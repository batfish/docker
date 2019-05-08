#!/usr/bin/env bash
# Build Allinone Docker image and either push to Docker Hub or save an artifact
# Accepts optional arguments:
#  1. Batfish docker artifact filename: if specified, Batfish image is loaded
#     from this artifact instead of pulling from Docker Hub
#  2. Allinone docker artifact filename: if specified, Allinone image is saved
#     to this artifact instead of pushing to Docker Hub

set -euxo pipefail

BUILDKITE_DIR="$(dirname "${BASH_SOURCE[0]}")"
ABS_SOURCE_DIR="$(realpath "${BUILDKITE_DIR}/..")"
source ${BUILDKITE_DIR}/common_vars.sh
ASSET_DIR=./assets

mkdir ${ARTIFACT_DIR}
mkdir ${ASSET_DIR}

buildkite-agent artifact download ${ARTIFACT_DIR}/batfish-tag.txt ${ARTIFACT_DIR}
buildkite-agent artifact download ${ARTIFACT_DIR}/pybatfish*.whl ${ARTIFACT_DIR}
buildkite-agent artifact download ${ARTIFACT_DIR}/pybatfish-notebooks.tgz ${ARTIFACT_DIR}
buildkite-agent artifact download ${ARTIFACT_DIR}/pybatfish-tag.txt ${ARTIFACT_DIR}
buildkite-agent artifact download ${ARTIFACT_DIR}/pybatfish-version.txt ${ARTIFACT_DIR}
if [ "${1-}" != "" ]; then
  # Download and load the image artifact if an image file path is specified
  buildkite-agent artifact download ${ARTIFACT_DIR}/$1 ${ARTIFACT_DIR}
  docker load -i ${ARTIFACT_DIR}/$1
fi

PYBF_VERSION=$(cat ${ARTIFACT_DIR}/pybatfish-version.txt)
PYBF_TAG=$(cat ${ARTIFACT_DIR}/pybatfish-tag.txt)
BF_TAG=$(cat ${ARTIFACT_DIR}/batfish-tag.txt)

# Setup assets for the Batfish image
cp ${ARTIFACT_DIR}/pybatfish*.whl ${ASSET_DIR}
TEMP_DIR=$(mktemp -d)
tar xzf ${ARTIFACT_DIR}/pybatfish-notebooks.tgz -C ${TEMP_DIR}
cp -r ${TEMP_DIR}/jupyter_notebooks/ ${ASSET_DIR}/notebooks/
# Script that starts Batfish + Jupyter server
cp ${ABS_SOURCE_DIR}/wrapper.sh ${ASSET_DIR}

docker build -f ${ABS_SOURCE_DIR}/allinone.dockerfile \
  -t batfish/allinone:${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER} \
  --build-arg PYBATFISH_VERSION=${PYBF_VERSION} \
  --build-arg ASSETS=${ASSET_DIR} \
  --build-arg TAG=${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER} .

if [ "${2-}" == "" ]; then
  # Upload the image to Docker Hub if no image file path is specified
  docker push batfish/allinone:${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER}
else
  # Upload the image as an artifact tar if an image file path is specified
  docker save -o ${ARTIFACT_DIR}/$2 batfish/allinone:${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER}
fi
