#!/usr/bin/env bash
set -euxo pipefail

source "$(dirname "${BASH_SOURCE[0]}")"/common_vars.sh
UPDATE_TO_TAG=$(buildkite-agent meta-data get release-tag)
ARTIFACTS_TO_RELEASE=$(buildkite-agent meta-data get artifacts-to-release)

if echo "$ARTIFACTS_TO_RELEASE" | grep --quiet ^bf$; then
    echo "Publishing Bf"
    mkdir ${ARTIFACT_DIR}

    buildkite-agent artifact download ${ARTIFACT_DIR}/batfish-tag.txt ${ARTIFACT_DIR}
    buildkite-agent artifact download ${ARTIFACT_DIR}/pybatfish-tag.txt ${ARTIFACT_DIR}

    BF_TAG=$(cat ${ARTIFACT_DIR}/batfish-tag.txt)
    PYBF_TAG=$(cat ${ARTIFACT_DIR}/pybatfish-tag.txt)

    for image in "batfish" "allinone"; do
        SHA_TAG=${BF_TAG}
        if [ "$image" == "allinone" ]; then
          SHA_TAG=${BF_TAG}_${PYBF_TAG}
        fi
        # Ensure we have the latest container
        docker pull "batfish/${image}:${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER}"

        # Re-tag & push with sha tag
        docker tag  "batfish/${image}:${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER}" \
                    "batfish/${image}:${SHA_TAG}"
        docker push "batfish/${image}:${SHA_TAG}"
        # Re-tag & push with updated tag + build number
        docker tag  "batfish/${image}:${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER}" \
                    "batfish/${image}:${UPDATE_TO_TAG}-${BUILDKITE_BUILD_NUMBER}"
        docker push "batfish/${image}:${UPDATE_TO_TAG}-${BUILDKITE_BUILD_NUMBER}"
        # Re-tag & push with just updated tag
        docker tag  "batfish/${image}:${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER}" \
                    "batfish/${image}:${UPDATE_TO_TAG}"
        docker push "batfish/${image}:${UPDATE_TO_TAG}"

        if [ "${UPDATE_TO_TAG}" == "latest" ]; then
            echo "Publishing VERSION tag for ${image}"
            # For latest containers, re-tag & push with version tag (build number is already in the version number)
            docker tag "batfish/${image}:${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER}" \
                       "batfish/${image}:${BATFISH_VERSION_STRING}"
            docker push "batfish/${image}:${BATFISH_VERSION_STRING}"
        fi
    done
else
    echo "Skipping publishing Bf"
fi
