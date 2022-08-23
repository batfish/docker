#!/usr/bin/env bash
set -euo pipefail

BUILDKITE_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${BUILDKITE_DIR}/common_vars.sh"

BATFISH_UPLOAD_PIPELINE="f283deec-7e26-4f46-b8c6-b95b0cc1d974"

BATFISH_DOCKER_CI_BASE_IMAGE="${BATFISH_DOCKER_CI_BASE_IMAGE:-batfish/ci-base:5d92c2f-14e42dd2de}"
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

# Only test Bf containers less than this many days old
BATFISH_MAX_TEST_CONTAINER_AGE="${BATFISH_MAX_TEST_CONTAINER_AGE:-31}"

# Attributes common to all command steps
COMMON_STEP_ATTRIBUTES=
# Specify queue for upload builds
if [ "${BUILDKITE_PIPELINE_ID}" == "${BATFISH_UPLOAD_PIPELINE}" ]; then
COMMON_STEP_ATTRIBUTES=$(cat <<EOF
    agents:
      queue: 'open-source-default'
EOF
)
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
    key: bf-jar
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
            - "BATFISH_VERSION_STRING=${BATFISH_VERSION_STRING}"
${COMMON_STEP_ATTRIBUTES}
EOF

cat <<EOF
  - label: ":ferris_wheel: Build pybatfish"
${COMMON_STEP_ATTRIBUTES}
    key: pybf
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
EOF
# Use SSH for upload pipeline, this needs to come RIGHT after the `plugins` section in the preceeding step
if [ "${BUILDKITE_PIPELINE_ID}" == "${BATFISH_UPLOAD_PIPELINE}" ]; then
cat <<EOF
          mount-ssh-agent: true
          volumes:
            - "${HOME}/.ssh/known_hosts:/home/batfish/.ssh/known_hosts"
EOF
fi

cat <<EOF
  - label: ":docker: Build Batfish container"
    key: bf
    depends_on: bf-jar
    command:
      - ".buildkite/docker_build_batfish.sh batfish.tar"
    env:
      BATFISH_VERSION_STRING: ${BATFISH_VERSION_STRING}
    artifact_paths:
      - artifacts/batfish.tar
${COMMON_STEP_ATTRIBUTES}
EOF

cat <<EOF
  - label: ":pytest: Test Batfish container w/ Pybatfish"
    depends_on:
      - bf
      - pybf
    command:
      - "df -h /tmp"
      - ".buildkite/test_batfish_container.sh batfish.tar"
${COMMON_STEP_ATTRIBUTES}
  - label: ":docker: Build Allinone container"
    key: allinone
    depends_on:
      - bf
      - pybf
    command:
      - ".buildkite/docker_build_allinone.sh batfish.tar allinone.tar"
    artifact_paths:
      - artifacts/allinone.tar
${COMMON_STEP_ATTRIBUTES}
EOF

cat <<EOF
  - label: ":pytest: Test Allinone container"
    depends_on:
      - allinone
      - pybf
    command:
      - "df -h /tmp"
      - ".buildkite/test_allinone_container.sh allinone.tar"
${COMMON_STEP_ATTRIBUTES}
EOF


###### Upload containers
cat <<EOF
  - label: ":arrow_up::docker: Upload Batfish container"
    if: pipeline.id == "${BATFISH_UPLOAD_PIPELINE}"
    key: bf-upload
    depends_on:
      - bf
    command:
      - ".buildkite/push_test_image.sh batfish.tar batfish"
    plugins:
      - docker-login#${DOCKER_LOGIN_PLUGIN_VERSION}:
          username: ${DOCKER_LOGIN_PLUGIN_USERNAME}
          password-env: DOCKER_LOGIN_PLUGIN_PASSWORD
${COMMON_STEP_ATTRIBUTES}
EOF

cat <<EOF
  - label: ":arrow_up::docker: Upload Allinone container"
    if: pipeline.id == "${BATFISH_UPLOAD_PIPELINE}"
    key: allinone-upload
    depends_on:
      - allinone
    command:
      - ".buildkite/push_test_image.sh allinone.tar allinone"
    plugins:
      - docker-login#${DOCKER_LOGIN_PLUGIN_VERSION}:
          username: ${DOCKER_LOGIN_PLUGIN_USERNAME}
          password-env: DOCKER_LOGIN_PLUGIN_PASSWORD
