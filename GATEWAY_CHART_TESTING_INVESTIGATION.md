# Gateway chart-testing investigation

Last updated: 2026-05-21

## Context

This PR adds chart tests for charts in this repository. The two gateway charts have timed out in GitHub Actions `ct install` even though they can install successfully on local kind and on the testing EKS cluster.

Affected charts:

- `charts/akeyless-api-gateway`
- `charts/akeyless-gateway`

Relevant GitHub Actions runs investigated:

- `26228633712` — failure, head SHA `a28830ffa26f9b7df833f12208cd9161141eaf63`
- `26230089904` — failure, head SHA `704e1d1decc7e28e738c4442d893abf47a63c168`
- `26232215225` — failure, head SHA `8fae5d8942309e9c4da4fdb3875624e035c80aa5`
- `26239834081` — **success** after pinning chart testing to `ubuntu-22.04`, head SHA `79c4403`

## Current working tree status

Current intentional changes:

- Remove PR-added `/run/akeyless` CI mounts from gateway CI values:
  - `charts/akeyless-api-gateway/ci/clusterip-values.yaml`
  - `charts/akeyless-gateway/ci/access-key-existing-secret-values.yaml`
  - `charts/akeyless-gateway/ci/redis-ha-values.yaml`
- Pin chart-testing workflow runner to `ubuntu-22.04`:
  - `.github/workflows/chart_test.yaml`

No gateway chart template changes are currently intended.

No Helm/kind version pinning is currently intended.

Validation runs after these changes:

```sh
ct lint --config .github/ct.yaml
```

Result: passed locally.

GitHub Actions:

```text
Chart Test run 26239834081
```

Result: passed on `ubuntu-22.04`.

## Key conclusion so far

The install failures are real runtime failures, not generic Helm wait/probe noise.

The consistent concrete blocker in GitHub diagnostics is:

```text
rsyslogd: cannot create '/run/akeyless/syslog': Permission denied
rsyslogd: error writing pid file (creation stage)
rsyslogd: run failed with error -3000
rsyslog entered FATAL state, too many start retries too quickly
```

This causes the gateway container processes to exit and the pods to enter `CrashLoopBackOff` / repeated restarts. The application can still log many scary messages in successful runs; not every error in these images is a readiness/liveness blocker.

New internal comparison runs show the rsyslog failure follows GitHub-hosted `ubuntu-24.04` / Azure kernel `6.17.0-1013-azure`, not kind node image `v1.35.0` alone: `ubuntu-24.04` still failed with kind nodes `v1.34.3` and `v1.33.7`, while `ubuntu-22.04` got the gateway deployment Ready and only failed later on Redis `ImagePullBackOff` in the older internal chart fixture.

Based on this, the current practical CI fix is to pin `.github/workflows/chart_test.yaml` to `ubuntu-22.04` instead of `ubuntu-latest`/`ubuntu-24.04`, while avoiding speculative gateway chart template changes.

## Important correction about `/run/akeyless` emptyDir mounts

The `/run/akeyless` `emptyDir` CI mounts were added during this PR, but they are **not proven to be the original root cause**.

Checked run head SHAs:

- `26228633712` (`a28830f...`): no `/run/akeyless` CI mount in values.
- `26230089904` (`704e1d...`): no `/run/akeyless` CI mount in values.
- `26232215225` (`8fae5d...`): had `/run/akeyless` CI mount in values.

So GitHub failed both before and after those mounts existed.

Removing those mounts is still cleaner because they were PR-added and unnecessary in local/EKS tests, but do not treat that removal as a confirmed fix by itself.

## GitHub Actions environment from failing runs

All examined failing GitHub runs used essentially the same environment:

