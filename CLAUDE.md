# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Lint a specific chart
helm lint charts/<chart-name>

# Render templates locally (dry-run)
helm template charts/<chart-name>

# Render with a custom values file
helm template charts/<chart-name> -f my-values.yaml

# Update chart dependencies (required for akeyless-gateway which depends on redis-ha)
helm dependency update charts/akeyless-gateway
```

## Chart Structure

Each chart lives under `charts/` and follows the standard Helm layout (`Chart.yaml`, `values.yaml`, `values.schema.json`, `templates/`).

| Chart | Purpose |
|-------|---------|
| `akeyless-gateway` | Main gateway chart. Includes embedded SRA components (`templates/akeyless-secure-remote-access/`) and an optional redis-ha dependency for HA caching. |
| `akeyless-api-gateway` | Simpler, older gateway chart. Tracks only a single `appVersion`. |
| `akeyless-secure-remote-access` | Standalone SRA chart. Its `appVersion` is a composite `ztbVersion_ztpVersion`. |
| `akeyless-zero-trust-web-access` | ZTWA chart. |
| `akeyless-csi-provider` | CSI secrets provider. |
| `akeyless-k8s-secrets-injection` | Mutating webhook for K8s secret injection. |

## Versioning Rules

Every change to a chart **must** include a `version` bump in `Chart.yaml` (semver). The CI `validate_chart_release.yaml` workflow enforces this by checking that no existing git tag matches the current `chart-name-version` combination.

**`akeyless-gateway` version fields:**
- `version` — chart version (bumped on every change)
- `appVersion` — derived composite: `gatewayVersion_sraVersion`
- `annotations.gatewayVersion` — tracks gateway image version
- `annotations.sraVersion` — tracks SRA image version

**`akeyless-secure-remote-access` version fields:**
- `appVersion` — derived composite: `ztbVersion_ztpVersion`
- `annotations.ztbVersion` / `annotations.ztpVersion`

The automation scripts (`latest_version_release.sh`, `common.sh`) use `yq` when available, otherwise fall back to `awk` for reading/updating these fields. The `extract_chart_field` and `update_chart_field` functions in `common.sh` support both root-level and annotation-level fields.

## CI/CD Workflows

| Workflow | Trigger | Action |
|----------|---------|--------|
| `validate_chart_release.yaml` | PR / deployment | Runs `helm lint` + validates version was bumped |
| `release.yaml` | Push to `main` | Packages and publishes charts via `helm/chart-releaser-action` |
| `helm_latest_version_release.yaml` | GitHub Deployment event (`task: update-latest-version`) | Bumps chart + app versions, commits, then triggers `akeyless-k8s-manifests` repo update |

The automated release workflow is triggered externally via GitHub Deployments with a JSON payload specifying `service`, `major_minor_patch`, and `app_version`. Service-to-chart mappings:
- `gateway` → `akeyless-api-gateway`, `akeyless-gateway`
- `zero-trust-bastion` → `akeyless-secure-remote-access`, `akeyless-gateway`
- `zt-portal` → `akeyless-secure-remote-access`
- `zero-trust-web-access` → `akeyless-zero-trust-web-access`
- `k8s-webhook` → `akeyless-k8s-secrets-injection`
