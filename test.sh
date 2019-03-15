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
pip3 install -e .[dev]
pip3 uninstall .

echo waiting for batfish to start
# Poll until we can connect to the container
while ! curl http://localhost:9996/
do
  echo "$(date) - waiting for Batfish to start"
  sleep 1
done
echo "$(date) - connected to Batfish"

echo starting tests
pytest tests/integration
echo done with tests
popd
