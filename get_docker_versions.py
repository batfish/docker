"""List relevant release versions from Docker Hub for the specified image.
Filters based on requested minimum number of releases and release age."""
import argparse
from datetime import datetime, timedelta
import re
import sys
import time
from typing import Dict, List, Optional, Set, Tuple

import requests

_MAX_RETRIES = 3
_RETRY_BACKOFF_SECONDS = 5
_DOCKER_HUB_PAGE_SIZE = 100
_REGISTRY_PAGE_SIZE = 100
_DOCKER_HUB_OFFSET_LIMIT_MSG = "pagination offset too large for anonymous requests"
_RELEASE_TAG_PATTERN = re.compile(r"^(?P<year>\d{4})\.(?P<month>\d{2})\.(?P<day>\d{2})\.(?P<build>\d+)$")


class DockerHubPaginationLimitError(RuntimeError):
    """Raised when Docker Hub anonymous pagination offset limit is reached."""


def _get_json(url: str, headers: Optional[dict] = None, params: Optional[dict] = None) -> dict:
    """Fetch URL and return parsed JSON, with retries on transient errors."""
    for attempt in range(1, _MAX_RETRIES + 1):
        resp = requests.get(url, headers=headers, params=params)
        if resp.status_code == 200:
            return resp.json()
        excerpt = resp.text[:200]
        if (
            resp.status_code == 403
            and _DOCKER_HUB_OFFSET_LIMIT_MSG in resp.text.lower()
        ):
            raise DockerHubPaginationLimitError(
                f"Docker Hub request failed: HTTP {resp.status_code} for {url!r}. "
                f"Response excerpt: {excerpt!r}"
            )
        if resp.status_code in (429, 500, 502, 503, 504) and attempt < _MAX_RETRIES:
            wait = _RETRY_BACKOFF_SECONDS * attempt
            print(
                f"Warning: Docker Hub returned {resp.status_code} (attempt {attempt}/{_MAX_RETRIES}), "
                f"retrying in {wait}s. Response: {excerpt!r}",
                file=sys.stderr,
            )
            time.sleep(wait)
            continue
        raise RuntimeError(
            f"Docker Hub request failed: HTTP {resp.status_code} for {url!r}. "
            f"Response excerpt: {excerpt!r}"
        )
    # Should not be reached, but satisfy type checker
    raise RuntimeError(f"Exhausted retries for {url!r}")


def _parse_release_tag(tag: str, pattern: Optional[str]) -> Optional[Tuple[datetime, int]]:
    """Return (release_date, build_num) for prod release tags, otherwise None."""
    if tag.startswith("test"):
        return None
    if pattern and pattern not in tag:
        return None
    match = _RELEASE_TAG_PATTERN.match(tag)
    if not match:
        return None
    try:
        release_date = datetime(
            year=int(match.group("year")),
            month=int(match.group("month")),
            day=int(match.group("day")),
        )
        build_num = int(match.group("build"))
    except ValueError:
        return None
    return (release_date, build_num)


def _select_relevant_releases(tags: List[str], days: int, minimum: int, pattern: Optional[str]) -> List[str]:
    """Apply prod-tag filtering and recency/minimum selection policy."""
    release_info: Dict[str, Tuple[datetime, int]] = {}
    for tag in tags:
        parsed = _parse_release_tag(tag, pattern)
        if parsed is not None:
            release_info[tag] = parsed

    versions = sorted(
        release_info.keys(),
        key=lambda tag: (release_info[tag][0], release_info[tag][1]),
        reverse=True,
    )

    threshold = datetime.now() - timedelta(days=days)
    selected = []
    for version in versions:
        release_date = release_info[version][0]
        if release_date > threshold or len(selected) < minimum:
            selected.append(version)
    return selected


