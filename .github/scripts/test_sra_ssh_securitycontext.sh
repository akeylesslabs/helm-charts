#!/usr/bin/env bash
#
# Render-asserts the SSH bastion securityContext contract (root + narrow capability set,
# required by the non-root zero-trust-bastion image). ct install can't cover this.
# Run:  bash .github/scripts/test_sra_ssh_securitycontext.sh

set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." >/dev/null 2>&1 && pwd)"
chart="${repo_root}/charts/akeyless-secure-remote-access"
values="${chart}/ci/sra-ssh-render-fixture.yaml"

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

# Container hardened context
assert_present "allowPrivilegeEscalation: true"    "allowPrivilegeEscalation: true"
assert_present "AppArmor Unconfined"               "type: Unconfined"

# Exact capability sets, any unexpected add or drop entry fails the test
extract_caps() {
  local section="$1"
  awk -v section="${section}:" '
    $1 == section { in_section = 1; next }
    in_section && $1 == "-" { print $2; next }
    in_section { exit }
  ' <<<"${rendered}" | sort | paste -sd, -
}
expected_add="AUDIT_WRITE,CHOWN,DAC_OVERRIDE,FOWNER,MKNOD,SETGID,SETUID,SYS_ADMIN,SYS_CHROOT"
actual_add="$(extract_caps add)"
actual_drop="$(extract_caps drop)"
if [[ "${actual_add}" == "${expected_add}" ]]; then
  echo "ok   - capability add set matches exactly"
else
  echo "FAIL - capability add set (expected: ${expected_add}, got: ${actual_add})"
  fail=1
fi
if [[ "${actual_drop}" == "ALL" ]]; then
  echo "ok   - capability drop set is exactly ALL"
else
  echo "FAIL - capability drop set (expected: ALL, got: ${actual_drop})"
  fail=1
fi

# The old broken config must be gone / not regress
assert_absent "no privileged: true"               "privileged:"

# The proxy must bind an unprivileged port, NET_BIND_SERVICE is never granted
assert_present "ssh-proxy containerPort 2200"      "containerPort: 2200"
assert_present "SSH_PROXY_PORT env set"            "name: SSH_PROXY_PORT"
assert_present "SSH_PROXY_PORT value 2200"         'value: "2200"'
assert_absent  "no CAP_NET_BIND_SERVICE granted"   "NET_BIND_SERVICE"
assert_absent  "proxy not on privileged port 22"   "containerPort: 22[[:space:]]*$"

# Invalid proxyPort values must be rejected at render time
for bad_port in 22 1024 2222 9900; do
  if helm template t "${chart}" -f "${values}" --set sshConfig.proxyPort="${bad_port}" >/dev/null 2>&1; then
    echo "FAIL - proxyPort=${bad_port} should fail to render"
    fail=1
  else
    echo "ok   - proxyPort=${bad_port} rejected at render time"
  fi
done

if [[ "${fail}" -eq 0 ]]; then
  echo "All SRA SSH securityContext assertions passed"
else
  echo "SRA SSH securityContext assertions FAILED"
  exit 1
fi
