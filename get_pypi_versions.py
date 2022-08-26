"""List relevant release versions from PyPI for the specified package.
Filters based on requested minimum number of releases and release age."""
import argparse
from datetime import datetime, timedelta
from typing import List

import requests

def get_relevant_releases(package: str, days: int, minimum: int) -> List[str]:
    """Returns a list of relevant releases, sorted newest first.

    Tries to return at least `minimum` releases, including all releases younger than the specified number of `days` old."""
    releases = requests.get(f'https://pypi.python.org/pypi/{package}/json').json()['releases']
    # Dict of release version to release datetime
    dates = {
        r: datetime.fromisoformat(releases.get(r)[0]['upload_time']) for r in releases
    }
    versions = sorted(dates.keys(), key=lambda r: dates.get(r), reverse=True)
    res = list()
    for v in versions:
        recent = dates.get(v) > datetime.now() - timedelta(days=days)
        if recent or len(res) < minimum:
            res.append(v)
    return res

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Get PyPI versions for a date-versioned package, e.g. Pybatfish.')
    parser.add_argument('--days', type=int, default=90,
                        help='List all versions from the past N days.')
    parser.add_argument('--minimum', type=int, default=3,
                        help='List at least M versions, even if they are older than N days old.')
    parser.add_argument('--package', type=str, required=True,
                        help='Name of the package as it appears on PyPI.')
    parser.add_argument('--json-format', action='store_true',
                        help='Print the output as a JSON list instead of newline separated list.')
    args = parser.parse_args()

    releases = get_relevant_releases(args.package, args.days, args.minimum)
    if args.json_format:
        releases_str = '","'.join(releases)
        print(f'["{releases_str}"]')
    else:
        print('\n'.join(releases))
