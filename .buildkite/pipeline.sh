#!/usr/bin/env bash
### Build and quick lint
set -e
cat <<EOF
steps:
  - label: "Build Images"
    command: 
      - ". .buildkite/docker_login.sh"
      - ".buildkite/download_artifacts.sh"
      - ".buildkite/build.sh"
    plugins:
      - docker#v2.1.0:
          image: "arifogel/batfish-docker-build-base:latest"
          always-pull: true
          environment:
            - "DOCKER_BOT_PASSWORD"
            - "DOCKER_BOT_USER"
          volumes:
            - ".:/workdir"
            - "/var/run/docker.sock:/var/run/docker.sock"
          workdir: "/workdir"
EOF

