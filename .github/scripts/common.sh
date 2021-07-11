#!/usr/bin/env bash

set -e

lookup_latest_tag() {
    git fetch --tags > /dev/null 2>&1

    if ! git describe --tags --abbrev=0 2> /dev/null; then
        git rev-list --max-parents=0 --first-parent HEAD
    fi
}

function die() {
  echo $*
  exit 1
}

function bump_version() {
  current_version=$1
  bump_target=$2

  major_version=$(echo "${current_version}" | cut -d'.' -f 1)
  minor_version=$(echo "${current_version}" | cut -d'.' -f 2)
  patch_version=$(echo "${current_version}" | cut -d'.' -f 3)

  # Validate each version is an actual number
  re='^[0-9]+$'
  if ! [[ $major_version =~ $re ]] ; then
   die "error: major version target $major_version is not a number!" >&2
  fi
  if ! [[ $minor_version =~ $re ]] ; then
   die "error: minor version target $minor_version is not a number!" >&2
  fi
  if ! [[ $patch_version =~ $re ]] ; then
   die "error: patch version target $patch_version is not a number!" >&2
  fi

  if [[ "${bump_target}" == "major" ]]; then
    major_version=$((major_version+1))
    minor_version=0
    patch_version=0
  elif [[ "${bump_target}" == "minor" ]]; then
    minor_version=$((minor_version+1))
    patch_version=0
  elif [[ "${bump_target}" == "patch" ]]; then
    patch_version=$((patch_version+1))

  else
    die "Bad parameter - ${bump_target}"
  fi

  new_version="${major_version}.${minor_version}.${patch_version}"
}

lookup_changed_charts() {
  commit=$(lookup_latest_tag)
  changed_files=$(git diff --find-renames --name-only "$commit" -- charts)

  local depth=$(( $(tr "/" "\n" <<< charts | wc -l) + 1 ))
  local fields="1-${depth}"

  cut -d '/' -f "$fields" <<< "$changed_files" | uniq
}