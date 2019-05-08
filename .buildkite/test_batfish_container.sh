#!/usr/bin/env bash
# Test the Batfish Docker image with Pybatfish integration tests
# Accepts optional argument:
#  1. Batfish docker artifact filename: if specified, Batfish image is loaded
#     from this artifact instead of pulling from Docker Hub

set -euxo pipefail

# Handle docker container cleanup
function finish {
    # Cleanup Batfish Docker container if it was started and is still running
    if [ -n ${BATFISH_CONTAINER} ]
    then
      if docker top ${BATFISH_CONTAINER} &>/dev/null
        then
          docker stop ${BATFISH_CONTAINER}
          echo stopped Batfish container
        fi
    fi
}

# Cleanup on exit
trap finish EXIT

BUILDKITE_DIR="$(dirname "${BASH_SOURCE[0]}")"
ABS_SOURCE_DIR="$(realpath "${BUILDKITE_DIR}/..")"
source $BUILDKITE_DIR/common_vars.sh
mkdir $ARTIFACT_DIR

buildkite-agent artifact download ${ARTIFACT_DIR}/pybatfish*.whl ${ARTIFACT_DIR}
buildkite-agent artifact download ${ARTIFACT_DIR}/pybatfish-notebooks.tgz ${ARTIFACT_DIR}
buildkite-agent artifact download ${ARTIFACT_DIR}/pybatfish-tag.txt ${ARTIFACT_DIR}
buildkite-agent artifact download ${ARTIFACT_DIR}/pybatfish-tests.tgz ${ARTIFACT_DIR}
buildkite-agent artifact download ${ARTIFACT_DIR}/pybatfish-version.txt ${ARTIFACT_DIR}
buildkite-agent artifact download ${ARTIFACT_DIR}/questions.tgz ${ARTIFACT_DIR}
if [ "${1-}" != "" ]; then
  # Download and load the image artifact if an image file path is specified
  buildkite-agent artifact download ${ARTIFACT_DIR}/$1 ${ARTIFACT_DIR}
  docker load -i ${ARTIFACT_DIR}/$1
fi

# Use host network so Batfish is accessible at localhost from inside test container
BATFISH_CONTAINER=$(docker run -d --net=host batfish/batfish:${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER})

# Run Pybatfish integration tests against Batfish container
docker run --net=host -v $(pwd)/${ARTIFACT_DIR}:/assets/ \
  -v $ABS_SOURCE_DIR/tests/test_batfish_container.sh:/test.sh \
  --entrypoint /bin/bash batfish/ci-base:latest /test.sh

docker stop ${BATFISH_CONTAINER}
