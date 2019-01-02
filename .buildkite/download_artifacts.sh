#!/usr/bin/env bash
set -e
set -x
S3_BUCKET="s3://batfish-build-artifacts-arifogel"
export BATFISH_TAR="artifacts/batfish/dev.tar"
export PYBATFISH_TAR="artifacts/pybatfish/dev.tar"
BATFISH_DIR="$(dirname "${BATFISH_TAR}")"
PYBATFISH_DIR="$(dirname "${PYBATFISH_TAR}")"
mkdir -p "${BATFISH_DIR}"
mkdir -p "${PYBATFISH_DIR}"
buildkite-agent artifact download "${S3_BUCKET}/${BATFISH_TAR}" "${BATFISH_DIR}/"
buildkite-agent artifact download "${S3_BUCKET}/${PYBATFISH_TAR}" "${PYBATFISH_DIR}/"
pushd "${BATFISH_DIR}"
tar -xf dev.tar
[ -n "$(cat tag)" ]
popd
pushd "${PYBATFISH_DIR}"
tar -xf dev.tar
[ -n "$(cat tag)" ]
popd

