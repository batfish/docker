#!/usr/bin/env bash
### Build and quick lint
set -e
cat <<EOF
steps:
  - label: "Diagnostics"
    command: "netstat -tunpl"

  - label: "Build Images"
    command: ".buildkite/build.sh"
    plugins:
      - docker#v1.1.1:
          image: "dhalperi/build-base:latest"
      - artifacts#v1.2.0:
          download:
            - "workspace/allinone.jar"
            - "workspace/questions.tar"
          build: "\${BUILDKITE_TRIGGERED_FROM_BUILD_ID}"
EOF