```text
Runner image: ubuntu-24.04
Runner version: 2.334.0
helm/kind-action SHA: ef37e7f390d99f746eb8b610417061a60e82a6cc
kind version: v0.31.0
kubectl version: v1.35.0
kind node image: kindest/node:v1.35.0
node OS: Debian GNU/Linux 12 (bookworm)
node kernel: 6.17.0-1013-azure
node architecture: amd64
container runtime: containerd://2.2.0
```

Images pulled in GitHub match local/EKS digests:

```text
akeyless/base:latest -> docker.io/akeyless/base@sha256:759e4289fae8f028ced292fa651ebca33f3dedd146ae12382caf1a1acf451b2f
akeyless/gateway:4.51.1 -> docker.io/akeyless/gateway@sha256:738ea6745d6eacff14a180df7a78f2f780a1bd8c25ef1c1d69688a832c510c38
```

So this is not image drift.

## helm/kind-action inspection

The pinned action `helm/kind-action@ef37e7f390d99f746eb8b610417061a60e82a6cc` was inspected.

Important files checked:

- `action.yml`
- `main.js`
- `main.sh`
- `kind.sh`
- `registry.sh`
- `cleanup.js`
- `cleanup.sh`

Findings:

- The action is mostly a thin shell wrapper around downloading `kind` and running `kind create cluster`.
- It does **not** apply explicit hardening such as AppArmor/seccomp/user namespace settings.
- It does **not** pass a custom kind config unless workflow input `config` is set.
- With the current workflow, registry and cloud-provider paths are disabled.
- Effective create command shape is:

```sh
kind create cluster --name=chart-testing --wait=60s
```

- Since no `node_image` input is currently set, kind `v0.31.0` defaults to `kindest/node:v1.35.0`.
- The action defaults from `action.yml` / `kind.sh` are:
  - kind: `v0.31.0`
  - kubectl: `v1.35.0`
  - cluster name: `chart-testing`
  - wait: `60s`

Conclusion: nothing in `helm/kind-action` itself appears to intentionally harden the kind cluster. If GitHub differs, it is likely coming from the GitHub-hosted runner/Docker/kernel layer underneath kind, or from kind/node-image behavior on that layer.

## Local kind test results

Current local context used:

```text
kind-helm-chart-testing
```

Local kind node:

```text
Kubernetes: v1.35.0
OS: Debian GNU/Linux 12 (bookworm)
Kernel: 6.15.9-201.fc42.aarch64
Runtime: containerd://2.2.0
Architecture: arm64
```

### Install with current CI values, without `/run/akeyless` mount

Both charts installed successfully with `--wait`:

- `debug-api-gateway`: pod `Running`, `0` restarts
- `debug-gateway`: pods `Running`, `0` restarts

Logs showed:

```text
rsyslog entered RUNNING state
Gateway ... started in offline mode
```

### Install with temporary values re-adding `/run/akeyless` emptyDir mount

Both charts also installed successfully with `--wait`.

Pod descriptions confirmed:

```text
/run/akeyless from akeyless-run (rw)
```

Logs still showed:

```text
rsyslog entered RUNNING state
```

So the `/run/akeyless` mount alone is not sufficient to reproduce the GitHub failure on local kind.

## EKS test results

Tested context:

```text
us-east-2-dev-eks-new
```

EKS nodes:

```text
Kubernetes: v1.35.4-eks-40737a8
OS: Amazon Linux 2023.11.20260413
Kernel: 6.12.79-101.147.amzn2023.x86_64
Runtime: containerd://2.2.1+unknown
Architecture: amd64
```

Both charts installed successfully with temporary values re-adding `/run/akeyless` emptyDir mount.

Pod descriptions confirmed:

```text
/run/akeyless from akeyless-run (rw)
```

Logs showed:

```text
rsyslog entered RUNNING state
Gateway ... started in offline mode
```

So EKS, even on amd64 + Kubernetes 1.35 + containerd 2.2.x, does not reproduce the GitHub failure.

## Local tooling note

Local Docker CLI is not available in this environment, but Podman is available:

