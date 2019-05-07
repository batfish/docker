#!/usr/bin/env bash
set -euxo pipefail

BUILDKITE_DIR="$(dirname "${BASH_SOURCE[0]}")"
ABS_SOURCE_DIR="$(realpath "${BUILDKITE_DIR}/..")"
source ${BUILDKITE_DIR}/common_vars.sh
ASSET_DIR=./assets

mkdir ${ARTIFACT_DIR}
mkdir ${ASSET_DIR}

buildkite-agent artifact download ${ARTIFACT_DIR}/allinone-bundle.jar ${ARTIFACT_DIR}
buildkite-agent artifact download ${ARTIFACT_DIR}/batfish-tag.txt ${ARTIFACT_DIR}
buildkite-agent artifact download ${ARTIFACT_DIR}/questions.tgz ${ARTIFACT_DIR}

BF_TAG=$(cat ${ARTIFACT_DIR}/batfish-tag.txt)

# Setup assets for the Batfish image
tar xzf ${ARTIFACT_DIR}/questions.tgz -C ${ASSET_DIR}
cp ${ARTIFACT_DIR}/allinone-bundle.jar ${ASSET_DIR}

docker build -f ${ABS_SOURCE_DIR}/batfish.dockerfile \
  -t batfish/batfish:${BF_TAG} --build-arg ASSETS=${ASSET_DIR} .
docker tag batfish/batfish:${BF_TAG} batfish/batfish:${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER}

if [ "${1-}" == "" ]; then
  # Upload the image to Docker Hub if no image file path is specified
  docker push batfish/batfish:${BF_TAG}
  docker push batfish/batfish:${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER}
else
  # Upload the image as an artifact tar if an image file path is specified
  docker save -o ${ARTIFACT_DIR}/$1 batfish/batfish:${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER}
fi
