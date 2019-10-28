#!/usr/bin/env bash
set -euo pipefail

BATFISH_UPLOAD_PIPELINE="f283deec-7e26-4f46-b8c6-b95b0cc1d974"
BATFISH_UPLOAD_PIPELINE="dc50f475-5ba8-448d-b699-261c36eb7a27"

BATFISH_DOCKER_CI_BASE_IMAGE="${BATFISH_DOCKER_CI_BASE_IMAGE:-batfish/ci-base:latest}"
BATFISH_DOCKER_CI_DOCKER_IMAGE="${BATFISH_DOCKER_CI_DOCKER_IMAGE:-batfish/ci-base:test-docker}"
BATFISH_GITHUB_BATFISH_REF="${BATFISH_GITHUB_BATFISH_REF:-master}"
BATFISH_GITHUB_BATFISH_REPO="${BATFISH_GITHUB_BATFISH_REPO:-https://github.com/batfish/batfish}"
BATFISH_GITHUB_PYBATFISH_REF="${BATFISH_GITHUB_PYBATFISH_REF:-master}"
if [ "${BUILDKITE_PIPELINE_ID}" == "${BATFISH_UPLOAD_PIPELINE}" ]; then
    BATFISH_GITHUB_PYBATFISH_REPO="${BATFISH_GITHUB_PYBATFISH_REPO:-git@github.com:batfish/pybatfish.git}"
else
    # Use SSL for precommit checks
    BATFISH_GITHUB_PYBATFISH_REPO="${BATFISH_GITHUB_PYBATFISH_REPO:-https://github.com/batfish/pybatfish}"
fi
DOCKER_LOGIN_PLUGIN_VERSION="${DOCKER_LOGIN_PLUGIN_VERSION:-v2.0.1}"
DOCKER_LOGIN_PLUGIN_USERNAME="${DOCKER_LOGIN_PLUGIN_USERNAME:-batfishbuildkitebot}"

ARTIFACTS_PLUGIN_VERSION="${ARTIFACTS_PLUGIN_VERSION:-v1.2.0}"
DOCKER_PLUGIN_VERSION="${DOCKER_PLUGIN_VERSION:-v3.3.0}"

BATFISH_VERSION_STRING="${BATFISH_VERSION_STRING:-$(date +'%Y.%m.%d').${BUILDKITE_BUILD_NUMBER}}"

# Attributes common to all command steps
COMMON_STEP_ATTRIBUTES=
# Specify queue for upload builds
if [ "${BUILDKITE_PIPELINE_ID}" == "${BATFISH_UPLOAD_PIPELINE}" ]; then
COMMON_STEP_ATTRIBUTES=$(cat <<EOF
    agents:
      queue: 'open-source-default'
EOF)
fi

cat <<EOF
steps:
EOF

###### WAIT a visible marker between pipeline generation and starting.
cat <<EOF
  - wait
EOF

cat <<EOF
  - label: ":java: Build batfish"
    command:
      - ".buildkite/build_batfish.sh"
    artifact_paths:
      - artifacts/allinone-bundle.jar
      - artifacts/questions.tgz
      - artifacts/batfish-tag.txt
    plugins:
      - docker#${DOCKER_PLUGIN_VERSION}:
          image: "${BATFISH_DOCKER_CI_BASE_IMAGE}"
          always-pull: true
          environment:
            - "BATFISH_GITHUB_BATFISH_REF=${BATFISH_GITHUB_BATFISH_REF}"
            - "BATFISH_GITHUB_BATFISH_REPO=${BATFISH_GITHUB_BATFISH_REPO}"
${COMMON_STEP_ATTRIBUTES}
EOF

cat <<EOF
  - label: ":python: Build pybatfish"
    command:
      - ".buildkite/build_pybatfish.sh"
    artifact_paths:
      - artifacts/pybatfish*.whl
      - artifacts/pybatfish-tag.txt
      - artifacts/pybatfish-version.txt
      - artifacts/pybatfish-tests.tgz
      - artifacts/pybatfish-notebooks.tgz
    plugins:
      - docker#${DOCKER_PLUGIN_VERSION}:
          image: "${BATFISH_DOCKER_CI_BASE_IMAGE}"
          always-pull: true
          environment:
            - "BATFISH_GITHUB_PYBATFISH_REF=${BATFISH_GITHUB_PYBATFISH_REF}"
            - "BATFISH_GITHUB_PYBATFISH_REPO=${BATFISH_GITHUB_PYBATFISH_REPO}"
            - "BATFISH_VERSION_STRING=${BATFISH_VERSION_STRING}"
${COMMON_STEP_ATTRIBUTES}
EOF
# Use SSH for upload pipeline
if [ "${BUILDKITE_PIPELINE_ID}" == "${BATFISH_UPLOAD_PIPELINE}" ]; then
cat <<EOF
          mount-ssh-agent: true
          volumes:
            - "${HOME}/.ssh/known_hosts:/home/batfish/.ssh/known_hosts"
EOF
fi

###### WAIT between initial build and docker container build
cat <<EOF
  - wait
EOF

cat <<EOF
  - label: ":docker: Build Batfish container"
    command:
      - ".buildkite/docker_build_batfish.sh batfish.tar"
    artifact_paths:
      - artifacts/batfish.tar
${COMMON_STEP_ATTRIBUTES}
EOF

###### WAIT between initial docker build and initial tests
cat <<EOF
  - wait
EOF