${COMMON_STEP_ATTRIBUTES}
EOF

cat <<EOF
  - group: ":trivy::docker: Scan containers"
    if: pipeline.id == "${BATFISH_UPLOAD_PIPELINE}"
    depends_on:
      - bf-upload
      - allinone-upload
    steps:
      - name: "{{matrix.container}}"
        command:
          - "trivy image --ignore-unfixed --exit-code 1 --severity HIGH,CRITICAL batfish/{{matrix.container}}:${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER}"
        plugins:
          - docker#${DOCKER_PLUGIN_VERSION}:
              image: "${BATFISH_DOCKER_CI_BASE_IMAGE}"
              always-pull: true
        agents:
          queue: 'open-source-default'
        matrix:
          setup:
            container:
              - batfish
              - allinone
EOF

# Get (Unix time) timestamp for the oldest container we would test
MIN_TIMESTAMP=$(date -d "$(date +%Y-%m-%d) - ${BATFISH_MAX_TEST_CONTAINER_AGE} day" +%s)

# Newline separated, double quoted container tags that contain '202', e.g. "2022.08.22.1234" or "test-1202"
CONTAINER_TAGS="$(wget -q -O - 'https://hub.docker.com/v2/repositories/batfish/batfish/tags/?name=202&page_size=100' | grep -Po '(?<="name":)"[^"]*"')"
# Get tags that start with dates (e.g. YYYY.M.D.# or YYYY.MM.DD) and remove double quotes
DATE_TAGS=$(echo "$CONTAINER_TAGS" | grep -o '"[0-9]\{4\}\.[0-9]\{1,2\}\.[0-9]\{1,2\}\(\.[0-9]\+\)\?"' | sed 's/"//g')

# Run integration tests on recent Batfish containers
while read bf_tag; do
# Convert YYYY.M.D format into (Unix time) timestamp that we can compare
TAG_TIMESTAMP=$(date -d $(echo ${bf_tag} | grep -o '[0-9]\{4\}\.[0-9]\{1,2\}\.[0-9]\{1,2\}' | sed 's/\./-/g') +"%s")
if [[ ${MIN_TIMESTAMP} -le ${TAG_TIMESTAMP} ]]; then
cat <<EOF
  - label: ":snake: dev <-> :batfish: ${bf_tag}"
    depends_on: pybf
    if: pipeline.id == "${BATFISH_UPLOAD_PIPELINE}"
    command:
      - ".buildkite/test_batfish_container.sh"
    env:
      BATFISH_CONTAINER_TAG: ${bf_tag}
      # Determines which Pybatfish integration tests are run
      bf_version: ${bf_tag}
      # Skip notebook ref tests
      PYBATFISH_PYTEST_ARGS: '-k "not test_notebook_output"'
${COMMON_STEP_ATTRIBUTES}
EOF
fi
done <<< "${DATE_TAGS}"

cat <<EOF
  - label: ":snake: dev <-> :batfish: prod"
    depends_on: pybf
    if: pipeline.id == "${BATFISH_UPLOAD_PIPELINE}"
    command:
      - ".buildkite/test_batfish_container.sh"
    env:
      BATFISH_CONTAINER_TAG: latest
      # Skip notebook ref tests
      PYBATFISH_PYTEST_ARGS: '-k "not test_notebook_output"'
${COMMON_STEP_ATTRIBUTES}
  - label: ":snake: dev <-> :batfish: dev"
    depends_on:
      - bf-upload
      - pybf
    if: pipeline.id == "${BATFISH_UPLOAD_PIPELINE}"
    command:
      - ".buildkite/test_batfish_container.sh"
${COMMON_STEP_ATTRIBUTES}
EOF

# Get available Pybatfish versions from PyPI
python -m pip install --user 'requests==2.23.0' >/dev/null
PYBF_TAGS=$(python -c "import requests; print('\n'.join(requests.get('https://pypi.python.org/pypi/pybatfish/json').json()['releases'].keys()))")

while read pybf_tag; do
# Convert tag from YYYY.M.D to YYYY-M-D and just drop tags that do not start with four digits (need || true; to avoid erroring when regex doesn't match)
PARSED_TAG=$(echo ${pybf_tag} | { grep -o '[0-9]\{4\}\.[0-9]\{1,2\}\.[0-9]\{1,2\}' || true; } | sed 's/\./-/g')
# Only consider tags that look like dates
if [[ "${PARSED_TAG}" != "" ]]; then
# Convert YYYY-M-D format into (comparable Unix time) timestamp
TAG_TIMESTAMP=$(date -d "${PARSED_TAG}" +"%s")
if [[ ${MIN_TIMESTAMP} -le ${TAG_TIMESTAMP} ]]; then
cat <<EOF
  - label: ":snake: ${pybf_tag} <-> :batfish: dev"
    depends_on: bf-upload
    if: pipeline.id == "${BATFISH_UPLOAD_PIPELINE}"
    command:
      - ".buildkite/test_batfish_container.sh"
    env:
      # Skip notebook ref tests
      PYBATFISH_PYTEST_ARGS: '-k "not test_notebook_output"'
      # Install specific version of Pybatfish from PyPI
      PYBATFISH_VERSION: "pybatfish[dev]==${pybf_tag}"
${COMMON_STEP_ATTRIBUTES}
EOF
fi
fi
done <<< "${PYBF_TAGS}"

cat <<EOF
  - label: ":snake: prod <-> :batfish: dev"
    depends_on: bf-upload
    if: pipeline.id == "${BATFISH_UPLOAD_PIPELINE}"
    command:
      - ".buildkite/test_batfish_container.sh"
    env:
      # Skip notebook ref tests
      PYBATFISH_PYTEST_ARGS: '-k "not test_notebook_output"'
      # Install specific version of Pybatfish from PyPI
      PYBATFISH_VERSION: "pybatfish[dev]"
${COMMON_STEP_ATTRIBUTES}
EOF

cat <<EOF
  - label: ":python: Test PyPI release"
    depends_on: pybf
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
            - "BATFISH_VERSION_STRING=${BATFISH_VERSION_STRING}"
            - "PYBF_TEST_PYPI_TOKEN=${PYBF_TEST_PYPI_TOKEN-}"
      - artifacts#${ARTIFACTS_PLUGIN_VERSION}:
          download:
            - artifacts/pybatfish-tag.txt
            - artifacts/pybatfish-version.txt
            - artifacts/pybatfish-*.whl
${COMMON_STEP_ATTRIBUTES}
EOF

###### WAIT for all tests to let users unblock
cat <<EOF
  - wait
EOF

cat <<EOF
  - block: ":chrome::firefox::ie::safari::edge: Manual testing"
    if: pipeline.id == "${BATFISH_UPLOAD_PIPELINE}"
    prompt: >-
      Perform manual testing. Instructions at
      https://docs.google.com/document/d/15XWSdyHApnVbmZCg3FKpu6ree2HGDysmgYNFhbqTj1Q/
      Your build number is: ${BUILDKITE_BUILD_NUMBER}
      Version string is: ${BATFISH_VERSION_STRING}
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
  - label: ":docker::rocket: Container release"
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
  - label: ":python::rocket: PyPI release"
    if: pipeline.id == "${BATFISH_UPLOAD_PIPELINE}"
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
            - "PYBF_PYPI_TOKEN=${PYBF_PYPI_TOKEN-}"
            - "BATFISH_GITHUB_PYBATFISH_REF=${BATFISH_GITHUB_PYBATFISH_REF}"
            - "BATFISH_GITHUB_PYBATFISH_REPO=${BATFISH_GITHUB_PYBATFISH_REPO}"
      - artifacts#${ARTIFACTS_PLUGIN_VERSION}:
          download:
            - artifacts/pybatfish-tag.txt
            - artifacts/pybatfish-version.txt
            - artifacts/pybatfish-*.whl
EOF