def _get_tags_from_docker_hub(image: str, minimum: int, pattern: Optional[str]) -> List[str]:
    """Collect tag names from Docker Hub pages (fast path)."""
    name_filter = f"&name={pattern}" if pattern else ""
    url = f"https://hub.docker.com/v2/repositories/{image}/tags/?page_size={_DOCKER_HUB_PAGE_SIZE}{name_filter}"
    tags = []
    while True:
        resp_json = _get_json(url)
        if "results" not in resp_json:
            raise RuntimeError(
                f"Unexpected Docker Hub response: 'results' key missing. "
                f"Keys present: {list(resp_json.keys())!r}. "
                f"Response excerpt: {str(resp_json)[:200]!r}"
            )
        page_tags = [r["name"] for r in resp_json["results"] if "name" in r]
        tags.extend(page_tags)
        if len(_select_relevant_releases(tags, days=0, minimum=minimum, pattern=pattern)) >= minimum:
            break
        if "next" not in resp_json or not resp_json["next"]:
            break
        url = resp_json["next"]
    return tags


def _get_registry_token(image: str) -> str:
    """Get Docker Registry bearer token for tag listing."""
    token_url = f"https://auth.docker.io/token?service=registry.docker.io&scope=repository:{image}:pull"
    token_json = _get_json(token_url)
    token = token_json.get("token")
    if not token:
        raise RuntimeError(f"Unexpected token response from auth service: {str(token_json)[:200]!r}")
    return token


def _get_tags_from_registry(image: str) -> List[str]:
    """Collect all tag names using Docker Registry cursor pagination."""
    token = _get_registry_token(image)
    headers = {"Authorization": "Bearer " + token}
    url = f"https://registry-1.docker.io/v2/{image}/tags/list"

    tags = []
    seen: Set[str] = set()
    last = None
    while True:
        params = {"n": _REGISTRY_PAGE_SIZE}
        if last is not None:
            params["last"] = last
        resp_json = _get_json(url, headers=headers, params=params)
        page_tags = resp_json.get("tags") or []
        if not isinstance(page_tags, list):
            raise RuntimeError(
                f"Unexpected Docker Registry response: 'tags' key is not a list. "
                f"Response excerpt: {str(resp_json)[:200]!r}"
            )
        if not page_tags:
            break
        for tag in page_tags:
            if tag not in seen:
                seen.add(tag)
                tags.append(tag)
        next_last = page_tags[-1]
        if len(page_tags) < _REGISTRY_PAGE_SIZE or next_last == last:
            break
        last = next_last
    return tags


def get_relevant_releases(image: str, days: int, minimum: int, pattern: Optional[str]) -> List[str]:
    """Returns a list of relevant releases, sorted newest first. Only includes release tags that look like dates e.g. 2022.08.26.1234

    Tries to return at least `minimum` releases, including all releases younger than the specified number of `days` old. Only considers tags containing the specified pattern."""
    try:
        tags = _get_tags_from_docker_hub(image, minimum, pattern)
    except DockerHubPaginationLimitError:
        print(
            "Warning: Docker Hub anonymous pagination limit reached; "
            "falling back to Docker Registry tag listing.",
            file=sys.stderr,
        )
        tags = _get_tags_from_registry(image)
    return _select_relevant_releases(tags, days, minimum, pattern)

def parse(args: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description='Get PyPI versions for a date-versioned package, e.g. Pybatfish.')
    parser.add_argument('--days', type=int, default=90,
                        help='List all versions from the past N days.')
    parser.add_argument('--minimum', type=int, default=3,
                        help='List at least M versions, even if they are older than N days old.')
    parser.add_argument('--image', type=str, required=True,
                        help='Name of the image on Docker Hub.')
    parser.add_argument('--pattern', type=str, default=None,
                        help='Pattern for tag to match, to be considered as a relevant release. Must be in the format accepted by Docker Hub\'s REST APIs. Note: additional filtering is done to include only release tags that look like dates e.g. 2022.08.26.1234')
    parser.add_argument('--json-format', action='store_true',
                        help='Print the output as a JSON list instead of newline separated list.')
    return parser.parse_args(args)

if __name__ == "__main__":
    args = parse(sys.argv[1:])

    releases = get_relevant_releases(args.image, args.days, args.minimum, args.pattern)
    if args.json_format:
        releases_str = '","'.join(releases)
        print(f'["{releases_str}"]')
    else:
        print('\n'.join(releases))
