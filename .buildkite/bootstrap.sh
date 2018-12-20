#!/usr/bin/env bash
CONFIG_FILE="/etc/buildkite-agent/buildkite-agent.cfg"

put_config() {
  KEY="$1"
  VALUE="$2"
  if grep "${KEY}" "${CONFIG_FILE}" >&/dev/null; then
    sed -i -e "s/${KEY}=.*/${KEY}=${VALUE}/g" "${CONFIG_FILE}"
  else
    mkdir -p "$(dirname "${CONFIG_FILE}")"
    echo "${KEY}=${VALUE}" >> "${CONFIG_FILE}"
  fi
}

put_config "git-clean-flags" "-xdqff"

