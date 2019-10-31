#!/usr/bin/env bash
# Publish Pybf to PyPI if `pybf` is listed in the artifacts-to-release and the release-tag is set to `latest`

set -euo pipefail

ARTIFACTS_TO_RELEASE=$(buildkite-agent meta-data get artifacts-to-release)
RELEASE_TAG=$(buildkite-agent meta-data get release-tag)

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

    if [ "$RELEASE_TAG" == "test" ]; then
        echo "Not releasing to prod, skip uploading to PyPI"
    elif [ "$RELEASE_TAG" == "latest" ]; then
        echo "Push release branch"
        # Checkout Pybf
        PYBF_DIR=$(mktemp -d)
        git clone --depth=1 --branch=${BATFISH_GITHUB_PYBATFISH_REF} ${BATFISH_GITHUB_PYBATFISH_REPO} ${PYBF_DIR}
        pushd "${PYBF_DIR}"
        # Make sure we use the same commit we built the wheel from to create release branch from
        git checkout ${PYBF_COMMIT}

        BRANCH_NAME="release-${BATFISH_VERSION_STRING}"
        git checkout origin/master -b $BRANCH_NAME
        # Sane in-place version replace: https://stackoverflow.com/a/22084103
        sed -i.bak -e "s/^__version__ = .*$/__version__ = \"${BATFISH_VERSION_STRING}\"/" pybatfish/__init__.py
        rm -f pybatfish/__init__.py.bak
        git config user.name "open-source-buildkitebot"
        git config user.email "open-source-buildkitebot@intentionet.com"
        git commit -am "Prepare for release ${BATFISH_VERSION_STRING}: Updating version number"
        git push --set-upstream origin $BRANCH_NAME
        popd

        echo "Uploading Pybf to PyPI"
        export TWINE_PASSWORD=${PYBF_PYPI_TOKEN}
        twine upload artifacts/pybatfish-${PYBF_VERSION}-py2.py3-none-any.whl
        deactivate

        # Install from PyPI
        python3 -m virtualenv testpypi
        . testpypi/bin/activate

        # Max retries before giving up on installing from PyPI
        # Need retries because sometimes it takes a little while for newly uploaded package to propagate
        MAX_RETRIES=2
        COUNTER=0
        while ! pip install pybatfish==${BATFISH_VERSION_STRING}
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
    else
        echo "Unrecognized release tag (expected test|latest)"
        exit 1
    fi
else
    echo "Skipping publishing Pybf"
fi
