# AGENTS.md

Repository guidance for coding agents working in this Helm charts repo.

## Commands

```bash
# Lint a specific chart
helm lint charts/<chart-dir>

# Render templates locally
helm template charts/<chart-dir>

# Render with custom values
helm template charts/<chart-dir> -f my-values.yaml

# Update chart dependencies before linting/rendering akeyless-gateway
helm dependency update charts/akeyless-gateway

# Run the same chart-testing lint config used in CI, when ct is installed
ct lint --config .github/ct.yaml
```

Notes:
- `akeyless-gateway` depends on external chart repos; add/update them before dependency updates when needed:
  `helm repo add dandydeveloper https://dandydeveloper.github.io/charts/ && helm repo update`.
- The PR workflow also runs `ct install` in a kind cluster. Local `helm template`/`helm lint` are usually the fastest first validation steps.

## Chart Structure

Charts live under `charts/` and follow the standard Helm layout (`Chart.yaml`, `values.yaml`, `templates/`). Some charts also have `values.schema.json`; do not assume every chart has one.

| Directory | Chart name | Purpose |
| --- | --- | --- |
| `akeyless-gateway` | `akeyless-gateway` | Main gateway chart. Includes embedded SRA components under `templates/akeyless-secure-remote-access/` and an optional `redis-ha` dependency for HA caching. |
| `akeyless-api-gateway` | `akeyless-api-gateway` | Simpler/older gateway chart that tracks a single app image version. |
| `akeyless-secure-remote-access` | `akeyless-sra` | Standalone SRA chart. Its app version is derived from Zero Trust Bastion and Zero Trust Portal versions. |
| `akeyless-zero-trust-web-access` | `akeyless-zero-trust-web-access` | ZTWA chart. |
| `akeyless-csi-provider` | `akeyless-csi-provider` | CSI secrets provider chart. |
| `akeyless-k8s-secrets-injection` | `akeyless-secrets-injection` | Mutating webhook chart for Kubernetes secret injection. |

## Versioning Rules

Every chart change must include a semver `version` bump in that chart's `Chart.yaml`. CI uses chart-testing with `check-version-increment: true` in `.github/ct.yaml` for PR chart changes.

Only bump `appVersion` when the application version changes. Template, values, README, or chart metadata-only changes normally require only the chart `version` bump.

Special version fields:

- `akeyless-gateway`
  - `version` — chart version; bump on every chart change.
  - `appVersion` — composite `<gatewayVersion>_<sraVersion>`.
  - `annotations.gatewayVersion` — gateway image version.
  - `annotations.sraVersion` — SRA image version.
- `akeyless-secure-remote-access`
  - `appVersion` — composite `<ztbVersion>_<ztpVersion>`.
  - `annotations.ztbVersion` — Zero Trust Bastion image version.
  - `annotations.ztpVersion` — Zero Trust Portal image version.

The automated version update scripts in `.github/scripts/latest_version_release.sh` and `.github/scripts/common.sh` read and update these fields with `yq` when available and `awk` fallbacks otherwise. `extract_chart_field` and `update_chart_field` support root-level fields and fields under `annotations`.

## CI/CD Workflows

| Workflow | Trigger | Action |
| --- | --- | --- |
| `.github/workflows/chart_test.yaml` | Pull requests touching charts or chart-test config | Runs chart-testing list/lint/install with `.github/ct.yaml`; installs changed charts into a kind cluster and dumps diagnostics on install failures. |
| `.github/workflows/chart_release.yaml` | Push to `main` touching charts | Packages and publishes charts with `helm/chart-releaser-action`. |
| `.github/workflows/chart_release.yaml` | GitHub Deployment with `task: update-latest-version` | Runs `.github/scripts/latest_version_release.sh`, commits chart/app version updates, pushes them, and dispatches the manifests repo update. |
| `.github/workflows/update_manifests.yaml` | Manual `workflow_dispatch` | Runs `.github/scripts/generate_manifests.sh` and opens/merges a generated manifests PR. |
| `.github/workflows/git-issues-jira-automation.yaml` | Issue-related automation | Jira integration for GitHub issues. |

The automated latest-version release is triggered by GitHub Deployments with a JSON payload containing `service`, `major_minor_patch`, and `app_version`.

Service-to-chart mappings in `.github/scripts/latest_version_release.sh`:

- `gateway` → `akeyless-api-gateway`, `akeyless-gateway`
- `zero-trust-bastion` → `akeyless-secure-remote-access`, `akeyless-gateway`
- `zt-portal` → `akeyless-secure-remote-access`
- `zero-trust-web-access` → `akeyless-zero-trust-web-access`
- `k8s-webhook` → `akeyless-k8s-secrets-injection`

## Chart-Specific Notes

### `akeyless-k8s-secrets-injection`

- `templates/apiservice-webhook.yaml` creates a generated CA/cert Secret and one `MutatingWebhookConfiguration`.
- New Kubernetes `MutatingWebhook` fields can generally be passed through `.Values.mutatingWebhook` without changing the template.
- Use `.Values.mutatingWebhook.failurePolicy` for the webhook failure policy. The old top-level `webhookFailurePolicy` value was removed in chart `2.0.0`.
- `.Values.mutatingWebhook.namespaceSelector`, `.Values.mutatingWebhook.objectSelector`, and `.Values.mutatingWebhook.matchConditions` are rendered with `tpl`, so defaults and overrides can reference release context.
- The chart owns the generated `name`, `clientConfig`, `rules`, `admissionReviewVersions`, and `sideEffects` fields to preserve existing behavior and avoid duplicate YAML keys.

## Contribution Guidance

- Keep changes small and chart-local unless the task requires cross-chart updates.
- Prefer existing chart patterns and values structure.
- Update chart README/configuration docs when adding user-facing values.
- Do not commit changes unless explicitly asked.
