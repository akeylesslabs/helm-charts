#!/usr/bin/env bash
#
# Refuse to release the akeyless-gateway chart unless the bundled Modern PAM chart is the one
# Chart.yaml names: pulled by its version, carrying the digest in the modernPamChartDigest
# annotation, and signed by the Modern PAM release workflow.
#
# Usage:  verify_bundled_chart.sh <path to the gateway chart directory>
# Needs:  helm and cosign on PATH, a registry login for both that can read the package.
set -euo pipefail

readonly CHART_DIR="${1:?usage: verify_bundled_chart.sh <gateway chart directory>}"
readonly CHART_FILE="${CHART_DIR}/Chart.yaml"
readonly REPOSITORY='oci://ghcr.io/akeylesslabs/modern-pam/charts'
readonly CHART_NAME='sra'
readonly OIDC_ISSUER='https://token.actions.githubusercontent.com'
# The Modern PAM release workflow on a release tag. Update the tag pattern with the re-pin that changes it.
readonly IDENTITY_REGEXP='^https://github\.com/akeylesslabs/modern-pam/\.github/workflows/release\.yml@refs/tags/sra/v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'

annotation() {
	sed -n "s/^  $1: *//p" "${CHART_FILE}" | head -1 | tr -d '"'
}

dependency_version() {
	awk -v name="${CHART_NAME}" '
		/^  - name: / { current = $3 }
		current == name && /^    version: / { print $2; exit }
	' "${CHART_FILE}" | tr -d '"'
}

version="$(annotation modernPamVersion)"
expected_digest="$(annotation modernPamChartDigest)"
pinned="$(dependency_version)"

[[ -n "${version}" ]] || { echo "verify_bundled_chart: no modernPamVersion annotation in ${CHART_FILE}" >&2; exit 1; }
[[ "${expected_digest}" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo "verify_bundled_chart: the modernPamChartDigest annotation in ${CHART_FILE} is not a sha256 digest" >&2; exit 1; }
[[ "${pinned}" == "${version}" ]] || { echo "verify_bundled_chart: the ${CHART_NAME} dependency is ${pinned} but modernPamVersion says ${version}" >&2; exit 1; }

workdir="$(mktemp -d)"
trap 'rm -r -- "${workdir:?}"' EXIT

# helm pull prints the pulled reference and its digest on standard error.
pulled="$(helm pull "${REPOSITORY}/${CHART_NAME}" --version "${version}" --destination "${workdir}" 2>&1)"
got_digest="$(printf '%s\n' "${pulled}" | sed -n 's/^Digest: *//p' | head -1)"

if [[ "${got_digest}" != "${expected_digest}" ]]; then
	echo "verify_bundled_chart: ${CHART_NAME} ${version} has digest '${got_digest}' but Chart.yaml expects ${expected_digest}" >&2
	exit 1
fi

cosign verify \
	--certificate-oidc-issuer "${OIDC_ISSUER}" \
	--certificate-identity-regexp "${IDENTITY_REGEXP}" \
	"ghcr.io/akeylesslabs/modern-pam/charts/${CHART_NAME}@${got_digest}" > /dev/null

echo "verify_bundled_chart: ${CHART_NAME} ${version} at ${got_digest} is the pinned chart and its signature verifies"
