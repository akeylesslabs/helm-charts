#!/usr/bin/env bash

set -e

dir_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "${dir_path}/common.sh"

service=$(echo "$GITHUB_CONTEXT" | jq -r '.payload.service | select (.!=null)')
major_minor_patch=$(echo "$GITHUB_CONTEXT" | jq -r '.payload.major_minor_patch | select (.!=null)')
app_version=$(echo "$GITHUB_CONTEXT" | jq -r '.payload.app_version | select (.!=null)')

charts=()
if [[ "${service}" == "gateway" ]]; then
  charts+=("akeyless-api-gateway" "akeyless-gateway")
elif [[ "${service}" == "zero-trust-bastion" ]]; then
  charts+=("akeyless-secure-remote-access" "akeyless-gateway")
elif [[ "${service}" == "zt-portal" ]]; then
 charts+=("akeyless-secure-remote-access")
elif [[ "${service}" == "zero-trust-web-access" ]]; then
  charts+=("akeyless-zero-trust-web-access")
elif [[ "${service}" == "k8s-webhook" ]]; then
  charts+=("akeyless-k8s-secrets-injection")
else
  die "Bad service name"
fi

updated_charts_summary=()
for chart in "${charts[@]}"; do
  pushd "$GITHUB_WORKSPACE/charts/${chart}"
    # bump chart version
    chart_version=$(grep '^version:[[:space:]][[:digit:]]' Chart.yaml | awk '{print $2}') || die "Failed to retrieve current chart version"
    bump_version "${chart_version}" "${major_minor_patch}"
    new_chart_version=${new_version} && echo "The new Chart version is: ${new_chart_version}"
    sed -i "s/version:.*/version: ${new_chart_version}/g" Chart.yaml

    # edit app version for akeyless-secure-remote-access
    if [[ "${{chart}" == "akeyless-secure-remote-access" ]]; then
      # edit app service version
      if [[ "${service}" == "zero-trust-bastion" ]]; then
        sra_inner_chart="ztbVersion"
      elif [[ "${service}" == "zt-portal" ]]; then
        sra_inner_chart="ztpVersion"
      else
        die "Bad SRA service name"
      fi

      sed -i "s/${sra_inner_chart}.*/${sra_inner_chart}: ${app_version}/g" Chart.yaml
      # edit sra app version
      ztb_app_ver=$(grep 'ztbVersion' Chart.yaml | awk '{print $2}')
      ztp_app_ver=$(grep 'ztpVersion' Chart.yaml | awk '{print $2}')
      app_version="${ztb_app_ver}_${ztp_app_ver}"
      sed -i "s/appVersion.*/appVersion: ${app_version}/g" Chart.yaml

    elif [[ "${chart}" == "akeyless-gateway" ]]; then
      # edit app version for akeyless-gateway
      if [[ "${service}" == "zero-trust-bastion" ]]; then
        gateway_inner_chart="sraVersion"
      elif [[ "${service}" == "gateway" ]]; then
        gateway_inner_chart="gatewayVersion"
      else
        die "Bad gateway service name"
      fi
      sed -i "s/${gateway_inner_chart}.*/${gateway_inner_chart}: ${app_version}/g" Chart.yaml
      # edit sra app version
      gateway_app_ver=$(grep 'gatewayVersion' Chart.yaml | awk '{print $2}')
      sra_app_ver=$(grep 'sraVersion' Chart.yaml | awk '{print $2}')
      sed -i "s/appVersion.*/appVersion: ${gateway_app_ver}_${sra_app_ver}/g" Chart.yaml
      app_version="${gateway_app_ver}_${sra_app_ver}"
    else
      sed -i "s/appVersion.*/appVersion: ${app_version}/g" Chart.yaml
    fi

    git add -A && git commit -m "Updated ${service} helm chart version to latest: ${app_version}" || die "Failed to commit changes to git"
    git push origin HEAD

    echo "${chart} app version was successfully updated to latest: ${app_version}"
    echo "${chart} Helm chart version was updated to: ${new_chart_version}"
    updated_charts_summary+=("${chart} app version: ${app_version} Helm chart version: ${new_chart_version}")
  popd
done

echo "new_chart_version=$new_chart_version" >> "${GITHUB_ENV}"
echo "new_chart_version=$new_chart_version" >> "${GITHUB_OUTPUT}"
echo "charts=${charts[*]}" >> "${GITHUB_ENV}"
echo "charts=${charts[*]}" >> "${GITHUB_OUTPUT}"
echo "updated_charts_summary=${updated_charts_summary[*]}" >> "${GITHUB_ENV}"
echo "updated_charts_summary=${updated_charts_summary[*]}" >> "${GITHUB_OUTPUT}"