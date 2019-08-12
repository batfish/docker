#!/usr/bin/env bash
set -euox pipefail

PYBF_VERSION=$(cat /assets/pybatfish-version.txt)
MAX_BATFISH_STARTUP_WAIT=20

# Setup conda so we can avoid permission issues setting up Python as non-root user
curl -o conda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash conda.sh -b -p $HOME/miniconda
export PATH="$HOME/miniconda/bin:$PATH"
conda create -y -n conda_env python=3.7.3
source activate conda_env

pip install /assets/pybatfish-${PYBF_VERSION}-py2.py3-none-any.whl[dev]

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
tar xzf /assets/questions.tgz -C ${TEMP_DIR}
tar xzf /assets/pybatfish-tests.tgz -C ${TEMP_DIR}
tar xzf /assets/pybatfish-notebooks.tgz -C ${TEMP_DIR}
pytest ${TEMP_DIR}/tests/integration
