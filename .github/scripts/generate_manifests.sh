#!/usr/bin/env bash

set -e

dir_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "${dir_path}/common.sh"


echo "${GITHUB_WORKSPACE}"

mkdir -p ${GITHUB_WORKSPACE}/manifests/akeyless-secrets-injection
cp ${GITHUB_WORKSPACE}/manifest_work_dir/akeyless-secrets-injection/manifests/* ${GITHUB_WORKSPACE}/manifests/akeyless-secrets-injection/
cp ${GITHUB_WORKSPACE}/manifest_work_dir/akeyless-secrets-injection/README.md ${GITHUB_WORKSPACE}/manifests/akeyless-secrets-injection/

branch_name="generate-manifest--${GITHUB_SHA:0:8}"
echo "branch_name=$branch_name" >> $GITHUB_ENV

