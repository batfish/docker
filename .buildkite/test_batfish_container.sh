#!/usr/bin/env bash
# Test the Batfish Docker image with Pybatfish integration tests
# Accepts optional argument:
#  1. Batfish docker artifact filename: if specified, Batfish image is loaded
#     from this artifact instead of pulling from Docker Hub
#
# If env var BATFISH_CONTAINER_TAG is set, that is used as the container tag
# instead of the default testing tag. (e.g. test-1234).
# If env var PYBATFISH_PYTEST_ARGS is set, that is added as extra args
# passed into pytest when running Pybatfish integration tests.
# If env var PYBATFISH_VERSION is set (e.g. pybatfish[dev]==2019.11.01),
# that package is installed from PyPI instead of using the buildkite
# artifacts

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
if [ "${1-}" != "" ]; then
  # Download and load the image artifact if an image file path is specified
  buildkite-agent artifact download ${ARTIFACT_DIR}/$1 ${ARTIFACT_DIR}
  docker load -i ${ARTIFACT_DIR}/$1
fi

# Use provided container tag, if applicable
BATFISH_CONTAINER_TAG="${BATFISH_CONTAINER_TAG:-${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER}}"

# Use host network so Batfish is accessible at localhost from inside test container
BATFISH_CONTAINER=$(docker run --memory=1536m -d --net=host batfish/batfish:${BATFISH_CONTAINER_TAG})

if [ "${bf_version-}" == "" ]; then
  # Pull batfish version from container label if none is supplied via env var
  BATFISH_VERSION=$(docker inspect -f '{{ index .Config.Labels "org.batfish.batfish-version" }}' ${BATFISH_CONTAINER})
else
  BATFISH_VERSION=${bf_version}
fi
echo "Using Batfish version: ${BATFISH_VERSION}"
# Run Pybatfish integration tests against Batfish container
docker run --net=host -v $(pwd)/${ARTIFACT_DIR}:/assets/ \
  -v $ABS_SOURCE_DIR/tests/test_batfish_container.sh:/test.sh \
  --env PYBATFISH_PYTEST_ARGS="${PYBATFISH_PYTEST_ARGS:-}" \
  --env bf_version="${BATFISH_VERSION}" \
  --env PYBATFISH_VERSION="${PYBATFISH_VERSION:-}" \
  --memory=256m \
  --entrypoint /bin/bash batfish/ci-base:latest /test.sh

docker stop ${BATFISH_CONTAINER}
