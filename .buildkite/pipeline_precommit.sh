#!/usr/bin/env bash
set -euo pipefail

BATFISH_DOCKER_CI_BASE_IMAGE="${BATFISH_DOCKER_CI_BASE_IMAGE:-batfish/ci-base:latest}"
BATFISH_DOCKER_CI_DOCKER_IMAGE="${BATFISH_DOCKER_CI_DOCKER_IMAGE:-batfish/ci-base:test-docker}"
BATFISH_GITHUB_BATFISH_REF="${BATFISH_GITHUB_BATFISH_REF:-master}"
BATFISH_GITHUB_BATFISH_REPO="${BATFISH_GITHUB_BATFISH_REPO:-https://github.com/batfish/batfish}"
BATFISH_GITHUB_PYBATFISH_REF="${BATFISH_GITHUB_PYBATFISH_REF:-master}"
BATFISH_GITHUB_PYBATFISH_REPO="${BATFISH_GITHUB_PYBATFISH_REPO:-https://github.com/batfish/pybatfish}"
DOCKER_LOGIN_PLUGIN_VERSION="${DOCKER_LOGIN_PLUGIN_VERSION:-v2.0.1}"
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
  - wait
EOF

cat <<EOF
  - label: ":docker: Build Batfish container"
    command:
      - ".buildkite/docker_build_batfish.sh batfish.tar"
    artifact_paths:
      - artifacts/batfish.tar
  - wait
EOF

cat <<EOF
  - label: ":pytest: Test Batfish container w/ Pybatfish"
    command:
      - ".buildkite/test_batfish_container.sh batfish.tar"
  - label: ":docker: Build Allinone container"
    command:
      - ".buildkite/docker_build_allinone.sh batfish.tar allinone.tar"
    artifact_paths:
      - artifacts/allinone.tar
  - wait
EOF

cat <<EOF
  - label: ":docker::pytest: Test Allinone container"
    command:
      - ".buildkite/test_allinone_container.sh allinone.tar"
EOF


cat <<EOF
  - label: "Dummy step"
    # Only run on release pipeline
    if: pipeline.id == "f283deec-7e26-4f46-b8c6-b95b0cc1d974"
    command:
      - "echo hello"
EOF
