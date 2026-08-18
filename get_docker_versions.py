"""List relevant release versions from Docker Hub for the specified image.
Filters based on requested minimum number of releases and release age."""
import argparse
from datetime import datetime, timedelta
import re
import sys
import time
from typing import List, Optional

import requests

_MAX_RETRIES = 3
_RETRY_BACKOFF_SECONDS = 5


def _get_json(url: str) -> dict:
    """Fetch URL and return parsed JSON, with retries on transient errors."""
    for attempt in range(1, _MAX_RETRIES + 1):
        resp = requests.get(url)
        if resp.status_code == 200:
            return resp.json()
        excerpt = resp.text[:200]
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


def get_relevant_releases(image: str, days: int, minimum: int, pattern: Optional[str]) -> List[str]:
    """Returns a list of relevant releases, sorted newest first. Only includes release tags that look like dates e.g. 2022.08.26.1234

    Tries to return at least `minimum` releases, including all releases younger than the specified number of `days` old. Only considers tags containing the specified pattern."""
    name_filter = f"&name={pattern}" if pattern else ""
    url = f'https://hub.docker.com/v2/repositories/{image}/tags/?page_size=100{name_filter}'
    res = list()
    while True:
        resp_json = _get_json(url)
        if 'results' not in resp_json:
            raise RuntimeError(
                f"Unexpected Docker Hub response: 'results' key missing. "
                f"Keys present: {list(resp_json.keys())!r}. "
                f"Response excerpt: {str(resp_json)[:200]!r}"
            )
        releases = resp_json['results']
        # Dict of release version to release datetime
        dates = {
            r['name']: datetime.strptime(r['last_updated'], "%Y-%m-%dT%H:%M:%S.%fZ") for r in releases
            if re.match('\d{4}\.\d{2}\.\d{2}\.\d+', r['name'])
        }
        versions = sorted(dates.keys(), key=lambda r: dates.get(r), reverse=True)
        threshold = datetime.now() - timedelta(days=days)
        for v in versions:
            recent = dates.get(v) > threshold
            if recent or len(res) < minimum:
                res.append(v)
        if len(res) >= minimum:
            break
        if not 'next' in resp_json:
            break
        url = resp_json['next']

    return res

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
