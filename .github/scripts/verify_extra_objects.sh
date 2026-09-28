#!/usr/bin/env bash
set -euo pipefail

namespace="${NAMESPACE:-chart-testing}"
label="extra-objects-probe=true"
kinds="configmaps,secretproviderclasses.secrets-store.csi.x-k8s.io"

fail() {
  echo "::error::$*"
  exit 1
}

verify_installed() {
  local expected=0 found=0 chart release kind owner value

  while IFS= read -r chart; do
    [[ -n "$chart" ]] || continue
    if grep -qs '^extraObjects:' "$chart"/ci/*.yaml; then
      expected=$((expected + 1))
    fi
  done <<< "${CHANGED_CHARTS:-}"

  for release in $(helm list -n "$namespace" --short); do
    helm get manifest "$release" -n "$namespace" | grep -q "extra-objects-probe" || continue
    for kind in configmap secretproviderclass.secrets-store.csi.x-k8s.io; do
      owner="$(kubectl get "$kind" "${release}-extra" -n "$namespace" \
        -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}')"
      [[ "$owner" == "$release" ]] || fail "$kind ${release}-extra is not owned by release $release (got '$owner')"
    done
    value="$(kubectl get configmap "${release}-extra" -n "$namespace" -o jsonpath='{.data.release}')"
    [[ "$value" == "$release" ]] || fail "configmap ${release}-extra did not render tpl (got '$value')"
    echo "release $release: extraObjects installed and owned"
    found=$((found + 1))
  done

  [[ "$found" -ge "$expected" ]] || fail "expected extraObjects from $expected chart(s), verified $found"
  echo "verified extraObjects for $found release(s)"
}

verify_removed() {
  local left
  left="$(kubectl get "$kinds" -n "$namespace" -l "$label" -o name)"
  [[ -z "$left" ]] || fail "extraObjects left after helm uninstall: $left"
  echo "extraObjects removed with their releases"
}

case "${1:-}" in
  installed) verify_installed ;;
  removed) verify_removed ;;
  *) fail "usage: $0 installed|removed" ;;
esac
