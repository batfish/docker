#!/usr/bin/env bash

# This script tests and builds and optionally pushes Batfish and Batfish+Pybatfish+Jupyter docker images
# Optionally pass in Batfish and Pybatfish commit hashes to build from specific commits instead of head, for example:
# sh build_images.sh push 3337ecf49f9f754d502e8aa5443919bea18afdd6 ddcb50bb8c05cbcfa71c261c146bc1360e581961

# Quick check to see if a particular port is free

BATFISH_DOCKER_REPO="arifogel/batfish"
ALLINONE_DOCKER_REPO="arifogel/allinone"

function is_port_free() {
  which netstat | return 1
  netstat -tln | awk '{print $4}' | grep '^127.0.0.1\|^::1' | sed 's/^.*:\([0-9][0-9]*\)$/\1/g' | grep -- "$1" >/dev/null
  local RET=${PIPESTATUS[4]}
  if [ "${RET}" -eq 0 ]; then
    echo "port $1 in use"
    return 1
  else
    return 0;
  fi
}

# Asset directory setup
WORK_DIR="$PWD"
TEMP_DIR="$(mktemp -d)"
ASSETS_REL_PATH="assets"
ASSETS_FULL_PATH="${WORK_DIR}/${ASSETS_REL_PATH}"
PY_ASSETS_REL_PATH="py_assets"
PY_ASSETS_FULL_PATH="${WORK_DIR}/${PY_ASSETS_REL_PATH}"

function cleanup_dirs {
    rm -rf "${TEMP_DIR}"
    rm -rf "${ASSETS_FULL_PATH}"
    rm -rf "${PY_ASSETS_FULL_PATH}"
}

# Handle directory and docker container cleanup
function finish {
    # Cleanup docker container if it was started and is still running
    if [ -n "${BATFISH_CONTAINER}" ]
    then
      if docker top "${BATFISH_CONTAINER}" &>/dev/null
        then
          docker stop "${BATFISH_CONTAINER}"
          echo stopped Batfish container
        fi
    fi
    cleanup_dirs
}

# Cleanup on exit
trap finish EXIT

# Make sure the ports Batfish will use are free, we will need that for testing
is_port_free 9996
is_port_free 9997

# Exit on error after checking ports, since port-check succeeds on error
set -e
set -x

REPO_TAG="$(git rev-parse HEAD)"
[ -n "${REPO_TAG}" ]

### Ensure docker socket is available
ls -l "/var/run/docker.sock"

mkdir -p "${ASSETS_FULL_PATH}"
mkdir -p "${PY_ASSETS_FULL_PATH}"

### get versions
BATFISH_TAG="$(cat artifacts/batfish/tag)"
BATFISH_VERSION="$(cat artifacts/batfish/version)"
BATFISH_DOCKER_TAG="sha_${BATFISH_TAG}_${REPO_TAG}"
PYBATFISH_TAG="$(cat artifacts/pybatfish/tag)"
PYBATFISH_VERSION="$(cat artifacts/pybatfish/version)"
ALLINONE_DOCKER_TAG="sha_${BATFISH_TAG}_${PYBATFISH_TAG}_${REPO_TAG}"

# Batfish
# Prepare using downloaded artifacts
cp artifacts/batfish/allinone.jar ${ASSETS_FULL_PATH}/allinone-bundle.jar
tar -x --no-same-owner -C ${ASSETS_FULL_PATH} -f artifacts/batfish/questions.tgz
echo "BATFISH_TAG is $BATFISH_TAG"
echo "BATFISH_VERSION is $BATFISH_VERSION"
docker build -f "${WORK_DIR}/batfish.dockerfile" -t "${BATFISH_DOCKER_REPO}:${BATFISH_DOCKER_TAG}" --build-arg ASSETS="${ASSETS_REL_PATH}" .


# Pybatfish
echo "Install pybatfish and run integration tests"
PYBATFISH_ARTIFACTS_DIR="${WORK_DIR}/artifacts/pybatfish"
# Prepare tests
pushd "${TEMP_DIR}"
mkdir -p pybatfish
pushd pybatfish
tar -x --no-same-owner -f "${PYBATFISH_ARTIFACTS_DIR}/integration_tests.tgz"
tar -x --no-same-owner -f "${PYBATFISH_ARTIFACTS_DIR}/jupyter_notebooks.tgz"
ln -s "${ASSETS_FULL_PATH}/questions"

