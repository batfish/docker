#!/usr/bin/env bash
set -euxo pipefail

BUILDKITE_DIR="$(dirname "${BASH_SOURCE[0]}")"
ABS_SOURCE_DIR="$(realpath "${BUILDKITE_DIR}/..")"
source $BUILDKITE_DIR/common_vars.sh
mkdir $ARTIFACT_DIR

buildkite-agent artifact download ${ARTIFACT_DIR}/pybatfish*.whl ${ARTIFACT_DIR}
buildkite-agent artifact download ${ARTIFACT_DIR}/pybatfish-tag.txt ${ARTIFACT_DIR}
buildkite-agent artifact download ${ARTIFACT_DIR}/pybatfish-tests.tgz ${ARTIFACT_DIR}
buildkite-agent artifact download ${ARTIFACT_DIR}/pybatfish-version.txt ${ARTIFACT_DIR}
buildkite-agent artifact download ${ARTIFACT_DIR}/pybatfish-notebooks.tgz ${ARTIFACT_DIR}
buildkite-agent artifact download ${ARTIFACT_DIR}/questions.tgz ${ARTIFACT_DIR}
if [ "$1" != "" ]; then
  # Download and load the image artifact if an image file path is specified
  buildkite-agent artifact download ${ARTIFACT_DIR}/$1 ${ARTIFACT_DIR}
  docker load -i ${ARTIFACT_DIR}/$1
fi

PYBF_VERSION=$(cat ${ARTIFACT_DIR}/pybatfish-version.txt)

# Setup assets for the allinone image
TEMP_DIR=$(mktemp -d)
tar xzf ${ARTIFACT_DIR}/questions.tgz -C ${TEMP_DIR}
tar xzf ${ARTIFACT_DIR}/pybatfish-tests.tgz -C ${TEMP_DIR}
tar xzf ${ARTIFACT_DIR}/pybatfish-notebooks.tgz -C ${TEMP_DIR}

PYBF_WHEEL=pybatfish-${PYBF_VERSION}-py2.py3-none-any.whl
ABS_ARTIFACT_DIR=$(pwd)/${ARTIFACT_DIR}

# Run Pybatfish integration tests inside the container
docker run -v ${ABS_SOURCE_DIR}/tests/test.sh:/test.sh:ro \
  -v ${TEMP_DIR}/tests/:/pybatfish/tests/ \
  -v ${TEMP_DIR}/jupyter_notebooks/:/pybatfish/jupyter_notebooks/ \
  -v ${TEMP_DIR}/questions/:/pybatfish/questions/ \
  -v ${ABS_ARTIFACT_DIR}/${PYBF_WHEEL}:/pybatfish/dist/${PYBF_WHEEL} \
  -e PYBATFISH_VERSION=${PYBF_VERSION} \
  --entrypoint /bin/bash \
  batfish/allinone:${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER} \
  test.sh
