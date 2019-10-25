#!/usr/bin/env bash
set -euo pipefail

BATFISH_DOCKER_CI_BASE_IMAGE="${BATFISH_DOCKER_CI_BASE_IMAGE:-batfish/ci-base:latest}"
BATFISH_DOCKER_CI_DOCKER_IMAGE="${BATFISH_DOCKER_CI_DOCKER_IMAGE:-batfish/ci-base:test-docker}"
BATFISH_GITHUB_BATFISH_REF="${BATFISH_GITHUB_BATFISH_REF:-master}"
BATFISH_GITHUB_BATFISH_REPO="${BATFISH_GITHUB_BATFISH_REPO:-https://github.com/batfish/batfish}"
BATFISH_GITHUB_PYBATFISH_REF="${BATFISH_GITHUB_PYBATFISH_REF:-master}"
BATFISH_GITHUB_PYBATFISH_REPO="${BATFISH_GITHUB_PYBATFISH_REPO:-https://github.com/batfish/pybatfish}"
DOCKER_LOGIN_PLUGIN_VERSION="${DOCKER_LOGIN_PLUGIN_VERSION:-v2.0.1}"
DOCKER_LOGIN_PLUGIN_USERNAME="${DOCKER_LOGIN_PLUGIN_USERNAME:-batfishbuildkitebot}"
DOCKER_PLUGIN_VERSION="${DOCKER_PLUGIN_VERSION:-v3.3.0}"

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
          environment:
            - "BATFISH_GITHUB_PYBATFISH_REF=${BATFISH_GITHUB_PYBATFISH_REF}"
            - "BATFISH_GITHUB_PYBATFISH_REPO=${BATFISH_GITHUB_PYBATFISH_REPO}"
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
  - wait
EOF

cat <<EOF
  - label: ":snake: dev <-> :batfish: dev"
    command:
      - ".buildkite/test_batfish_container.sh"
    agents:
      queue: 'open-source-default'
  - label: ":snake: dev <-> :batfish: prod"
    command:
      - ".buildkite/test_batfish_container.sh"
    env:
      BATFISH_CONTAINER_TAG: latest
      PYBATFISH_PYTEST_ARGS: '-k "not test_notebook_output"'
    agents:
      queue: 'open-source-default'
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
    # Only run on release pipeline
    if: pipeline.id == "f283deec-7e26-4f46-b8c6-b95b0cc1d974"
    prompt: >-
      Perform manual testing. Instructions at
      https://docs.google.com/document/d/15XWSdyHApnVbmZCg3FKpu6ree2HGDysmgYNFhbqTj1Q/
      Your build number is: ${BUILDKITE_BUILD_NUMBER}
    fields:
      - select: "Docker image tag"
        key: "release-docker-tag"
        default: "test"
        options:
          - label: "Public release"
            value: "latest"
          - label: "Test use only"
            value: "test"
EOF

cat <<EOF
  - label: ":rocket: Release!"
    # Only run on release pipeline
    if: pipeline.id == "f283deec-7e26-4f46-b8c6-b95b0cc1d974"
    command:
      - ".buildkite/promote_tags.sh"
    plugins:
      - docker-login#${DOCKER_LOGIN_PLUGIN_VERSION}:
            username: ${DOCKER_LOGIN_PLUGIN_USERNAME}
            password-env: DOCKER_LOGIN_PLUGIN_PASSWORD
    agents:
      queue: 'open-source-default'
EOF