```text
podman version 5.8.2
```

Podman can be used for local image inspection, with the caveat that this local machine is arm64 and some gateway images are amd64, so platform warnings may appear.

## Permission probe results

Ran direct command-only pods with:

- `akeyless/gateway:4.51.1`
- `akeyless/base:latest`

Both with and without `emptyDir` mounted at `/run/akeyless`.

### Local kind

`akeyless/gateway:4.51.1`, image filesystem:

```text
uid=1001(akeyless) gid=1001(akeyless) groups=1001(akeyless),0(root),4(adm),100(users),999(systemd-journal)
/run          775 0    0
/run/akeyless 775 1001 0
touch-ok
```

`akeyless/gateway:4.51.1`, emptyDir mounted at `/run/akeyless`:

```text
uid=1001(akeyless) gid=1001(akeyless) groups=1001(akeyless),0(root),4(adm),100(users),999(systemd-journal)
/run          775 0 0
/run/akeyless 777 0 0
touch-ok
```

`akeyless/base:latest`, image filesystem:

```text
uid=0(root) gid=0(root) groups=0(root)
/run          755 0 0
/run/akeyless 755 0 0
touch-ok
```

`akeyless/base:latest`, emptyDir mounted at `/run/akeyless`:

```text
uid=0(root) gid=0(root) groups=0(root)
/run          755 0 0
/run/akeyless 777 0 0
touch-ok
```

### EKS

Same results as local kind for the relevant permissions:

- `akeyless/gateway` image filesystem: `/run/akeyless` is `775 1001 0`, writable by user `1001`.
- `akeyless/gateway` with emptyDir: `/run/akeyless` is `777 0 0`, writable.
- `akeyless/base` runs as root and can write in both cases.

## GitHub failure comparison

GitHub run `26232215225` with `/run/akeyless` mount showed pod descriptions confirming:

```text
/run/akeyless from akeyless-run (rw)
akeyless-run: EmptyDir
```

But logs showed:

```text
rsyslogd: cannot create '/run/akeyless/syslog': Permission denied
```

This differs from local kind and EKS, where the same emptyDir mount appears as `0777 root:root` and is writable.

GitHub run `26230089904` failed similarly before the CI values had the `/run/akeyless` mount. That suggests the image filesystem path itself may also be seen as non-writable under GitHub kind, or rsyslog is hitting a slightly different permission/mount behavior there.

## Noisy but non-blocking logs

These appear in successful local/EKS runs and should not be treated as blockers by themselves:

```text
AuthenticationFailed / invalid dummy credentials
cluster admin is invalid
Gateway started in offline mode
rm: cannot remove '/etc/cron.daily/apt-compat': Permission denied
cp: cannot stat '/akeyless_shared_vol/.../op': No such file or directory
```

The readiness blocker is the repeated `rsyslog` permission failure leading to supervisor fatal state / process exit.

## GitHub runner image details

Checked the current runner image documentation:

- Source: `https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md`
- Runner OS: Ubuntu `24.04.4 LTS`
- Kernel: `6.17.0-1013-azure`
- Image version in docs: `20260513.135.3`
- Docker Client: `28.0.4`
- Docker Server: `28.0.4`
- Docker Compose: `2.38.2`
- Docker Buildx: `0.33.0`
- Preinstalled Kind: `0.31.0`
- Preinstalled Kubectl: `1.36.1`
- Podman: `4.9.3`
- Buildah: `1.33.7`
- Skopeo: `1.13.3`

The failing workflow does not use the preinstalled Helm/Kubectl directly for all steps:

- `azure/setup-helm` installed Helm `v4.2.0` in the failing runs.
- `helm/kind-action` installed/used kind `v0.31.0` and kubectl `v1.35.0`.

Potentially relevant runner-image layer: Docker Server `28.0.4` on Ubuntu 24.04 / Azure kernel `6.17.0-1013-azure`. Local kind and EKS do not match this host Docker/kernel combination.

