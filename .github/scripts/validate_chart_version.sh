#!/usr/bin/env bash

set -e

function die() {
  echo $*
  exit 1
}

dir_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "${dir_path}/common.sh"

lookup_changed_charts() {
  commit=$(lookup_latest_tag)
  changed_files=$(git diff --find-renames --name-only "$commit" -- charts)

  local depth=$(( $(tr "/" "\n" <<< charts | wc -l) + 1 ))
  local fields="1-${depth}"

  cut -d '/' -f "$fields" <<< "$changed_files" | uniq
}

# Function to extract a top-level field from helm show chart output, ignoring dependencies and indented fields
extract_chart_field() {
  local chart_dir="$1"
  local field="$2"
  helm show chart "$chart_dir" | \
    awk -v f="$field" '
      /^[^ ]*:/ { in_deps=($1=="dependencies:") }
      !in_deps && $1 == f":" { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }
    '
}

main() {
  local repo_root
  repo_root=$(git rev-parse --show-toplevel)
  pushd "$repo_root" > /dev/null

  local changed_charts=($(lookup_changed_charts | awk '{print $1}'))
  echo "The following charts have been changed: ${changed_charts[*]}"

  if [[ -n "${changed_charts[*]}" ]]; then
      for chart in "${changed_charts[@]}"; do
          if [[ -d "$chart" ]]; then
            chart_name=$(extract_chart_field "$chart" "name")
            chart_version=$(extract_chart_field "$chart" "version")
            if [[ -z "$chart_name" || -z "$chart_version" ]]; then
              die "Failed to extract chart name or version for $chart"
            fi
            git tag "$chart_name-$chart_version" || die "Chart version already exists, please bump the version"
            echo "${chart} chart version changes validated successfully"
          else
            echo "Chart '$chart' no longer exists in repo. Skipping it..."
          fi
      done
  else
      echo "Nothing to do. No chart changes detected."
  fi

  popd > /dev/null
}

main "$@"
