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
pip install -i https://test.pypi.org/simple --extra-index-url https://pypi.org/simple pybatfish

# If we can successfully import something after installing from PyPI,
# then assume the upload was successful
python -c "from pybatfish.client.session import Session"
echo "Pybf import was successful!"
deactivate
