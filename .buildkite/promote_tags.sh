#!/usr/bin/env bash
set -euxo pipefail

source "$(dirname "${BASH_SOURCE[0]}")"/common_vars.sh
UPDATE_TO_TAG=$(buildkite-agent meta-data get release-docker-tag)

for image in "batfish" "allinone"; do
  # Ensure we have the latest container
  docker pull "batfish/${image}:${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER}"
  # Re-tag & push with updated tag + build number
  docker tag  "batfish/${image}:${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER}" \
              "batfish/${image}:${UPDATE_TO_TAG}-${BUILDKITE_BUILD_NUMBER}"
  docker push "batfish/${image}:${UPDATE_TO_TAG}-${BUILDKITE_BUILD_NUMBER}"
  # Re-tag & push with just updated tag
  docker tag  "batfish/${image}:${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER}" \
              "batfish/${image}:${UPDATE_TO_TAG}"
  docker push "batfish/${image}:${UPDATE_TO_TAG}"
done
