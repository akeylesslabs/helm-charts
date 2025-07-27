#!/usr/bin/env bash

set -e

dir_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "${dir_path}/common.sh"



service=$(echo "$GITHUB_CONTEXT" | jq -r '.payload.service | select (.!=null)')
major_minor_patch=$(echo "$GITHUB_CONTEXT" | jq -r '.payload.major_minor_patch | select (.!=null)')
app_version=$(echo "$GITHUB_CONTEXT" | jq -r '.payload.app_version | select (.!=null)')

# Validate required environment variables
if [[ -z "${service}" ]]; then
  die "Required environment variable 'service' is not set"
fi

if [[ -z "${major_minor_patch}" ]]; then
  die "Required environment variable 'major_minor_patch' is not set"
fi

if [[ -z "${app_version}" ]]; then
  die "Required environment variable 'app_version' is not set"
fi

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
  if [[ ! -d "$GITHUB_WORKSPACE/charts/${chart}" ]]; then
    die "Chart directory not found: $GITHUB_WORKSPACE/charts/${chart}"
  fi
  
  if [[ ! -f "$GITHUB_WORKSPACE/charts/${chart}/Chart.yaml" ]]; then
    die "Chart.yaml not found in: $GITHUB_WORKSPACE/charts/${chart}"
  fi
  
  pushd "$GITHUB_WORKSPACE/charts/${chart}"
    # bump chart version
    chart_version=$(extract_chart_field "." "version")
    bump_version "${chart_version}" "${major_minor_patch}"
    if [[ -z "${new_version}" ]]; then
      die "Failed to bump version from ${chart_version} with ${major_minor_patch}"
    fi
    new_chart_version=${new_version} && echo "The new Chart version is: ${new_chart_version}"
    update_chart_field "." "version" "${new_chart_version}"

    # edit app version for akeyless-secure-remote-access
    if [[ "${chart}" == "akeyless-secure-remote-access" ]]; then
      # edit app service version
      if [[ "${service}" == "zero-trust-bastion" ]]; then
        sra_inner_chart="ztbVersion"
      elif [[ "${service}" == "zt-portal" ]]; then
        sra_inner_chart="ztpVersion"
      else
        die "Bad SRA service name"
      fi

      update_chart_field "." "${sra_inner_chart}" "${app_version}"
      # edit sra app version
      ztb_app_ver=$(extract_chart_field "." "ztbVersion")
      ztp_app_ver=$(extract_chart_field "." "ztpVersion")
      new_app_version="${ztb_app_ver}_${ztp_app_ver}"
      update_chart_field "." "appVersion" "${new_app_version}"

    elif [[ "${chart}" == "akeyless-gateway" ]]; then
      # edit app version for akeyless-gateway
      if [[ "${service}" == "zero-trust-bastion" ]]; then
        gateway_inner_chart="sraVersion"
      elif [[ "${service}" == "gateway" ]]; then
        gateway_inner_chart="gatewayVersion"
      else
        die "Bad gateway service name"
      fi
      update_chart_field "." "${gateway_inner_chart}" "${app_version}"
      # edit sra app version
      gateway_app_ver=$(extract_chart_field "." "gatewayVersion")
      sra_app_ver=$(extract_chart_field "." "sraVersion")
      update_chart_field "." "appVersion" "${gateway_app_ver}_${sra_app_ver}"
      new_app_version="${gateway_app_ver}_${sra_app_ver}"
    else
      new_app_version="${app_version}"
      update_chart_field "." "appVersion" "${new_app_version}"
    fi

    git add -A && git commit -m "Updated ${service} helm chart version to latest: ${new_app_version}" || die "Failed to commit changes to git"
    git push origin HEAD

    echo "${chart} app version was successfully updated to latest: ${new_app_version}"
    echo "${chart} Helm chart version was updated to: ${new_chart_version}"
    updated_charts_summary+=("${chart} app version: ${new_app_version} Helm chart version: ${new_chart_version}")
  popd
done

echo "new_chart_version=$new_chart_version" >> "${GITHUB_ENV}"
echo "new_chart_version=$new_chart_version" >> "${GITHUB_OUTPUT}"
echo "charts=${charts[*]}" >> "${GITHUB_ENV}"
echo "charts=${charts[*]}" >> "${GITHUB_OUTPUT}"
echo "updated_charts_summary=${updated_charts_summary[*]}" >> "${GITHUB_ENV}"
echo "updated_charts_summary=${updated_charts_summary[*]}" >> "${GITHUB_OUTPUT}"