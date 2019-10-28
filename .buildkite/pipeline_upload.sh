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

# Only test Bf containers less than this many days old
BATFISH_MAX_TEST_CONTAINER_AGE="${BATFISH_MAX_TEST_CONTAINER_AGE:-31}"

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
          volumes:
            - "${HOME}/.ssh/known_hosts:/home/batfish/.ssh/known_hosts"
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
  - wait
EOF

# Get (Unix time) timestamp for the oldest container we would test
MIN_TIMESTAMP=$(date -d "$(date +%Y-%m-%d) - ${BATFISH_MAX_TEST_CONTAINER_AGE} day" +%s)

CONTAINER_TAGS=$(wget -q -O - https://registry.hub.docker.com/v1/repositories/batfish/batfish/tags)
# Get tags that start with dates (YYYY.M.D.#)
DATE_TAGS=$(echo "$CONTAINER_TAGS" | grep -o '"[0-9]\{4\}\.[0-9]\{1,2\}\.[0-9]\{1,2\}\(\.[0-9]\+\)\?"') | sed 's/"//g'

# Run integration tests on recent Batfish containers
while read bf_tag; do
# Convert YYYY.M.D format into (Unix time) timestamp that we can compare
TAG_TIMESTAMP=$(date -d $(echo ${bf_tag} | grep -o '[0-9]\{4\}\.[0-9]\{1,2\}\.[0-9]\{1,2\}' | sed 's/\./-/g') +"%s")
if [[ ${MIN_TIMESTAMP} -le ${TAG_TIMESTAMP} ]]; then
cat <<EOF
  - label: ":snake: dev <-> :batfish: ${bf_tag}"
    command:
      - ".buildkite/test_batfish_container.sh"
    env:
      BATFISH_CONTAINER_TAG: ${bf_tag}
      PYBATFISH_PYTEST_ARGS: '-k "not test_notebook_output"'
    agents:
      queue: 'open-source-default'
EOF
fi
done <<< "${DATE_TAGS}"

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
    env:
      BATFISH_VERSION_STRING: ${BATFISH_VERSION_STRING}
### Pybatfish PyPI project does not exist yet, so can cannot automatically push yet
#  - label: ":python: PyPI release"
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
