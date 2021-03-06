#!/usr/bin/env bash
# Build Batfish Docker image and either push to Docker Hub or save an artifact
# Accepts optional argument:
#  1. Batfish docker artifact filename: if specified, Batfish image is saved
#     to this artifact instead of pushing to Docker Hub

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
  -t batfish/batfish:${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER} \
  --label "org.batfish.batfish-tag=${BF_TAG}" \
  --label "org.batfish.batfish-version=${BATFISH_VERSION_STRING-}" \
  --build-arg ASSETS=${ASSET_DIR} .

if [ "${1-}" == "" ]; then
  # Upload the image to Docker Hub if no image file path is specified
  docker push batfish/batfish:${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER}
else
  # Upload the image as an artifact tar if an image file path is specified
  docker save -o ${ARTIFACT_DIR}/$1 batfish/batfish:${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER}
fi
