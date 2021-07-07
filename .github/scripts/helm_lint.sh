#!/usr/bin/env bash

set -e

dir_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "${dir_path}/common.sh"

changed_charts=($(lookup_changed_charts | awk '{print $1}'))

if [[ -n "${changed_charts[*]}" ]]; then
    for chart in "${changed_charts[@]}"; do
        if [[ -d "$chart" ]]; then
        helm lint "$chart"
        else
        echo "Chart '$chart' no longer exists in repo. Skipping it..."
        fi
    done
else
    echo "Nothing to do. No chart changes detected."
fi