## Internal diagnostic run results so far

Internal branch/workflow:

```text
repo: akeylesslabs/internal-helm-chart-testing
branch: gateway-kind-permissions
workflow: Gateway kind permissions probe
```

Runs:

- `26236909615` — push, permission probes only, success.
- `26237166767` — manual dispatch with `install_gateway=true`, targeted gateway install failed and reproduced rsyslog issue.
- `26237874917` — push after adding rsyslog probes, success.
- `26238532375` — manual dispatch, `ubuntu-24.04` + `kindest/node:v1.34.3` + targeted install, failed with same rsyslog `/run/akeyless/syslog` permission error.
- `26238532438` — manual dispatch, `ubuntu-24.04` + `kindest/node:v1.33.7` + targeted install, failed with same rsyslog `/run/akeyless/syslog` permission error.
- `26238532507` — manual dispatch, `ubuntu-22.04` + default kind node + targeted install, did **not** show the rsyslog `/run/akeyless/syslog` failure; gateway pods reached `1/1 Running`, but Helm still timed out because Redis was `ImagePullBackOff`.
- `26239778629` — manual dispatch after disabling internal diagnostic cluster cache, `ubuntu-22.04` + default kind node + targeted install; gateway pods reached `1/1 Running` and deployment `2/2` available, but Helm still timed out because the diagnostic service remained `LoadBalancer` with no external IP in kind.
- `26239778731` — manual dispatch after adding `rsyslog-startup-runner`/mitigation probes, `ubuntu-24.04` + default kind node + targeted install; `rsyslog-startup-runner` probes and targeted install still reproduced `/run/akeyless/syslog` permission failure.

### `26236909615`: simple permission probe on GitHub kind

Environment matched the public failing workflow shape closely enough to be useful: GitHub-hosted runner, `helm/kind-action`, kind, and the gateway/base images. The simple write probes showed `touch-ok` for `/run/akeyless`, so the failure is not explained by basic writability of that directory.

The strongest current hypothesis is a GitHub-hosted runner/kind filesystem or security-layer difference, not a chart template issue.

Likely layers:

- GitHub-hosted `ubuntu-24.04` Docker daemon settings
- AppArmor/seccomp/user namespace behavior on GitHub-hosted runners
- kind node container mount/overlay behavior on GitHub's Azure kernel
- kind/node image behavior under that Docker/kernel combination

Less likely / ruled down:

- Image drift: digests match.
- Architecture alone: EKS amd64 succeeds.
- Kubernetes 1.35 alone: local kind and EKS Kubernetes 1.35 succeed.
- containerd 2.2 alone: local kind and EKS containerd 2.2.x succeed.
- Dummy credential errors: appear in successful runs too.
- `/run/akeyless` emptyDir mount alone: local kind and EKS succeed with it.

## Internal-repo diagnostic workflow

Created a manual-dispatch workflow in the internal repo:

```text
internal-helm-chart-testing/.github/workflows/gateway_kind_permissions_probe.yaml
```

Workflow name:

```text
Gateway kind permissions probe
```

Triggers:

- `workflow_dispatch` with configurable inputs
- `push` to branches matching `gateway-kind-permissions*` when this workflow file changes
- `pull_request` when this workflow file changes

The `push`/`pull_request` triggers were added because a brand-new `workflow_dispatch` workflow may not be manually runnable until the workflow exists on the default branch.

Inputs:

- `runner`: `ubuntu-24.04` or `ubuntu-22.04`
- `kind_version`: optional; blank uses `helm/kind-action` default
- `kubectl_version`: optional; blank uses `helm/kind-action` default
- `node_image`: optional; blank uses kind default
- `install_gateway`: boolean; when true, runs a targeted `akeyless-gateway` Helm install after the permission probes

The workflow:

