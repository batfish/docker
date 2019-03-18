#!/usr/bin/env bash
set -e

# This script tests and builds and optionally pushes Batfish and Batfish+Pybatfish+Jupyter docker images
# Optionally pass in Batfish and Pybatfish commit hashes to build from specific commits instead of head, for example:
# sh build_images.sh push 3337ecf49f9f754d502e8aa5443919bea18afdd6 ddcb50bb8c05cbcfa71c261c146bc1360e581961
if [ "$1" == "" -o "$1" == "build" ]; then
    PUSH=false
elif [ "$1" == "push" ]; then
    PUSH=true
else
    echo "Unknown action '$1' does not match 'push' or 'build'."
    exit 1
fi

# Asset directory setup
WORK_DIR="$PWD"
TEMP_DIR=$(mktemp -d)
ASSETS_REL_PATH=./assets
ASSETS_FULL_PATH=${WORK_DIR}/${ASSETS_REL_PATH}
PY_ASSETS_REL_PATH=./py_assets
PY_ASSETS_FULL_PATH=${WORK_DIR}/${PY_ASSETS_REL_PATH}

function cleanup_dirs {
    # Testing writes pycache files as root
    sudo rm -rf ${TEMP_DIR}
    rm -rf ${ASSETS_FULL_PATH}
    rm -rf ${PY_ASSETS_FULL_PATH}
}

# Cleanup on exit
trap cleanup_dirs EXIT

mkdir -p ${ASSETS_FULL_PATH}
mkdir -p ${PY_ASSETS_FULL_PATH}


# Batfish
echo "Cloning and building batfish"
echo "Using tmp dir: ${TEMP_DIR}"

pushd ${TEMP_DIR}
git clone --depth 1 https://github.com/batfish/batfish.git
## Build and save commit info
pushd batfish
if [ "$2" != "" ]; then
    echo "Using specific Batfish commit $2"
    git reset --hard $2
fi
mvn clean -f projects/pom.xml package
BATFISH_TAG=$(git rev-parse --short HEAD)
BATFISH_VERSION=$(grep -1 batfish-parent "projects/pom.xml" | grep version | sed 's/[<>]/|/g' | cut -f3 -d\|)
echo "BATFISH_TAG is $BATFISH_TAG"
echo "BATFISH_VERSION is $BATFISH_VERSION"
popd
cp batfish/projects/allinone/target/allinone-bundle-${BATFISH_VERSION}.jar ${ASSETS_FULL_PATH}/allinone-bundle.jar
cp -r batfish/questions ${ASSETS_FULL_PATH}
popd
docker build -f ${WORK_DIR}/batfish.dockerfile -t batfish/batfish:sha_${BATFISH_TAG} --build-arg ASSETS=${ASSETS_REL_PATH} .


echo "Cloning and building pybatfish"
# Pybatfish
pushd ${TEMP_DIR}
git clone --depth 1 https://github.com/batfish/pybatfish.git
## Build and save commit info
pushd pybatfish
if [ "$3" != "" ]; then
    echo "Using specific Pybatfish commit $3"
    git reset --hard $3
fi

# Create virtual env + dependencies so we can build the wheel
virtualenv -p python3 .env
source .env/bin/activate
pip install pytest wheel
python setup.py sdist bdist_wheel
PYBATFISH_TAG=$(git rev-parse --short HEAD)
PYBATFISH_VERSION=$(python setup.py --version)
echo PYBATFISH_TAG is $PYBATFISH_TAG
echo PYBATFISH_VERSION is $PYBATFISH_VERSION
cp -r ../batfish/questions questions
deactivate
popd

cp pybatfish/dist/pybatfish-${PYBATFISH_VERSION}-py2.py3-none-any.whl ${PY_ASSETS_FULL_PATH}
cp -r pybatfish/jupyter_notebooks/ ${PY_ASSETS_FULL_PATH}/notebooks
popd


# Combined container stuff
cp wrapper.sh ${PY_ASSETS_FULL_PATH}
docker build -f ${WORK_DIR}/allinone.dockerfile -t batfish/allinone:sha_${BATFISH_TAG}_${PYBATFISH_TAG} \
  --build-arg PYBATFISH_VERSION=${PYBATFISH_VERSION} \
  --build-arg ASSETS=${PY_ASSETS_REL_PATH} \
  --build-arg TAG=sha_${BATFISH_TAG} .

# Get tmp dir mounting to work for mac without updating Docker
# See https://github.com/docker/for-mac/issues/1532
PYBATFISH_DIR=$TEMP_DIR/pybatfish
MAC_PYBATFISH_DIR=/private/$TEMP_DIR/pybatfish
if [ -d "$MAC_PYBATFISH_DIR" ]; then
    PYBATFISH_DIR=$MAC_PYBATFISH_DIR
fi
# Run tests inside Docker container
docker run -v $(pwd)/tests/test.sh:/test.sh:ro \
  -v $PYBATFISH_DIR:/pybatfish \
  --entrypoint /bin/bash \
  batfish/allinone:sha_${BATFISH_TAG}_${PYBATFISH_TAG} test.sh

docker tag batfish/batfish:sha_${BATFISH_TAG} batfish/batfish:latest
docker tag batfish/allinone:sha_${BATFISH_TAG}_${PYBATFISH_TAG} batfish/allinone:latest

# Cleanup the temp directory if successful
cleanup_dirs

echo "Built batfish/batfish:sha_${BATFISH_TAG}"
echo "Built batfish/allinone:sha_${BATFISH_TAG}_${PYBATFISH_TAG}"

if [ "$PUSH" == "true" ]; then
    # Push the docker images after successfully build
    docker push batfish/batfish:sha_${BATFISH_TAG}
    docker push batfish/batfish:latest
    docker push batfish/allinone:sha_${BATFISH_TAG}_${PYBATFISH_TAG}
    docker push batfish/allinone:latest

    echo "Pushed batfish/batfish:latest and batfish/batfish:sha_${BATFISH_TAG}"
    echo "Pushed batfish/allinone:latest and batfish/allinone:sha_${BATFISH_TAG}_${PYBATFISH_TAG}"
fi
