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

function commit_and_push_to_git() {
  message="$1"
  path_to_file=$2

  git config user.name "$GITHUB_ACTOR"
  git config user.email "$GITHUB_ACTOR@users.noreply.github.com"

  (git add ${path_to_file} && git commit -m "${message}" ${path_to_file}) || die "Failed to commit changes to git"
  git push origin HEAD
}

function die() {
  echo -e $*
  exit 1
}

# Extract a field (e.g., name, version) from Chart.yaml using yq if available, otherwise use awk as a fallback
# Supports both root-level fields and annotation fields
extract_chart_field() {
  local chart_dir="$1"
  local field="$2"
  local result=""
  
  if command -v yq >/dev/null 2>&1; then
    # Try root level first, then annotations
    result=$(yq e ".$field // .annotations.$field" "$chart_dir/Chart.yaml" 2>/dev/null)
  else
    # Use awk to target only the first field line at root level (not indented)
    result=$(awk -v f="$field" '
      # Track if we are in annotations section
      /^annotations:/ { in_annotations = 1; next }
      /^[^ ]/ && !/^annotations:/ { in_annotations = 0 }
      
      # Match root level field (not indented, not in annotations)
      /^[^ ]/ && $1 == f":" && !in_annotations { 
        print $2; 
        exit 
      }
      
      # Match annotation field (indented, in annotations section)
      in_annotations && /^[[:space:]]+[^[:space:]]/ && $1 == f":" { 
        print $2; 
        exit 
      }
    ' "$chart_dir/Chart.yaml")
  fi
  
  # Check if field was found
  if [[ -z "$result" ]] || [[ "$result" == "null" ]]; then
    die "Field '$field' not found in $chart_dir/Chart.yaml"
  fi
  
  echo "$result"
}

# Update a field in Chart.yaml using yq if available, otherwise use awk as a fallback
# Supports both root-level fields and annotation fields
update_chart_field() {
  local chart_dir="$1"
  local field="$2"
  local new_value="$3"
  local field_found=false
  
  if command -v yq >/dev/null 2>&1; then
    # Use yq for YAML-aware operations
    # Check if field exists first
    local field_exists=$(yq e ".$field // .annotations.$field" "$chart_dir/Chart.yaml" 2>/dev/null)
    if [[ -n "$field_exists" ]] && [[ "$field_exists" != "null" ]]; then
      # Try to update root level first, then annotations if needed
      if yq e ".$field = \"$new_value\"" "$chart_dir/Chart.yaml" > "$chart_dir/Chart.yaml.tmp" 2>/dev/null; then
        mv "$chart_dir/Chart.yaml.tmp" "$chart_dir/Chart.yaml"
        field_found=true
      elif yq e ".annotations.$field = \"$new_value\"" "$chart_dir/Chart.yaml" > "$chart_dir/Chart.yaml.tmp" 2>/dev/null; then
        mv "$chart_dir/Chart.yaml.tmp" "$chart_dir/Chart.yaml"
        field_found=true
      fi
    fi
  else
    # Fallback to awk for environments without yq
    awk -v field="$field" -v new_val="$new_value" '
      # Track if we are in annotations section
      /^annotations:/ { in_annotations = 1; next }
      /^[^ ]/ && !/^annotations:/ { in_annotations = 0 }
      
      # Match root level field (not indented, not in annotations)
      /^[^ ]/ && $1 == field":" && !in_annotations { 
        print field ": " new_val; 
        field_found = 1;
        next 
      }
      
      # Match annotation field (indented, in annotations section)
      in_annotations && /^[[:space:]]+[^[:space:]]/ && $1 == field":" { 
        print "  " field ": " new_val; 
        field_found = 1;
        next 
      }
      
      { 
        print 
      }
      
      END {
        exit !field_found
      }
    ' "$chart_dir/Chart.yaml" > "$chart_dir/Chart.yaml.tmp"
    
    if [[ $? -eq 0 ]]; then
      mv "$chart_dir/Chart.yaml.tmp" "$chart_dir/Chart.yaml"
      field_found=true
    else
      rm -f "$chart_dir/Chart.yaml.tmp"
    fi
  fi
  
  # Check if field was found and updated
  if [[ "$field_found" != "true" ]]; then
    die "Field '$field' not found or could not be updated in $chart_dir/Chart.yaml"
  fi
}