1. Checks out the internal repo.
2. Sets up Helm `v3.14.4`.
3. Creates kind using `helm/kind-action@ef37e7f390d99f746eb8b610417061a60e82a6cc`.
4. Dumps host/kind environment details (`docker info`, `docker inspect chart-testing-control-plane`, node describe, AppArmor files, etc.).
5. Runs four permission probe pods:
   - `akeyless/gateway:4.51.1` without `/run/akeyless` mount
   - `akeyless/gateway:4.51.1` with `emptyDir` mounted at `/run/akeyless`
   - `akeyless/base:latest` without `/run/akeyless` mount
   - `akeyless/base:latest` with `emptyDir` mounted at `/run/akeyless`
6. Optionally installs `charts/akeyless-gateway` with `charts/akeyless-gateway/ci/access-key-id-existing-secret-values.yaml` and dumps pod logs/describes.

Suggested first run:

- Branch name: `gateway-kind-permissions` or similar, so the `push` trigger runs.
- Defaults are equivalent to:

```text
runner: ubuntu-24.04
kind_version: <blank>
kubectl_version: <blank>
node_image: <blank>
install_gateway: false
```

If the first run shows GitHub probe `touch-ok` with expected permissions, manually dispatch or edit inputs/branch workflow for `install_gateway: true` to see if rsyslog still fails in a targeted install.

### `26238532375` / `26238532438` / `26238532507`: runner and node-image comparison

These runs materially narrowed the failure:

| Run | Runner | kind node image | Targeted install result |
| --- | --- | --- | --- |
| `26238532375` | `ubuntu-24.04` | `kindest/node:v1.34.3` | Gateway pods `CrashLoopBackOff`; rsyslog could not create `/run/akeyless/syslog` and entered FATAL state. |
| `26238532438` | `ubuntu-24.04` | `kindest/node:v1.33.7` | Gateway pods `CrashLoopBackOff`; same rsyslog `/run/akeyless/syslog` permission failure. |
| `26238532507` | `ubuntu-22.04` | default node | Gateway deployment reached `2/2` available and gateway pods were `1/1 Running`; Helm timed out because `docker.io/bitnami/redis:6.2` was `ImagePullBackOff`, not because of rsyslog. |
| `26239778629` | `ubuntu-22.04` | default node | With internal diagnostic cache disabled, gateway pods reached `1/1 Running` and deployment `2/2` available; Helm still timed out because the diagnostic service remained `LoadBalancer` in kind. |
| `26239778731` | `ubuntu-24.04` | default node | `rsyslog-startup-runner` failed with `cannot create '/run/akeyless/syslog': Permission denied`; targeted install still had gateway `CrashLoopBackOff`/non-ready pods. |

Important environment comparison:

- `ubuntu-24.04` runs: host kernel `6.17.0-1013-azure`, Docker Server `28.0.4`, containerd `77c84241...`, runc `v1.3.5-0-g488fc13e`.
- `ubuntu-22.04` run: host kernel `6.8.0-1052-azure`, Docker Server `28.0.4`, containerd `77c84241...`, runc `v1.3.5-0-g488fc13e`.
- Docker inspect of the kind control-plane still showed the node container started with `seccomp=unconfined` and `apparmor=unconfined` in both cases.

Interpretation:

- The rsyslog failure follows the **GitHub `ubuntu-24.04` runner / Azure kernel line**, not the kind node image version alone.
- Older kind node images `v1.34.3` and `v1.33.7` do **not** avoid the rsyslog failure on `ubuntu-24.04`.
- `ubuntu-22.04` is a useful control: the gateway container can start and become Ready under the same workflow shape when the host kernel is `6.8`; remaining internal diagnostic Helm timeouts were unrelated to rsyslog (`ImagePullBackOff` before cache was disabled, then `LoadBalancer` service wait in kind).

## Recommended next internal-repo experiments

Use `akeylesslabs/internal-helm-chart-testing` to run quiet experiments before changing the public PR again.

