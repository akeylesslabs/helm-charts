#!/usr/bin/env bash
#
# Unit tests for select_charts_for_service (ASM-18714 legacy SRA release gate).
# Verifies that the legacy standalone SRA chart (akeyless-secure-remote-access) is only
# auto-released when RELEASE_LEGACY_SRA == "true", and that all other services are unaffected.
#
# Run locally:  bash .github/scripts/test_select_charts.sh

dir_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=common.sh
source "${dir_path}/common.sh"
set +e  # common.sh enables `set -e`; the runner drives control flow itself

fail=0

assert_charts() {
  local desc="$1" service="$2" flag="$3" expected="$4"
  selected_charts=()
  select_charts_for_service "${service}" "${flag}"
  local got="${selected_charts[*]}"
  if [[ "${got}" == "${expected}" ]]; then
    echo "ok   - ${desc}"
  else
    echo "FAIL - ${desc}: expected [${expected}] got [${got}]"
    fail=1
  fi
}

# --- the gate: legacy SRA chart is opt-in ---
assert_charts "zero-trust-bastion + flag off skips legacy SRA" \
  zero-trust-bastion false "akeyless-gateway"
assert_charts "zero-trust-bastion + flag on includes legacy SRA" \
  zero-trust-bastion true "akeyless-gateway akeyless-secure-remote-access"
assert_charts "zt-portal + flag off yields no charts" \
  zt-portal false ""
assert_charts "zt-portal + flag on includes legacy SRA" \
  zt-portal true "akeyless-secure-remote-access"

# --- unrelated services must be unaffected by the gate ---
assert_charts "gateway service unaffected (flag off)" \
  gateway false "akeyless-api-gateway akeyless-gateway"
assert_charts "zero-trust-web-access service unaffected" \
  zero-trust-web-access false "akeyless-zero-trust-web-access"
assert_charts "k8s-webhook service unaffected" \
  k8s-webhook false "akeyless-k8s-secrets-injection"

# --- bad service still fails fast ---
if ( select_charts_for_service "nonsense" false ) >/dev/null 2>&1; then
  echo "FAIL - bad service name should exit non-zero"
  fail=1
else
  echo "ok   - bad service name exits non-zero"
fi

if [[ "${fail}" -eq 0 ]]; then
  echo "All select_charts_for_service tests passed"
else
  echo "select_charts_for_service tests FAILED"
  exit 1
fi
