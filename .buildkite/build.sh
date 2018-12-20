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


# Batfish
echo "Cloning and building batfish"
echo "Using tmp dir: ${TEMP_DIR}"
pushd "${TEMP_DIR}"


if [ -z "${BATFISH_TAG}" ]; then
	### If not a triggered build, need to produce artifact and set variables
	git clone --depth 1 "https://github.com/arifogel/batfish.git"
	## Build and save commit info
	pushd batfish
	mvn clean -f "projects/pom.xml" package
	BATFISH_TAG="$(git rev-parse --short HEAD)"
	BATFISH_VERSION="$(grep -1 batfish-parent "projects/pom.xml" | grep version | sed 's/[<>]/|/g' | cut -f3 -d\|)"
	popd
	cp "batfish/projects/allinone/target/allinone-bundle-${BATFISH_VERSION}.jar" "${ASSETS_FULL_PATH}/allinone-bundle.jar"
	cp -r "batfish/questions" "${ASSETS_FULL_PATH}"
else
  ### For triggered build, just prepare using downloaded artifacts
	cp "workspace/allinone.jar" "${ASSETS_FULL_PATH}/allinone-bundle.jar"
	tar -x --no-same-owner -C "${ASSETS_FULL_PATH}" -f "workspace/questions.tar"
fi

echo "BATFISH_TAG is $BATFISH_TAG"
echo "BATFISH_VERSION is $BATFISH_VERSION"
popd
docker build -f "${WORK_DIR}/batfish.dockerfile" -t "arifogel/batfish:sha_${BATFISH_TAG}" --build-arg ASSETS="${ASSETS_REL_PATH}" .


echo "Cloning and building pybatfish"
# Pybatfish
pushd "${TEMP_DIR}"
git clone --depth 1 "https://github.com/arifogel/pybatfish.git"
## Build and save commit info
pushd pybatfish

# Create virtual env + dependencies so we can build the wheel
virtualenv -p python3 .env
source ".env/bin/activate"
pip install pytest wheel
python setup.py sdist bdist_wheel
PYBATFISH_TAG="$(git rev-parse --short HEAD)"
PYBATFISH_VERSION="$(python setup.py --version)"
echo "PYBATFISH_TAG is $PYBATFISH_TAG"
echo "PYBATFISH_VERSION is $PYBATFISH_VERSION"
pip install .[dev]
ln -s "../batfish/questions"

# Start up batfish container using build-base network stack
BATFISH_CONTAINER="$(docker run -d --network=container:"$(grep '/docker/' /proc/self/cgroup | sed 's|.*docker/\(.*\)|\1|g' | head -n1)" "arifogel/batfish:sha_${BATFISH_TAG}")"
# Poll until we can connect to the container
while ! curl http://localhost:9996/
do
  echo "$(date) - waiting for Batfish to start"
  sleep 1
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

# Push the docker images after successfully build
docker push "arifogel/batfish:sha_${BATFISH_TAG}"
docker push "arifogel/allinone:sha_${BATFISH_TAG}_${PYBATFISH_TAG}"

echo "Pushed arifogel/batfish:sha_${BATFISH_TAG}"
echo "Pushed arifogel/allinone:sha_${BATFISH_TAG}_${PYBATFISH_TAG}"

