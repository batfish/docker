#!/usr/bin/env bash
# Accepts one optional argument:
#  1. latest|test, determines if the Pybf wheel is uploaded to PyPI or test-PyPI, respectively. If not provided the PyPI target is pulled from release-tag meta-data value.

set -euo pipefail

ARTIFACTS_TO_RELEASE=$(buildkite-agent meta-data get artifacts-to-release)
# If supplied, use first argument to script as PyPI target, otherwise pull target from release-tag meta-data
PYPI_TARGET=${1:-$(buildkite-agent meta-data get release-tag)}

PYBF_COMMIT=$(cat artifacts/pybatfish-tag.txt)
PYBF_VERSION=$(cat artifacts/pybatfish-version.txt)

# Check if Pybf is one of the artifacts we want to release
# Note: artifact names are newline delimited
if echo "$ARTIFACTS_TO_RELEASE" | grep --quiet ^pybf$; then
    echo "Publishing Pybf"

    python3 -m virtualenv .venv
    . .venv/bin/activate
    pip install twine
    export TWINE_USERNAME="__token__"

    if [ "$PYPI_TARGET" == "test" ]; then
        echo "Uploading Pybf to test-PyPI"
        export TWINE_PASSWORD=${PYBF_TEST_PYPI_TOKEN}
        twine upload --repository-url https://test.pypi.org/legacy/ artifacts/pybatfish-${PYBF_VERSION}-py2.py3-none-any.whl
        deactivate

        # Install from test PyPI
        python3 -m virtualenv testpypi
        . testpypi/bin/activate
        pip install -i https://test.pypi.org/simple --extra-index-url https://pypi.org/simple pybatfish
    elif [ "$PYPI_TARGET" == "latest" ]; then
        echo "Push release branch"
        # Checkout Pybf
        PYBF_DIR=$(mktemp -d)
        git clone ${BATFISH_GITHUB_PYBATFISH_REPO} ${PYBF_DIR}
        pushd "${PYBF_DIR}"
        # Make sure we use the same commit we built the wheel from to create release branch from
        git checkout ${PYBF_COMMIT}

        BRANCH_NAME="release-${BATFISH_VERSION_STRING}"
        git checkout origin/master -b $BRANCH_NAME
        # Sane in-place version replace: https://stackoverflow.com/a/22084103
        sed -i.bak -e "s/^__version__ = .*$/__version__ = \"${BATFISH_VERSION_STRING}\"/" pybatfish/__init__.py
        rm -f pybatfish/__init__.py.bak
        git config user.name "buildkitebot"
        git config user.email "buildkitebot@intentionet.com"
        git commit -am "Prepare for release ${BATFISH_VERSION_STRING}: Updating version number"
        echo "PUSH PLACEHOLDER"
        # SKIP push for now
        # git push --set-upstream origin $BRANCH_NAME
        popd

        echo "Uploading Pybf to PyPI"
        echo "UPLOAD PLACEHOLDER"
        # SKIP upload for now
        # export TWINE_PASSWORD=${PYBF_PYPI_TOKEN}
        # twine upload artifacts/pybatfish-${PYBF_VERSION}-py2.py3-none-any.whl
        deactivate

        # re-install from test PyPi and re-test, in a new venv
        python3 -m virtualenv testpypi
        . testpypi/bin/activate
        pip install pybatfish
    else
        echo "Must specify what PyPI target to upload to (test|latest)"
        exit 1
    fi

    # If we can successfully import something after installing from PyPI,
    # then assume the upload was successful
    python -c "from pybatfish.client.session import Session"
    echo "Pybf import was successful!"
    deactivate
else
    echo "Skipping publishing Pybf"
fi
