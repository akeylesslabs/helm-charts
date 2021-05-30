#!/usr/bin/env bash

set -e

dir_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "${dir_path}/common.sh"

service=$(echo "$GITHUB_CONTEXT" | jq -r '.payload.service | select (.!=null)')
major_minor_patch=$(echo "$GITHUB_CONTEXT" | jq -r '.payload.major_minor_patch | select (.!=null)')
app_version=$(echo "$GITHUB_CONTEXT" | jq -r '.payload.app_version | select (.!=null)')

if [[ "${service}" == "akeyless-api-proxy" ]]; then
    chart_dir="akeyless-api-gateway"
elif [[ "${service}" == "ssh-proxy" ]]; then
    chart_dir="akeyless-ssh-bastion"
elif [[ "${service}" == "zero-trust-web-access" ]]; then
    chart_dir="akeyless-zero-trust-web-access"
else
die "Bad service name"
fi

pushd "$GITHUB_WORKSPACE/charts/$chart_dir"
# bump chart version
    chart_version=$(grep '^version:[[:space:]][[:digit:]]' Chart.yaml | awk '{print $2}') || die "Failed to retrieve current chart version"
    bump_version "${chart_version}" "${major_minor_patch}"
    new_chart_version=$new_version && echo "The new Chart version is: ${new_chart_version}"
    sed -i "s/version:.*/version: ${new_chart_version}/g" Chart.yaml

# edit app version
    sed -i "s/appVersion.*/appVersion: ${app_version}/g" Chart.yaml

    git add -A && git commit -m "Updated helm chart to latest api-gw version ${app_version}" || die "Failed to commit changes to git"
    git push origin HEAD
popd

echo "$chart_dir app version was successfully updated to latest: ${app_version}"
echo "$chart_dir Helm chart version was updated to: ${new_chart_version}"


