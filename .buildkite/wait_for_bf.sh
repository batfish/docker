#!/usr/bin/env bash
set -euox pipefail

# Number of seconds to wait for Batfish backend to start
MAX_BATFISH_STARTUP_WAIT="${MAX_BATFISH_STARTUP_WAIT:-20}"
BATFISH_HOST="${BATFISH_HOST:-localhost}"
BATFISH_PORT="${BATFISH_PORT:-9996}"

COUNTER=0
while ! curl http://${BATFISH_HOST}:${BATFISH_PORT}/
do
  if [ $COUNTER -gt $MAX_BATFISH_STARTUP_WAIT ]; then
    echo "Batfish took too long to start, aborting"
    exit 1
  fi
  echo "$(date) - waiting for Batfish to start"
  sleep 1
  ((COUNTER+=1))
done
echo "$(date) - connected to Batfish"
