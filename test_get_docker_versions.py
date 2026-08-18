"""Tests for get_docker_versions.py"""
import pytest
from unittest.mock import MagicMock, patch

import get_docker_versions


def _make_response(status_code: int, json_data: dict) -> MagicMock:
    resp = MagicMock()
    resp.status_code = status_code
    resp.json.return_value = json_data
    resp.text = str(json_data)
    return resp


def _tag(name: str, last_updated: str = "2023-01-01") -> dict:
    return {"name": name, "last_updated": f"{last_updated}T00:00:00.000000Z"}


class TestGetRelevantReleases:
    def test_successful_response_returns_releases(self):
        tags = [
            _tag("2023.01.15.1001"),
            _tag("2023.01.10.1000"),
            _tag("latest"),  # non-date tag, should be filtered out
        ]
        resp = _make_response(200, {"results": tags, "next": None})
        with patch("get_docker_versions.requests.get", return_value=resp):
            result = get_docker_versions.get_relevant_releases(
                "batfish/batfish", days=9999, minimum=1, pattern=None
            )
        assert "2023.01.15.1001" in result
        assert "2023.01.10.1000" in result
        assert "latest" not in result

    def test_missing_results_key_raises_runtime_error(self):
        resp = _make_response(200, {"detail": "Not found"})
        with patch("get_docker_versions.requests.get", return_value=resp):
            with pytest.raises(RuntimeError, match="'results' key missing"):
                get_docker_versions.get_relevant_releases(
                    "batfish/batfish", days=90, minimum=1, pattern=None
                )

    def test_non_2xx_response_raises_runtime_error(self):
        resp = _make_response(403, {"message": "access denied"})
        with patch("get_docker_versions.requests.get", return_value=resp):
            with pytest.raises(RuntimeError, match="HTTP 403"):
                get_docker_versions.get_relevant_releases(
                    "batfish/batfish", days=90, minimum=1, pattern=None
                )

    def test_rate_limit_retries_then_succeeds(self):
        tags = [_tag("2023.01.15.1001")]
        rate_limited = _make_response(429, {"message": "rate limited"})
        success = _make_response(200, {"results": tags, "next": None})
        responses = [rate_limited, success]
        with patch("get_docker_versions.requests.get", side_effect=responses), \
             patch("get_docker_versions.time.sleep"):
            result = get_docker_versions.get_relevant_releases(
                "batfish/batfish", days=9999, minimum=1, pattern=None
            )
        assert "2023.01.15.1001" in result

    def test_rate_limit_exhausted_raises_runtime_error(self):
        rate_limited = _make_response(429, {"message": "rate limited"})
        with patch("get_docker_versions.requests.get", return_value=rate_limited), \
             patch("get_docker_versions.time.sleep"):
            with pytest.raises(RuntimeError, match="HTTP 429"):
                get_docker_versions.get_relevant_releases(
                    "batfish/batfish", days=90, minimum=1, pattern=None
                )

    def test_minimum_respected(self):
        """Should include older releases to satisfy minimum count."""
        old_tag = _tag("2000.01.01.1", last_updated="2000-01-01")
        resp = _make_response(200, {"results": [old_tag], "next": None})
        with patch("get_docker_versions.requests.get", return_value=resp):
            result = get_docker_versions.get_relevant_releases(
                "batfish/batfish", days=1, minimum=1, pattern=None
            )
        assert "2000.01.01.1" in result

    def test_pagination_followed(self):
        page1 = _make_response(200, {
            "results": [_tag("2023.01.15.1001")],
            "next": "https://hub.docker.com/page2",
        })
        page2 = _make_response(200, {
            "results": [_tag("2023.01.10.1000")],
            # No 'next' key means end of pagination
        })
        responses = [page1, page2]
        with patch("get_docker_versions.requests.get", side_effect=responses):
            result = get_docker_versions.get_relevant_releases(
                "batfish/batfish", days=9999, minimum=5, pattern=None
            )
        assert "2023.01.15.1001" in result
        assert "2023.01.10.1000" in result

    def test_test_tags_excluded_when_pattern_matches_both(self):
        resp = _make_response(
            200,
            {
                "results": [
                    _tag("test-2026.08.09.4001"),
                    _tag("2026.08.09.4001"),
                ],
                "next": None,
            },
        )
        with patch("get_docker_versions.requests.get", return_value=resp):
            result = get_docker_versions.get_relevant_releases(
                "batfish/batfish", days=9999, minimum=1, pattern="202"
            )
        assert result == ["2026.08.09.4001"]

    def test_falls_back_to_registry_when_hub_offset_limit_hit(self):
        page1 = _make_response(
            200,
            {
                "results": [_tag("test-2026.08.09.4001")],
                "next": "https://hub.docker.com/v2/repositories/batfish/batfish/tags/?name=202&page=11&page_size=100",
            },
        )
        hub_limit = _make_response(
            403,
            {"message": "pagination offset too large for anonymous requests; sign in to page further"},
        )
        token = _make_response(200, {"token": "token-value"})
        registry = _make_response(
            200,
            {"name": "batfish/batfish", "tags": ["test-2026.08.09.4001", "2026.08.09.4001", "2026.08.08.3999"]},
        )

        responses = [page1, hub_limit, token, registry]
        with patch("get_docker_versions.requests.get", side_effect=responses):
            result = get_docker_versions.get_relevant_releases(
                "batfish/batfish", days=9999, minimum=2, pattern="202"
            )
        assert result == ["2026.08.09.4001", "2026.08.08.3999"]

    def test_old_prod_tags_still_meet_minimum(self):
        resp = _make_response(
            200,
            {
                "results": [
                    _tag("2020.01.03.2", last_updated="2026-08-01"),
                    _tag("2020.01.02.1", last_updated="2026-08-01"),
                ],
                "next": None,
            },
        )
        with patch("get_docker_versions.requests.get", return_value=resp):
            result = get_docker_versions.get_relevant_releases(
                "batfish/batfish", days=1, minimum=2, pattern=None
            )
        assert result == ["2020.01.03.2", "2020.01.02.1"]
