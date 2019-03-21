#!/bin/bash
set -e

MAX_BATFISH_STARTUP_WAIT=20

# Start both Jupyter and Batfish
echo Starting wrapper
sh wrapper.sh&

echo Performing setup
apt-get update
apt-get install -y curl

pushd pybatfish
# Install test dependencies
pip3 install .[dev]

echo Waiting for batfish to start
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

echo Starting unit tests
# Integration tests are skipped by --ignore setting in setup.cfg
# Skip generating .pytest_cache
pytest -p no:cacheprovider tests
echo Starting integration tests
pytest -p no:cacheprovider tests/integration
echo Done with tests
# Remove pycache
py3clean .
popd
while true
do
  sleep 1
done