#!/usr/bin/env bash
set -euxo pipefail

source "$(dirname "${BASH_SOURCE[0]}")"/common_vars.sh
mkdir $ARTIFACT_DIR

# Build Batfish
BF_DIR=$(mktemp -d)
git clone --depth=1 --branch=${BATFISH_GITHUB_BATFISH_REF} ${BATFISH_GITHUB_BATFISH_REPO} ${BF_DIR}
pushd ${BF_DIR}
  BATFISH_TAG=$(git rev-parse --short HEAD)
  mvn -f projects/pom.xml versions:set -DnewVersion=${BATFISH_VERSION_STRING}
  bazel build //projects/allinone:allinone_main_deploy.jar
popd

# Copy artifacts
# 1. The jar
cp ${BF_DIR}/bazel-bin/projects/allinone/allinone_main_deploy.jar ${ARTIFACT_DIR}/allinone-bundle.jar

# 2. Questions from Batfish
TMP_DIR=$(mktemp -d)
QUESTION_DIR=${TMP_DIR}/questions
mkdir -p ${QUESTION_DIR}
cp -r ${BF_DIR}/questions/{stable,experimental} ${QUESTION_DIR}
tar -czf ${ARTIFACT_DIR}/questions.tgz -C ${TMP_DIR} questions

# 3. The tag for the Batfish image
echo ${BATFISH_TAG} > ${ARTIFACT_DIR}/batfish-tag.txt
