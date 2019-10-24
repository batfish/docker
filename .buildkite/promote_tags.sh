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

      echo "RETAG AND PUSH PLACEHOLDER"
      # SKIP tag and push for now
      # Re-tag & push with sha tag
      #docker tag  "batfish/${image}:${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER}" \
      #            "batfish/${image}:${SHA_TAG}"
      #docker push "batfish/${image}:${SHA_TAG}"
      # Re-tag & push with updated tag + build number
      #docker tag  "batfish/${image}:${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER}" \
      #            "batfish/${image}:${UPDATE_TO_TAG}-${BUILDKITE_BUILD_NUMBER}"
      #docker push "batfish/${image}:${UPDATE_TO_TAG}-${BUILDKITE_BUILD_NUMBER}"
      # Re-tag & push with just updated tag
      #docker tag  "batfish/${image}:${TESTING_TAG}-${BUILDKITE_BUILD_NUMBER}" \
      #            "batfish/${image}:${UPDATE_TO_TAG}"
      #docker push "batfish/${image}:${UPDATE_TO_TAG}"

      # TODO tag with BATFISH_VERSION_STRING
    done
  else
    echo "Skipping publishing Bf"
fi