# Create virtual env + dependencies
virtualenv -p python3 .env
. ".env/bin/activate"
pip install pytest wheel
pip install "${PYBATFISH_ARTIFACTS_DIR}/pybatfish-${PYBATFISH_VERSION}-py2.py3-none-any.whl"[dev,test]

echo "PYBATFISH_TAG is $PYBATFISH_TAG"
echo "PYBATFISH_VERSION is $PYBATFISH_VERSION"

# Start up batfish container using build-base network stack
BATFISH_CONTAINER="$(docker run -d --network=container:"$(grep '/docker/' /proc/self/cgroup | sed 's|.*docker/\(.*\)|\1|g' | head -n1)" "${BATFISH_DOCKER_REPO}:${BATFISH_DOCKER_TAG}")"
# Poll until we can connect to the container
MAX_RETRIES=30
CURL_ATTEMPT=0
while ! curl http://localhost:9996/ >&/dev/null && [ "${CURL_ATTEMPT}" -lt "${MAX_RETRIES}" ]
do
  echo "$(date) - waiting for Batfish to start"
  sleep 1
  CURL_ATTEMPT=$((CURL_ATTEMPT + 1))
done
echo "$(date) - connected to Batfish"

# Run pybatfish integration tests on batfish container
py.test "tests/integration"
deactivate
docker stop "${BATFISH_CONTAINER}"
popd
cp -r "pybatfish/jupyter_notebooks/" "${PY_ASSETS_FULL_PATH}/notebooks"
popd
cp "${PYBATFISH_ARTIFACTS_DIR}/pybatfish-${PYBATFISH_VERSION}-py2.py3-none-any.whl" "${PY_ASSETS_FULL_PATH}/"

# Combined container stuff
cp "wrapper.sh" "${PY_ASSETS_FULL_PATH}"
docker build -f "${WORK_DIR}/allinone.dockerfile" -t "${ALLINONE_DOCKER_REPO}:${ALLINONE_DOCKER_TAG}" \
  --build-arg PYBATFISH_VERSION="${PYBATFISH_VERSION}" \
  --build-arg ASSETS="${PY_ASSETS_REL_PATH}" \
  --build-arg TAG="${BATFISH_DOCKER_TAG}" .


# Cleanup the temp directory if successful
cleanup_dirs

echo "Built ${BATFISH_DOCKER_REPO}:${BATFISH_DOCKER_TAG}"
echo "Built ${ALLINONE_DOCKER_REPO}:${ALLINONE_DOCKER_TAG}"

if [ "${BUILDKITE_PULL_REQUEST}" = "false" ]; then 
  if curl --silent -f -lSL "https://index.docker.io/v1/repositories/${BATFISH_DOCKER_REPO}/tags/${BATFISH_DOCKER_TAG}" > /dev/null; then
    echo "Skipping batfish docker push since tag already exists"
  else
    # Push the docker images after successfully build
    docker push "${BATFISH_DOCKER_REPO}:${BATFISH_DOCKER_TAG}"
    echo "Pushed ${BATFISH_DOCKER_REPO}:${BATFISH_DOCKER_TAG}"
    docker tag "${BATFISH_DOCKER_REPO}:${BATFISH_DOCKER_TAG}" "${BATFISH_DOCKER_REPO}:dev"
    docker push "${BATFISH_DOCKER_REPO}:dev"
    echo "Pushed ${BATFISH_DOCKER_REPO}:dev"
  fi
  if curl --silent -f -lSL "https://index.docker.io/v1/repositories/${ALLINONE_DOCKER_REPO}/tags/${ALLINONE_DOCKER_TAG}" >& /dev/null; then
    echo "Skipping allinone docker push since tag already exists"
  else
    docker push "${ALLINONE_DOCKER_REPO}:${ALLINONE_DOCKER_TAG}"
    echo "Pushed ${ALLINONE_DOCKER_REPO}:${ALLINONE_DOCKER_TAG}"
    docker tag "${ALLINONE_DOCKER_REPO}:${ALLINONE_DOCKER_TAG}" "${ALLINONE_DOCKER_REPO}:dev"
    docker push "${ALLINONE_DOCKER_REPO}:dev"
    echo "Pushed ${ALLINONE_DOCKER_REPO}:dev"
  fi
fi

