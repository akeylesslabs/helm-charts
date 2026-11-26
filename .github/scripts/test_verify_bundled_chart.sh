#!/usr/bin/env bash
#
# Unit tests for verify_bundled_chart.sh with stand in helm and cosign, so no registry is needed.
# Run:  bash .github/scripts/test_verify_bundled_chart.sh

dir_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
script="${dir_path}/verify_bundled_chart.sh"
fail=0
work="$(mktemp -d)"
trap 'rm -r -- "${work:?}"' EXIT

readonly GOOD=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
readonly OTHER=sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb

mkdir -p "${work}/bin" "${work}/chart"
cat > "${work}/bin/helm" <<STUB
#!/usr/bin/env bash
echo "Pulled: ghcr.io/akeylesslabs/modern-pam/charts/sra:\${STUB_PULLED_VERSION:-0.9.1}" >&2
echo "Digest: \${STUB_DIGEST}" >&2
STUB
cat > "${work}/bin/cosign" <<'STUB'
#!/usr/bin/env bash
[[ "${STUB_COSIGN:-ok}" == "ok" ]]
STUB
chmod +x "${work}/bin/helm" "${work}/bin/cosign"

write_chart() {
	local annotation_digest="$1" dependency_version="$2"
	cat > "${work}/chart/Chart.yaml" <<YAML
apiVersion: v2
name: akeyless-gateway
annotations:
  gatewayVersion: 5.8.0
  modernPamVersion: 0.9.1
  modernPamChartDigest: ${annotation_digest}
dependencies:
  - name: redis-ha
    version: 4.35.10
  - name: sra
    version: ${dependency_version}
    repository: oci://ghcr.io/akeylesslabs/modern-pam/charts
YAML
}

run() {
	local desc="$1" want="$2"
	shift 2
	if env PATH="${work}/bin:${PATH}" "$@" bash "${script}" "${work}/chart" > "${work}/out" 2>&1; then got=pass; else got=refuse; fi
	if [[ "${got}" == "${want}" ]]; then echo "ok   - ${desc}"; else echo "FAIL - ${desc}: wanted ${want}, got ${got}"; sed 's/^/       /' "${work}/out"; fail=1; fi
}

write_chart "${GOOD}" 0.9.1
run "the pinned digest with a good signature passes" pass STUB_DIGEST="${GOOD}"
run "a registry digest that differs from the annotation is refused" refuse STUB_DIGEST="${OTHER}"
run "a signature that does not verify is refused" refuse STUB_DIGEST="${GOOD}" STUB_COSIGN=fail

write_chart "${GOOD}" 0.9.0
run "a dependency version that differs from the annotation is refused" refuse STUB_DIGEST="${GOOD}"

write_chart "sha256:short" 0.9.1
run "an annotation that is not a digest is refused" refuse STUB_DIGEST="${GOOD}"

write_chart "" 0.9.1
run "a missing digest annotation is refused" refuse STUB_DIGEST="${GOOD}"

exit "${fail}"
