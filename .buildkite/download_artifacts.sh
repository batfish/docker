#!/usr/bin/env bash
set -e
set -x
. /root/workdir/.venv-aws/bin/activate
S3_BUCKET="s3://batfish-build-artifacts-arifogel"
export BATFISH_TAR="artifacts/batfish/dev.tar"
export PYBATFISH_TAR="artifacts/pybatfish/dev.tar"
BATFISH_DIR="$(dirname "${BATFISH_TAR}")"
PYBATFISH_DIR="$(dirname "${PYBATFISH_TAR}")"
mkdir -p "${BATFISH_DIR}"
mkdir -p "${PYBATFISH_DIR}"
pushd "${BATFISH_DIR}"
aws s3 cp "${S3_BUCKET}/${BATFISH_TAR}" .
tar -x --no-same-owner -f dev.tar
[ -n "$(cat tag)" ]
popd
pushd "${PYBATFISH_DIR}"
aws s3 cp "${S3_BUCKET}/${PYBATFISH_TAR}" .
tar -x --no-same-owner -f dev.tar
[ -n "$(cat tag)" ]
popd
deactivate

