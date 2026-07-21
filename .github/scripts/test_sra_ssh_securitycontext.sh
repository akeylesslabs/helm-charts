#!/usr/bin/env bash
#
# Render-assert test for the legacy SRA SSH bastion securityContext (ASM-18714).
# The zero-trust-bastion image (>= 3.1.0) defaults to a non-root user, so the SSH bastion
# StatefulSet must pin itself back to root with a narrow capability set. This guards that
# contract at render time — `ct install` can't cover it (the SRA CI fixture disables SSH).
#
# Run locally:  bash .github/scripts/test_sra_ssh_securitycontext.sh

set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." >/dev/null 2>&1 && pwd)"
chart="${repo_root}/charts/akeyless-secure-remote-access"
values="${repo_root}/.github/chart-tests/sra-ssh-values.yaml"

rendered="$(helm template t "${chart}" -f "${values}" --show-only templates/statefulSet.yaml 2>&1)"
if [[ $? -ne 0 || -z "${rendered}" ]]; then
  echo "FAIL - could not render SSH StatefulSet:"
  echo "${rendered}"
  exit 1
fi

fail=0
assert_present() {
  local desc="$1" pattern="$2"
  if grep -qE -- "${pattern}" <<<"${rendered}"; then
    echo "ok   - ${desc}"
  else
    echo "FAIL - ${desc} (missing: ${pattern})"
    fail=1
  fi
}
assert_absent() {
  local desc="$1" pattern="$2"
  if grep -qE -- "${pattern}" <<<"${rendered}"; then
    echo "FAIL - ${desc} (unexpected: ${pattern})"
    fail=1
  else
    echo "ok   - ${desc}"
  fi
}

# Pod runs as root (the fix)
assert_present "pod securityContext runAsUser: 0"  "runAsUser: 0"
assert_present "pod securityContext runAsGroup: 0" "runAsGroup: 0"

# Container Phase-A hardened context
assert_present "allowPrivilegeEscalation: true"    "allowPrivilegeEscalation: true"
assert_present "AppArmor Unconfined"               "type: Unconfined"
assert_present "capabilities drop ALL"             "^[[:space:]]+- ALL"
assert_present "cap DAC_OVERRIDE (root file writes)" "- DAC_OVERRIDE"
assert_present "cap SYS_ADMIN (mount --bind)"      "- SYS_ADMIN"

# The old broken config must be gone / not regress
assert_absent "no privileged: true"               "privileged:"

# ssh-proxy must bind an UNPRIVILEGED port: we drop ALL caps and never add NET_BIND_SERVICE,
# so binding 22 would fail. Proxy moved to 2200 via SSH_PROXY_PORT (helm-charts#389).
assert_present "ssh-proxy containerPort 2200"      "containerPort: 2200"
assert_present "SSH_PROXY_PORT env set"            "name: SSH_PROXY_PORT"
assert_present "SSH_PROXY_PORT value 2200"         'value: "2200"'
assert_absent  "no CAP_NET_BIND_SERVICE granted"   "NET_BIND_SERVICE"
assert_absent  "proxy not on privileged port 22"   "containerPort: 22[[:space:]]*$"

if [[ "${fail}" -eq 0 ]]; then
  echo "All SRA SSH securityContext assertions passed"
else
  echo "SRA SSH securityContext assertions FAILED"
  exit 1
fi
