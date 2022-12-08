#!/usr/bin/env bash

set -ex

dir_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "${dir_path}/common.sh"


echo "${GITHUB_WORKSPACE}"

mkdir -p ${GITHUB_WORKSPACE}/manifests/akeyless-secrets-injection
cp ${GITHUB_WORKSPACE}/manifest_work_dir/akeyless-secrets-injection/manifests/* ${GITHUB_WORKSPACE}/manifests/akeyless-secrets-injection/
cp ${GITHUB_WORKSPACE}/manifest_work_dir/akeyless-secrets-injection/README.md ${GITHUB_WORKSPACE}/manifests/akeyless-secrets-injection/

message="update generated manifests"
path="${GITHUB_WORKSPACE}/manifests/akeyless-secrets-injection/*"

commit_and_push_to_git "${message}" "${path}"


#git config --local user.name "$GITHUB_ACTOR"
#git config --local user.email "$GITHUB_ACTOR@users.noreply.github.com"
#git add ${GITHUB_WORKSPACE}/manifests/akeyless-secrets-injection/*
#git commit -m "update generated manifests"
#git push origin HEAD