cat <<EOF
  - label: ":pytest: Test Batfish container w/ Pybatfish"
    command:
      - ".buildkite/test_batfish_container.sh batfish.tar"
${COMMON_STEP_ATTRIBUTES}
  - label: ":docker: Build Allinone container"
    command:
      - ".buildkite/docker_build_allinone.sh batfish.tar allinone.tar"
    artifact_paths:
      - artifacts/allinone.tar
${COMMON_STEP_ATTRIBUTES}
EOF

###### WAIT between allinone docker build and allinone tests
cat <<EOF
  - wait
EOF

cat <<EOF
  - label: ":docker::pytest: Test Allinone container"
    command:
      - ".buildkite/test_allinone_container.sh allinone.tar"
${COMMON_STEP_ATTRIBUTES}
EOF


###### End pre-commit-only steps and begin upload steps here
cat <<EOF
  - label: ":arrow_up::docker: Upload test containers"
    if: pipeline.id == "${BATFISH_UPLOAD_PIPELINE}"
    command:
      - ".buildkite/push_test_image.sh batfish.jar batfish"
      - ".buildkite/push_test_image.sh allinone.jar allinone"
    plugins:
      - docker-login#${DOCKER_LOGIN_PLUGIN_VERSION}:
          username: ${DOCKER_LOGIN_PLUGIN_USERNAME}
          password-env: DOCKER_LOGIN_PLUGIN_PASSWORD
${COMMON_STEP_ATTRIBUTES}
EOF

cat <<EOF
  - label: ":python: Test PyPI release"
    if: pipeline.id == "${BATFISH_UPLOAD_PIPELINE}"
    command:
      - ".buildkite/publish_pybf_test.sh"
    plugins:
      - docker#${DOCKER_PLUGIN_VERSION}:
          image: "${BATFISH_DOCKER_CI_BASE_IMAGE}"
          always-pull: true
          mount-buildkite-agent: true
          mount-ssh-agent: true
          volumes:
            - "${HOME}/.ssh/known_hosts:/home/batfish/.ssh/known_hosts"
          environment:
            - "PYBF_TEST_PYPI_TOKEN=${PYBF_TEST_PYPI_TOKEN-}"
      - artifacts#${ARTIFACTS_PLUGIN_VERSION}:
          download:
            - artifacts/pybatfish-tag.txt
            - artifacts/pybatfish-version.txt
            - artifacts/pybatfish-*.whl
${COMMON_STEP_ATTRIBUTES}
EOF


cat <<EOF
  - block: ":chrome::firefox::ie::safari::edge: Manual testing"
    if: pipeline.id == "${BATFISH_UPLOAD_PIPELINE}"
    prompt: >-
      Perform manual testing. Instructions at
      https://docs.google.com/document/d/15XWSdyHApnVbmZCg3FKpu6ree2HGDysmgYNFhbqTj1Q/
      Your build number is: ${BUILDKITE_BUILD_NUMBER}
    fields:
      - select: "Artifact tag"
        key: "release-tag"
        default: "test"
        options:
          - label: "Public release"
            value: "latest"
          - label: "Test use only"
            value: "test"
      - select: "Artifact(s) to release"
        key: "artifacts-to-release"
        multiple: true
        options:
          - label: "Pybf (note: does not automatically push to PyPI yet)"
            value: "pybf"
          - label: "Bf containers"
            value: "bf"
EOF

cat <<EOF
  - label: ":rocket: Container release"
    if: pipeline.id == "${BATFISH_UPLOAD_PIPELINE}"
    command:
      - ".buildkite/promote_tags.sh"
    plugins:
      - docker-login#${DOCKER_LOGIN_PLUGIN_VERSION}:
            username: ${DOCKER_LOGIN_PLUGIN_USERNAME}
            password-env: DOCKER_LOGIN_PLUGIN_PASSWORD
    env:
      BATFISH_VERSION_STRING: ${BATFISH_VERSION_STRING}
${COMMON_STEP_ATTRIBUTES}
EOF

cat <<EOF
### Pybatfish PyPI project does not exist yet, so can cannot automatically push yet
#  - label: ":python: PyPI release"
#    if: pipeline.id == "${BATFISH_UPLOAD_PIPELINE}"
#    command:
#      - ".buildkite/publish_pybf.sh"
#    agents:
#      queue: 'open-source-default'
#    plugins:
#      - docker#${DOCKER_PLUGIN_VERSION}:
#          image: "${BATFISH_DOCKER_CI_BASE_IMAGE}"
#          always-pull: true
#          mount-buildkite-agent: true
#          mount-ssh-agent: true
#          volumes:
#            - "${HOME}/.ssh/known_hosts:/home/batfish/.ssh/known_hosts"
#          environment:
#            - "BATFISH_VERSION_STRING=${BATFISH_VERSION_STRING}"
#            - "PYBF_PYPI_TOKEN=${PYBF_PYPI_TOKEN-}"
#            - "BATFISH_GITHUB_PYBATFISH_REF=${BATFISH_GITHUB_PYBATFISH_REF}"
#            - "BATFISH_GITHUB_PYBATFISH_REPO=${BATFISH_GITHUB_PYBATFISH_REPO}"
#      - artifacts#${ARTIFACTS_PLUGIN_VERSION}:
#          download:
#            - artifacts/pybatfish-tag.txt
#            - artifacts/pybatfish-version.txt
#            - artifacts/pybatfish-*.whl
EOF
