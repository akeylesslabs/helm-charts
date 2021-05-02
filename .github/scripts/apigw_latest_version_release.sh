#!/usr/bin/env bash

set -x 

service=$(echo "$GITHUB_CONTEXT" | jq -r '.payload.service | select (.!=null)')
publish_as_latest=$(echo "$GITHUB_CONTEXT" | jq -r '.payload.publish_as_latest | select (.!=null)')
major_minor_patch=$(echo "$GITHUB_CONTEXT" | jq -r '.payload.major_minor_patch | select (.!=null)')

echo "test"
echo $service
echo $major_minor_patch
echo $publish_as_latest




# set -e

# function die() {
#   echo $*
#   exit 1
# }

# dir_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# source "${dir_path}/common.sh"

# lookup_changed_charts() {
#   commit=$(lookup_latest_tag)
#   changed_files=$(git diff --find-renames --name-only "$commit" -- charts)

#   local depth=$(( $(tr "/" "\n" <<< charts | wc -l) + 1 ))
#   local fields="1-${depth}"

#   cut -d '/' -f "$fields" <<< "$changed_files" | uniq
# }

# main() {
#   local repo_root
#   repo_root=$(git rev-parse --show-toplevel)
#   pushd "$repo_root" > /dev/null

#   local changed_charts=($(lookup_changed_charts | awk '{print $1}'))

#   if [[ -n "${changed_charts[*]}" ]]; then
#       for chart in "${changed_charts[@]}"; do
#           if [[ -d "$chart" ]]; then
#             chart_name=$(helm show chart "$chart" | grep name: | awk '{print $2}')
#             chart_version=$(helm show chart "$chart" | grep version: | awk '{print $2}')
#             git tag "$chart_name-$chart_version" || die "Chart version already exists, please bump the version"
#           else
#             echo "Chart '$chart' no longer exists in repo. Skipping it..."
#           fi
#       done
#   else
#       echo "Nothing to do. No chart changes detected."
#   fi

#   popd > /dev/null
# }

# main "$@"


