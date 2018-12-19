#!/usr/bin/env bash
### Build and quick lint
set -e
cat <<EOF
steps:
  - label: "Build Images"
    command: 
      - "python3 .buildkite/write_password.py"
      - "unset DOCKER_BOT_PASSWORD"
      - "docker login --username=batfishbuildkitebot --password-stdin < docker_bot_password"
      - ".buildkite/build.sh"
    plugins:
      - docker#v2.1.0:
          image: "arifogel/batfish-docker-build-base:latest"
          always-pull: true
          environment:
            - "DOCKER_BOT_PASSWORD"
          network: "host"
          volumes:
            - ".:/workdir"
            - "/var/run/docker.sock:/var/run/docker.sock"
          workdir: "/workdir"
EOF
### If triggered from another pipeline, we need to download artifacts
if [ -n "${BUILDKITE_TRIGGERED_FROM_BUILD_ID}" ]; then
  cat <<EOF
      - artifacts#v1.2.0:
          build: "\${BUILDKITE_TRIGGERED_FROM_BUILD_ID}"
          download:
EOF
  ### If triggered from batfish, download batfish artifacts
  if [ "${BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG}" = "batfish" ]; then
    cat <<EOF
            - "workspace/allinone.jar"
            - "workspace/questions.tar"
EOF
  fi
fi
