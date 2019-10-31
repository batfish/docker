#!/usr/bin/env bash
# Test that built wheel can be published and installed from test PyPI

set -euo pipefail

PYBF_VERSION=$(cat artifacts/pybatfish-version.txt)

python3 -m virtualenv .venv
. .venv/bin/activate
pip install twine
export TWINE_USERNAME="__token__"

echo "Uploading Pybf to test-PyPI"
export TWINE_PASSWORD=${PYBF_TEST_PYPI_TOKEN}
twine upload --repository-url https://test.pypi.org/legacy/ artifacts/pybatfish-${PYBF_VERSION}-py2.py3-none-any.whl
deactivate

# Install from test PyPI
python3 -m virtualenv testpypi
. testpypi/bin/activate

# Max retries before giving up on installing from PyPI
# Need retries because sometimes it takes a little while for newly uploaded package to propagate
MAX_RETRIES=2
COUNTER=0
while ! pip install -i https://test.pypi.org/simple --extra-index-url https://pypi.org/simple pybatfish==${BATFISH_VERSION_STRING}
do
  if [ $COUNTER -gt $MAX_RETRIES ]; then
    echo "Could not install Pybf"
    exit 1
  fi
  sleep 5
  ((COUNTER+=1))
done
echo "Pybf installed"

# If we can successfully import something after installing from PyPI,
# then assume the upload was successful
python -c "from pybatfish.client.session import Session"
echo "Pybf import was successful!"
deactivate
