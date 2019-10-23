#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")"/common_vars.sh
mkdir $ARTIFACT_DIR

# Build Pybatfish
PYBF_DIR=$(mktemp -d)
git clone --depth=1 --branch=${BATFISH_GITHUB_PYBATFISH_REF} ${BATFISH_GITHUB_PYBATFISH_REPO} ${PYBF_DIR}
pushd ${PYBF_DIR}
  PYBF_TAG=$(git rev-parse --short HEAD)
  # Sane in-place version replace: https://stackoverflow.com/a/22084103
  sed -i.bak -e "s/^__version__ = .*$/__version__ = \"${BATFISH_VERSION_STRING}\"/" pybatfish/__init__.py
  rm -f pybatfish/__init__.py.bak
  python3 -m virtualenv .venv
  source .venv/bin/activate
  pip install setuptools
  python setup.py bdist_wheel
  PYBF_VERSION=$(python setup.py --version)
popd

# Copy artifacts
cp ${PYBF_DIR}/dist/pybatfish*.whl ${ARTIFACT_DIR}
tar -czf ${ARTIFACT_DIR}/pybatfish-tests.tgz -C ${PYBF_DIR} tests
tar -czf ${ARTIFACT_DIR}/pybatfish-notebooks.tgz -C ${PYBF_DIR} jupyter_notebooks
echo "${PYBF_TAG}" > ${ARTIFACT_DIR}/pybatfish-tag.txt
echo "${PYBF_VERSION}" > ${ARTIFACT_DIR}/pybatfish-version.txt