Goal: isolate whether the failure is caused by GitHub-hosted runner Docker/kernel/kind behavior, kind node image version, or something in chart-testing flow.

Recommended experiment order:

1. **Permission probe only, no chart installs**
   - Use `ubuntu-24.04` GitHub-hosted runner.
   - Use `helm/kind-action@ef37e7f390d99f746eb8b610417061a60e82a6cc` with defaults.
   - After kind creation, run the permission probe pods listed below.
   - This answers whether GitHub kind sees `/run/akeyless` as writable at all.

2. **Same probe with pinned older kind node images**
   - Keep same runner.
   - Matrix `node_image` values:
     - default `kindest/node:v1.35.0`
     - `kindest/node:v1.34.3@sha256:08497ee19eace7b4b5348db5c6a1591d7752b164530a36f855cb0f2bdcbadd48` — tested by targeted install in `26238532375`; still failed with rsyslog on `ubuntu-24.04`.
     - `kindest/node:v1.33.7@sha256:d26ef333bdb2cbe9862a0f7c3803ecc7b4303d8cea8e814b481b09949d353040` — tested by targeted install in `26238532438`; still failed with rsyslog on `ubuntu-24.04`.
     - `kindest/node:v1.32.11@sha256:5fc52d52a7b9574015299724bd68f183702956aa4a2116ae75a63cb574b35af8`
     - `kindest/node:v1.31.14@sha256:6f86cf509dbb42767b6e79debc3f2c32e4ee01386f0489b3b2be24b0a55aac2b`
   - These are the prebuilt images listed in kind `v0.31.0` release notes.
   - Current evidence already rules down kind node `v1.35.0` as the only trigger.

3. **Same probe on `ubuntu-22.04` runner**
   - Run `26238532507` did this with a targeted install.
   - Result: gateway pods became Ready on `ubuntu-22.04`; Helm failed for unrelated Redis `ImagePullBackOff`.
   - This strongly implicates host runner image/kernel behavior rather than the chart or kind node image alone.

4. **Targeted gateway install only after probe**
   - This has now reproduced the failure on `ubuntu-24.04` and shown a contrasting non-rsyslog result on `ubuntu-22.04`.
   - Avoid full `ct install` initially to reduce noise.
   - Compare whether rsyslog behavior follows the permission probe.

5. **Next most useful probe: same image startup path under altered pod security context**
   - Add/commit the local workflow step that runs `rsyslog-startup-runner` directly.
   - Extend it with variants using `securityContext.privileged: true` and, if supported, AppArmor unconfined annotations/profiles.
   - Purpose: determine whether the `ubuntu-24.04` failure is mediated by pod-level LSM/seccomp behavior even though the kind node container itself is unconfined.

Suggested extra diagnostics for every internal run:

```sh
docker info || true
docker inspect chart-testing-control-plane || true
docker version || true
uname -a || true
ls -l /sys/module/apparmor/parameters/enabled || true
cat /sys/module/apparmor/parameters/enabled || true
kubectl get nodes -o wide || true
kubectl describe nodes || true
```

## Recommended next workflow diagnostic

Add a temporary GitHub Actions diagnostic step after creating kind and before `ct install`.

Purpose: compare GitHub kind permission probes against local/EKS baselines.

Suggested script:

