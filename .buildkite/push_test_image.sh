#!/usr/bin/env bash
# Push specified test image files to Docker Hub
# Requires two arguments:
#  1. image filename: image file to be pushed to Docker Hub (e.g. allinone.tar)
#  2. image name: name of image to push to Docker Hub (e.g. allinone)

set -euxo pipefail

if [ "${1-}" == "" -o "${2-}" == "" ]; then
  echo "Must specify both the image filename and image name to upload to Docker Hub."
  exit 1
fi

BUILDKITE_DIR="$(dirname "${BASH_SOURCE[0]}")"
source $BUILDKITE_DIR/common_vars.sh
mkdir -p $ARTIFACT_DIR

# Download, load into local Docker, and push the specified image to Docker Hub
buildkite-agent artifact download ${ARTIFACT_DIR}/$1 ${ARTIFACT_DIR}
docker load -i ${ARTIFACT_DIR}/$1
docker push batfish/$2:${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER}
