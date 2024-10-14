#!/usr/bin/env bash
set -euox pipefail

MAX_BATFISH_STARTUP_WAIT=20

# Setup conda so we can avoid permission issues setting up Python as non-root user
curl -o conda.sh https://repo.anaconda.com/miniconda/Miniconda3-4.7.12.1-Linux-x86_64.sh
bash conda.sh -b -p $HOME/miniconda
export PATH="$HOME/miniconda/bin:$PATH"
# pip 20.3 has problems resolving dependencies correctly, so pin to last working version
# See related resolver issue: https://github.com/pypa/pip/issues/9187
conda create -y -n conda_env python=3.9 pip=20.2.4
source activate conda_env

# Install specific version of Pybatfish if specified, otherwise use the available version/wheel artifacts
if [ "${PYBATFISH_VERSION-}" == "" ]; then
    PYBF_VERSION=$(cat /assets/pybatfish-version.txt)
    pip install /assets/pybatfish-${PYBF_VERSION}-py3-none-any.whl[dev]
else
    # Install from test PyPI for now (until it is on real PyPI)
    pip install ${PYBATFISH_VERSION}
fi

# Poll until we can connect to the container
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

TEMP_DIR=$(mktemp -d)
tar xzf /assets/pybatfish-tests.tgz -C ${TEMP_DIR}
tar xzf /assets/pybatfish-notebooks.tgz -C ${TEMP_DIR}

# Use eval here to evaluate quotes in pytest args before spaces
# e.g. permit the following as two items:
#   -k "not test_name"
# instead of treating it like three items (`-k`, `"not`, and `test_name"`)
eval pytest ${PYBATFISH_PYTEST_ARGS:-} ${TEMP_DIR}/tests/integration