```sh
kubectl create namespace chart-testing-perms --dry-run=client -o yaml | kubectl apply -f -

cat <<'EOF' | kubectl apply -n chart-testing-perms -f -
apiVersion: v1
kind: Pod
metadata:
  name: gateway-perms-image
spec:
  restartPolicy: Never
  containers:
    - name: gateway
      image: akeyless/gateway:4.51.1
      command:
        - sh
        - -c
        - 'id; ls -ld /run /run/akeyless || true; stat -c "%a %u %g %n" /run /run/akeyless || true; touch /run/akeyless/probe && echo touch-ok || echo touch-failed; cat /proc/self/status | grep -E "Uid|Gid|Groups|NoNewPrivs|Cap"; sleep 5'
---
apiVersion: v1
kind: Pod
metadata:
  name: gateway-perms-emptydir
spec:
  restartPolicy: Never
  containers:
    - name: gateway
      image: akeyless/gateway:4.51.1
      command:
        - sh
        - -c
        - 'id; ls -ld /run /run/akeyless || true; stat -c "%a %u %g %n" /run /run/akeyless || true; touch /run/akeyless/probe && echo touch-ok || echo touch-failed; cat /proc/self/status | grep -E "Uid|Gid|Groups|NoNewPrivs|Cap"; sleep 5'
      volumeMounts:
        - name: akeyless-run
          mountPath: /run/akeyless
  volumes:
    - name: akeyless-run
      emptyDir: {}
---
apiVersion: v1
kind: Pod
metadata:
  name: base-perms-image
spec:
  restartPolicy: Never
  containers:
    - name: base
      image: akeyless/base:latest
      command:
        - sh
        - -c
        - 'id; ls -ld /run /run/akeyless || true; stat -c "%a %u %g %n" /run /run/akeyless || true; touch /run/akeyless/probe && echo touch-ok || echo touch-failed; cat /proc/self/status | grep -E "Uid|Gid|Groups|NoNewPrivs|Cap"; sleep 5'
---
apiVersion: v1
kind: Pod
metadata:
  name: base-perms-emptydir
spec:
  restartPolicy: Never
  containers:
    - name: base
      image: akeyless/base:latest
      command:
        - sh
        - -c
        - 'id; ls -ld /run /run/akeyless || true; stat -c "%a %u %g %n" /run /run/akeyless || true; touch /run/akeyless/probe && echo touch-ok || echo touch-failed; cat /proc/self/status | grep -E "Uid|Gid|Groups|NoNewPrivs|Cap"; sleep 5'
      volumeMounts:
        - name: akeyless-run
          mountPath: /run/akeyless
  volumes:
    - name: akeyless-run
      emptyDir: {}
EOF

kubectl wait --for=condition=PodReadyToStartContainers pod --all -n chart-testing-perms --timeout=120s || true
kubectl get pods -n chart-testing-perms -o wide || true
kubectl describe pods -n chart-testing-perms || true
for pod in gateway-perms-image gateway-perms-emptydir base-perms-image base-perms-emptydir; do
  echo "### $pod"
  kubectl logs -n chart-testing-perms "$pod" || true
done
```

Also useful to dump GitHub host/kind-node security details:

```sh
docker info || true
docker inspect chart-testing-control-plane || true
kubectl get nodes -o yaml || true
```

Compare GitHub output to local/EKS baseline above. The key line to look for is whether GitHub reports `touch-failed`, different `/run/akeyless` permissions, different identity/groups, or different security bits.

## PR guidance

Keep chart changes as a last resort.

Recommended near-term PR state:

1. Keep removal of the PR-added `/run/akeyless` CI mounts because they are unnecessary and not representative of default chart behavior.
2. Pin chart testing to `ubuntu-22.04` because internal controls show the failure follows GitHub `ubuntu-24.04`/kernel `6.17`, while `ubuntu-22.04` does not reproduce the rsyslog crash. Public PR Chart Test run `26239834081` passed with this pin.
3. Avoid init containers, `runAsUser`, `fsGroup`, or template changes unless diagnostics prove they are necessary and safe.

## Cleanup performed

Temporary local namespaces created during investigation were deleted:

- `chart-testing-debug`
- `chart-testing-debug-mounted`
- `chart-testing-perms`

Temporary EKS namespaces created during investigation were deleted:

- `chart-testing-debug-eks`
- `chart-testing-perms`

Temporary files removed:

- `.tmp/`
- `.perms-debug.yaml`
