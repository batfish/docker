#!/usr/bin/env bash
set -euo pipefail

BATFISH_DOCKER_CI_BASE_IMAGE="${BATFISH_DOCKER_CI_BASE_IMAGE:-batfish/ci-base:latest}"
BATFISH_DOCKER_CI_DOCKER_IMAGE="${BATFISH_DOCKER_CI_DOCKER_IMAGE:-batfish/ci-base:test-docker}"
BATFISH_GITHUB_BATFISH_REF="${BATFISH_GITHUB_BATFISH_REF:-master}"
BATFISH_GITHUB_BATFISH_REPO="${BATFISH_GITHUB_BATFISH_REPO:-https://github.com/batfish/batfish}"
BATFISH_GITHUB_PYBATFISH_REF="${BATFISH_GITHUB_PYBATFISH_REF:-master}"
BATFISH_GITHUB_PYBATFISH_REPO="${BATFISH_GITHUB_PYBATFISH_REPO:-git@github.com:batfish/pybatfish.git}"
DOCKER_LOGIN_PLUGIN_VERSION="${DOCKER_LOGIN_PLUGIN_VERSION:-v2.0.1}"
DOCKER_LOGIN_PLUGIN_USERNAME="${DOCKER_LOGIN_PLUGIN_USERNAME:-batfishbuildkitebot}"

ARTIFACTS_PLUGIN_VERSION="${ARTIFACTS_PLUGIN_VERSION:-v1.2.0}"
DOCKER_PLUGIN_VERSION="${DOCKER_PLUGIN_VERSION:-v3.3.0}"

BATFISH_VERSION_STRING="${BATFISH_VERSION_STRING:-$(date +'%Y.%m.%d').${BUILDKITE_BUILD_NUMBER}}"

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
    agents:
      queue: 'open-source-default'
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
          mount-ssh-agent: true
          environment:
            - "BATFISH_GITHUB_PYBATFISH_REF=${BATFISH_GITHUB_PYBATFISH_REF}"
            - "BATFISH_GITHUB_PYBATFISH_REPO=${BATFISH_GITHUB_PYBATFISH_REPO}"
            - "BATFISH_VERSION_STRING=${BATFISH_VERSION_STRING}"
    agents:
      queue: 'open-source-default'
  - wait
EOF

cat <<EOF
  - label: ":docker: Build Batfish container"
    command:
      - ".buildkite/docker_build_batfish.sh"
    plugins:
      - docker-login#${DOCKER_LOGIN_PLUGIN_VERSION}:
            username: ${DOCKER_LOGIN_PLUGIN_USERNAME}
            password-env: DOCKER_LOGIN_PLUGIN_PASSWORD
    agents:
      queue: 'open-source-default'
  # TODO move later in pipeline
  - label: ":python: Test PyPI release"
    command:
      - ".buildkite/publish_pybf_test.sh"
    agents:
      queue: 'open-source-default'
    plugins:
      - docker#${DOCKER_PLUGIN_VERSION}:
          image: "${BATFISH_DOCKER_CI_BASE_IMAGE}"
          always-pull: true
          mount-buildkite-agent: true
          mount-ssh-agent: true
          volumes:
            - "${HOME}/.ssh/known_hosts:/home/batfish/.ssh/known_hosts"
          environment:
            - "PYBF_TEST_PYPI_TOKEN=${PYBF_TEST_PYPI_TOKEN}"
      - artifacts#${ARTIFACTS_PLUGIN_VERSION}:
          download:
            - artifacts/pybatfish-tag.txt
            - artifacts/pybatfish-version.txt
            - artifacts/pybatfish-*.whl
  - wait
EOF

cat <<EOF
  - label: ":pytest: Test Batfish container w/ Pybatfish"
    command:
      - ".buildkite/test_batfish_container.sh"
  - label: ":docker: Build Allinone container"
    command:
      - ".buildkite/docker_build_allinone.sh"
    plugins:
      - docker-login#${DOCKER_LOGIN_PLUGIN_VERSION}:
            username: ${DOCKER_LOGIN_PLUGIN_USERNAME}
            password-env: DOCKER_LOGIN_PLUGIN_PASSWORD
    agents:
      queue: 'open-source-default'
  - wait
EOF

cat <<EOF
  - label: ":docker::pytest: Test Allinone container"
    command:
      - ".buildkite/test_allinone_container.sh"
    agents:
      queue: 'open-source-default'
EOF


cat <<EOF
  - block: ":chrome::firefox::ie::safari::edge: Manual testing"
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
          - label: "Pybf"
            value: "pybf"
          - label: "Bf containers"
            value: "bf"
EOF

cat <<EOF
  - label: ":rocket: Container release"
    command:
      - ".buildkite/promote_tags.sh"
    plugins:
      - docker-login#${DOCKER_LOGIN_PLUGIN_VERSION}:
            username: ${DOCKER_LOGIN_PLUGIN_USERNAME}
            password-env: DOCKER_LOGIN_PLUGIN_PASSWORD
    agents:
      queue: 'open-source-default'
    env:
      BATFISH_VERSION_STRING: ${BATFISH_VERSION_STRING}
  - label: ":python: PyPI release"
    command:
      - ".buildkite/publish_pybf.sh"
    agents:
      queue: 'open-source-default'
    plugins:
      - docker#${DOCKER_PLUGIN_VERSION}:
          image: "${BATFISH_DOCKER_CI_BASE_IMAGE}"
          always-pull: true
          mount-buildkite-agent: true
          mount-ssh-agent: true
          volumes:
            - "${HOME}/.ssh/known_hosts:/home/batfish/.ssh/known_hosts"
          environment:
            - "BATFISH_VERSION_STRING=${BATFISH_VERSION_STRING}"
            # Project and therefore token won't exist until after initial PyPI push
            - "PYBF_PYPI_TOKEN=${PYBF_PYPI_TOKEN-}"
            - "BATFISH_GITHUB_PYBATFISH_REF=${BATFISH_GITHUB_PYBATFISH_REF}"
            - "BATFISH_GITHUB_PYBATFISH_REPO=${BATFISH_GITHUB_PYBATFISH_REPO}"
      - artifacts#${ARTIFACTS_PLUGIN_VERSION}:
          download:
            - artifacts/pybatfish-tag.txt
            - artifacts/pybatfish-version.txt
            - artifacts/pybatfish-*.whl

EOF
