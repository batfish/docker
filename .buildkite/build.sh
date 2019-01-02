#!/usr/bin/env bash

# This script tests and builds and optionally pushes Batfish and Batfish+Pybatfish+Jupyter docker images
# Optionally pass in Batfish and Pybatfish commit hashes to build from specific commits instead of head, for example:
# sh build_images.sh push 3337ecf49f9f754d502e8aa5443919bea18afdd6 ddcb50bb8c05cbcfa71c261c146bc1360e581961

# Quick check to see if a particular port is free

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

### Ensure docker socket is available
ls -l "/var/run/docker.sock"

mkdir -p "${ASSETS_FULL_PATH}"
mkdir -p "${PY_ASSETS_FULL_PATH}"

### get versions
BATFISH_TAG="$(cat artifacts/batfish/tag)"
BATFISH_VERSION="$(cat artifacts/batfish/version)"
PYBATFISH_TAG="$(cat artifacts/pybatfish/tag)"
PYBATFISH_VERSION="$(cat artifacts/pybatfish/version)"

# Batfish
# Prepare using downloaded artifacts
cp artifacts/batfish/allinone.jar ${ASSETS_FULL_PATH}/allinone-bundle.jar
tar -x --no-same-owner -C ${ASSETS_FULL_PATH} -f artifacts/batfish/questions.tgz
echo "BATFISH_TAG is $BATFISH_TAG"
echo "BATFISH_VERSION is $BATFISH_VERSION"
docker build -f "${WORK_DIR}/batfish.dockerfile" -t "arifogel/batfish:sha_${BATFISH_TAG}" --build-arg ASSETS="${ASSETS_REL_PATH}" .


echo "Cloning and building pybatfish"
# Pybatfish
pushd "${TEMP_DIR}"
git clone --depth 1 --branch="${PYBATFISH_TAG}" "https://github.com/arifogel/pybatfish.git"
## Build and save commit info
pushd pybatfish

# Create virtual env + dependencies so we can build the wheel
virtualenv -p python3 .env
source ".env/bin/activate"
pip install pytest wheel
python setup.py sdist bdist_wheel
echo "PYBATFISH_TAG is $PYBATFISH_TAG"
echo "PYBATFISH_VERSION is $PYBATFISH_VERSION"
pip install .[dev]
ln -s "${ASSETS_FULL_PATH}/questions"

# Start up batfish container using build-base network stack
BATFISH_CONTAINER="$(docker run -d --network=container:"$(grep '/docker/' /proc/self/cgroup | sed 's|.*docker/\(.*\)|\1|g' | head -n1)" "arifogel/batfish:sha_${BATFISH_TAG}")"
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
cp "pybatfish/dist/pybatfish-${PYBATFISH_VERSION}-py2.py3-none-any.whl" "${PY_ASSETS_FULL_PATH}"
cp -r "pybatfish/jupyter_notebooks/" "${PY_ASSETS_FULL_PATH}/notebooks"
popd

# Combined container stuff
cp "wrapper.sh" "${PY_ASSETS_FULL_PATH}"
docker build -f "${WORK_DIR}/allinone.dockerfile" -t "arifogel/allinone:sha_${BATFISH_TAG}_${PYBATFISH_TAG}" \
  --build-arg PYBATFISH_VERSION="${PYBATFISH_VERSION}" \
  --build-arg ASSETS="${PY_ASSETS_REL_PATH}" \
  --build-arg TAG="sha_${BATFISH_TAG}" .


# Cleanup the temp directory if successful
cleanup_dirs

echo "Built arifogel/batfish:sha_${BATFISH_TAG}"
echo "Built arifogel/allinone:sha_${BATFISH_TAG}_${PYBATFISH_TAG}"

if [ "${BUILDKITE_PULL_REQUEST}" = "false" ]; then 
  # Push the docker images after successfully build
  docker push arifogel/batfish:sha_${BATFISH_TAG}
  docker push arifogel/allinone:sha_${BATFISH_TAG}_${PYBATFISH_TAG}

  echo "Pushed arifogel/batfish:sha_${BATFISH_TAG}"
  echo "Pushed arifogel/allinone:sha_${BATFISH_TAG}_${PYBATFISH_TAG}"

  docker tag "arifogel/batfish:sha_${BATFISH_TAG}" "arifogel/batfish:dev"
  docker tag "arifogel/allinone:sha_${BATFISH_TAG}_${PYBATFISH_TAG}" "arifogel/allinone:dev"
  docker push "arifogel/batfish:dev"
  docker push "arifogel/allinone:dev"

  echo "Pushed arifogel/batfish:dev"
  echo "Pushed arifogel/allinone:dev"
fi

