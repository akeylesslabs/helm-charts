#!/usr/bin/env bash

set -e

dir_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "${dir_path}/common.sh"

service=$(echo "$GITHUB_CONTEXT" | jq -r '.payload.service | select (.!=null)')
major_minor_patch=$(echo "$GITHUB_CONTEXT" | jq -r '.payload.major_minor_patch | select (.!=null)')
app_version=$(echo "$GITHUB_CONTEXT" | jq -r '.payload.app_version | select (.!=null)')

if [[ "${service}" == "gateway" ]]; then
    chart_dir="akeyless-api-gateway"
elif [[ "${service}" == "ssh-proxy" ]]; then
    chart_dir="akeyless-secure-remote-access"
elif [[ "${service}" == "zero-trust-bastion" ]]; then
    chart_dir="akeyless-secure-remote-access"
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
    if [[ "${chart_dir}" == "akeyless-secure-remote-access" ]]; then
      # edit app service version
      if [[ "${service}" == "ssh-proxy" ]]; then
          sra_inner_chart="sshVersion"
      elif [[ "${service}" == "zero-trust-bastion" ]]; then
          sra_inner_chart="ztbVersion"
      else
          die "Bad SRA service name"
      fi

      sed -i "s/${sra_inner_chart}.*/${sra_inner_chart}: ${app_version}/g" Chart.yaml
      # edit sra app version
      ztb_app_ver=$(grep 'ztbVersion' Chart.yaml | awk '{print $2}')
      ssh_app_ver=$(grep 'sshVersion' Chart.yaml | awk '{print $2}')
      sed -i "s/appVersion.*/appVersion: ${ztb_app_ver}_${ssh_app_ver}/g" Chart.yaml

    else
        sed -i "s/appVersion.*/appVersion: ${app_version}/g" Chart.yaml
    fi

    git add -A && git commit -m "Updated ${service} helm chart version to latest: ${app_version}" || die "Failed to commit changes to git"
    git push origin HEAD

    echo "$chart_dir app version was successfully updated to latest: ${app_version}"
    echo "$chart_dir Helm chart version was updated to: ${new_chart_version}"
popd



