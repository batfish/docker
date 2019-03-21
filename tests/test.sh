#!/bin/bash
set -e

# Start both jupyter and batfish
echo starting wrapper
sh wrapper.sh&

echo performing setup
apt-get update
apt-get install -y git curl

pushd pybatfish
# Install test dependencies
pip3 install .[dev]

echo waiting for batfish to start
# Poll until we can connect to the coordinator
COUNTER=0
while ! curl http://localhost:9996/
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

echo starting unit tests
# Integration tests are skipped by --ignore setting in setup.cfg
pytest tests
echo starting integration tests
pytest tests/integration
echo done with tests
popd
