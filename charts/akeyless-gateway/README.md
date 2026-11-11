# Akeyless Gateway

This repository contains the official Akeyless Gateway Helm chart for installing and configuring the Gateway on Kubernetes.

For full documentation on this Helm chart please see the [official docs](https://docs.akeyless.io/docs/gateway-chart)


## Prerequisites

To use the charts here, [Helm](https://helm.sh/) must be configured for your
Kubernetes cluster. Setting up Kubernetes and Helm is outside the scope of
this README. Please refer to the Kubernetes and Helm documentation.

### Horizontal Autoscaling

The Kubernetes [metrics server](https://github.com/kubernetes-sigs/metrics-server) must be configured in your cluster.


## Add Akeyless Repository

To install the latest version of this chart, add the Akeyless Helm repository

```bash
helm repo add akeyless https://akeylesslabs.github.io/helm-charts
helm repo update
```

## Installing the Chart

Please see all supported options directly on the Akeyless Docs website along with more
detailed installation instructions.

To install the chart run the following:
```bash
helm install gateway akeyless/akeyless-gateway
```

## Upgrade Notes

### 3.13.0: custom CA extends the trust store

From 3.13.0 `gateway.customCA` and `sra.customCA` default to `mode: extend`: the bundle is added to the image trust store. Before 3.13.0 the bundle replaced `/etc/ssl/certs/ca-certificates.crt`.

| Release before the upgrade | Effect of the upgrade to 3.13.0 or later |
| --- | --- |
| `customCA.enabled: false` | None. |
| `customCA.enabled: true`, bundle holds only your CAs | Public roots are trusted again, beside your CAs. The pods restart with the new init container. |
| `customCA.enabled: true`, bundle holds public roots and your CAs | No change in trust. The pods restart with the new init container. |
| You need the earlier behaviour | Set `mode: replace`. The pod spec stays as before the upgrade. |

### 3.12.1: SRA SSH replicas

From 3.12.1 the SRA SSH deployment sets `spec.replicas` from `sra.sshConfig.replicaCount` only when `sra.sshConfig.hpa.enabled` is false, the same as the SRA web and Gateway deployments. Earlier versions did the opposite.

| Release before the upgrade | Effect of the first upgrade to 3.12.1 or later |
| --- | --- |
| SSH HPA off, default values | None. The deployment keeps 1 replica. |
| SSH HPA off, `sra.sshConfig.replicaCount` set | The deployment scales to `replicaCount`. Before 3.12.1 the value was ignored. |
| SSH HPA off, scaled by hand | The deployment scales to `replicaCount`. Set `replicaCount` to the count you run before the upgrade. |
| SSH HPA on | Helm removes `spec.replicas` from the deployment, so it scales to 1 and the HPA scales it back. SSH sessions on the removed pods end. |

With the SSH HPA on, run the first upgrade to 3.12.1 or later in a maintenance window:

1. Before the upgrade, record the current count: `kubectl get hpa -n <namespace>`.
2. Run `helm upgrade`.
3. Confirm the HPA restored the count and the SSH pods are ready: `kubectl get hpa,deployment -n <namespace>`.

Later upgrades do not change `spec.replicas`, and the HPA stays in control.

## Cluster DNS Domain

Clusters whose DNS search domain is not the default `svc.cluster.local` (for example `svc.custom.local`) must set `clusterDomain` so SRA internal service URLs resolve correctly:

```yaml
clusterDomain: custom.local
```

## Extra Volumes and Volume Mounts

To add custom Kubernetes volumes to the Gateway pod and mount them into the Gateway container, configure `gateway.deployment.extraVolumes` and `gateway.deployment.extraVolumeMounts`:

```yaml
gateway:
  deployment:
    extraVolumes:
      - name: custom-secret
        secret:
          secretName: custom-secret
    extraVolumeMounts:
      - name: custom-secret
        mountPath: /etc/custom-secret
        readOnly: true
```

## Custom CA

Environments that re-sign outbound TLS with an internal CA (a TLS-intercepting proxy), or that reach internal services signed by a private CA, must trust that CA from the first outbound connection. The Gateway uses `gateway.customCA`. The SRA web and SSH deployments use `sra.customCA`. The two are independent: set both when both components need the CA.

```yaml
gateway:
  customCA:
    enabled: true
    mode: "extend"            # or "replace"
    volumeName: "ca-certificates"
    volumeType: "configMap"   # or "secret"
    volumeSourceName: "<configmap-or-secret-name>"

sra:
  customCA:
    enabled: true
    mode: "extend"
    volumeName: "ca-certificates"
    volumeType: "configMap"
    volumeSourceName: "<configmap-or-secret-name>"
```

| Value | Default | Meaning |
| --- | --- | --- |
| `enabled` | `false` | Off renders nothing for the component. |
| `mode` | `extend` | How the bundle reaches the container trust store. See [Modes](#modes). |
| `resources` | `{}` | Requests and limits for the `custom-ca-trust` init container in `extend` mode. Empty renders none, except under `strictSecurityPolicy.enabled`, which sets 10m / 32Mi requests and 100m / 64Mi limits. |
| `volumeName` | `ca-certificates` | Name of the pod volume that holds the bundle. |
| `volumeType` | `configMap` | `configMap` or `secret`, case-insensitive. Any other value fails the render. |
| `volumeSourceName` | `""` | Name of the ConfigMap or Secret. Required when `enabled` is true. It must have the key `ca-certificates.crt`, which holds one or more PEM certificates. |

### Modes

| | `extend` (default) | `replace` |
| --- | --- | --- |
| What the bundle holds | Only your CAs: the proxy CA, internal roots, intermediates. | Every CA the container trusts, public roots included. |
| Effect on the image trust store | Your CAs are added. The public roots in the image stay trusted. | The bundle is mounted over `/etc/ssl/certs/ca-certificates.crt` and hides the image's file. |
| Pod changes | An init container, `custom-ca-trust`, runs the same image. It copies `/etc/ssl/certs` and `/usr/local/share/ca-certificates` into `emptyDir` volumes, appends the bundle to `ca-certificates.crt`, and adds it as `custom-ca.crt` for `update-ca-certificates`. The container mounts both volumes. | One `subPath` mount. No init container. |
| Gateway CA Certificate Store | Works. Certificates added at runtime are added beside your CAs. | `update-ca-certificates` cannot replace the mounted file, so certificates added at runtime do not reach the system trust store. |
| With `gateway.deployment.readOnlyRootFilesystem` | Supported. The init container fills the same trust volumes, and the image's startup seed does not overwrite the bundle. | Not recommended. The bundle must hold every CA. |

`extend` accepts a full bundle too: roots that are already in the image are trusted twice, which has no effect.

When the Gateway release already uses `/etc/ssl/certs` or `/usr/local/share/ca-certificates`, `gateway.customCA` renders as `replace`, so the pod spec stays as it was. That is the case for a `gateway.deployment.extraVolumeMounts`, `gateway.persistence.mountPath` or `gateway.secretsStore.mountPath` on either path, or a `gateway.deployment.extraVolumes` entry named `etc-ssl-certs` or `usr-local-ca-certificates` without `readOnlyRootFilesystem`. Remove that mount to get `extend`.

In `extend` the init container parses each certificate in the bundle. When a certificate does not parse, it logs a warning and the pod starts as before: `kubectl logs <pod> -c custom-ca-trust` shows `customCA: warning: ... holds N PEM certificates and M parse`. TLS clients skip a certificate that does not parse, so that CA is not trusted. The usual cause is a bundle written on one line, for example with `kubectl create secret --from-literal`: create it with `--from-file` instead, so each `-----BEGIN CERTIFICATE-----` and `-----END CERTIFICATE-----` marker sits on its own line.

`custom-ca-trust` runs the component's own image, so `extend` needs `/bin/sh`, `cp`, `cat` and `printf` in that image, as the Gateway and SRA images have. The check also uses `awk`, `tr` and `openssl`, and is skipped when the image lacks `awk` or `openssl`. With a custom image that has no shell, the init container fails and the pod does not start: use `mode: replace`.

### Build a bundle for replace mode

Start from the bundle in the image you run, then add your CAs:

```bash
docker run --rm --entrypoint cat akeyless/gateway:<tag> /etc/ssl/certs/ca-certificates.crt > ca-certificates.crt
cat private-root.crt private-intermediate.crt >> ca-certificates.crt
kubectl -n <namespace> create configmap <name> --from-file=ca-certificates.crt
```

Use `akeyless/zero-trust-bastion:<tag>` for the SRA bundle.

### Verify

From a running Gateway pod, check that a public chain and a chain signed by your CA both verify. Pass `-CAfile`: the `openssl` binary in the Gateway image does not read `/etc/ssl` by default, so without it every chain fails to verify.

```bash
kubectl -n <namespace> exec deploy/<gateway-deployment> -- sh -c \
  'echo | openssl s_client -CAfile /etc/ssl/certs/ca-certificates.crt -connect <host>:<port> -servername <host> 2>&1 | grep "Verify return code"'
```

Expect `Verify return code: 0 (ok)` for a public endpoint, for example the message queue on port 5671, and for an internal endpoint signed by your CA.

### Rotate the bundle

The bundle is read when the pod starts. In both modes a changed ConfigMap or Secret does not reach a running pod. Restart the pods after a change:

```bash
kubectl -n <namespace> rollout restart deployment/<deployment>
```

## Extra Objects

`extraObjects` renders additional Kubernetes manifests as part of the release. Each entry is rendered with `tpl`, so it can reference `.Release`, `.Chart` and `.Values`. Custom resources require their CRDs to be installed before the release.

```yaml
extraObjects:
  - apiVersion: v1
    kind: ConfigMap
    metadata:
      name: "{{ .Release.Name }}-extra"
      namespace: "{{ .Release.Namespace }}"
    data:
      chart: "{{ .Chart.Name }}-{{ .Chart.Version }}"
```

An entry is either a map or a string (`- |`). What the chart does to each:

| | String entry | Map entry |
|---|---|---|
| Values and types | exactly as written | numbers are read as 64-bit floats: `1.0` renders as `1`, integers above 2^53 lose precision |
| Templated values | keep their type: `{{ .Values.x }}` renders a number | always strings: `"{{ .Values.x }}"` renders `'3'` |
| Key order, quoting, comments | kept | keys sorted, quoting normalized, comments dropped |
| `{{ }}` anywhere in the object | evaluated as a template | evaluated as a template |

The chart tests cover values and types, templated values and `{{ }}` handling. Key order, quoting and comments follow Helm and are not tested here.

To pass a literal `{{ }}` through, for example a Prometheus alert using `{{ $labels.instance }}`, escape it as `{{ "{{" }}` and `{{ "}}" }}`. Use a string entry when a field needs an exact value or a templated number or boolean:

```yaml
extraMinAvailable: 1
extraObjects:
  - |
    apiVersion: policy/v1
    kind: PodDisruptionBudget
    metadata:
      name: "{{ .Release.Name }}-extra"
      namespace: "{{ .Release.Namespace }}"
    spec:
      minAvailable: {{ .Values.extraMinAvailable }}
```

## Strict Security Policy (Kyverno/PSA Compliance)

For environments requiring Kyverno or Pod Security Admission (PSA) `restricted` profile compliance, enable the `strictSecurityPolicy` toggle:

```bash
helm install gateway akeyless/akeyless-gateway \
  --set strictSecurityPolicy.enabled=true \
  --set globalConfig.gatewayAuth.gatewayAccessId=<your-access-id> \
  --set globalConfig.gatewayAuth.gatewayAccessType=access_key \
  --set globalConfig.gatewayAuth.gatewayCredentialsExistingSecret=<your-secret>
```

This enforces:
- **Non-root execution** (`runAsUser: 1001`, `runAsNonRoot: true`)
- **Capability drops** (`drop: [ALL]`)
- **No privilege escalation** (`allowPrivilegeEscalation: false`)
- **Explicit resource limits** (CPU/memory)
- **Seccomp profile** (`RuntimeDefault`)

**Applies to:** Gateway, Cache, SRA Web Bastion

**SRA SSH Bastion:** Phase A interim hardening (narrow capabilities, documented Kyverno exception). See [STRICT_SECURITY_POLICY.md](./STRICT_SECURITY_POLICY.md) for full details, SSH exception requirements, and Phase B roadmap.

For comprehensive documentation, troubleshooting, and validation steps, see **[STRICT_SECURITY_POLICY.md](./STRICT_SECURITY_POLICY.md)**.

## Read-Only Root Filesystem

For environments that require an immutable container root filesystem, enable `gateway.deployment.readOnlyRootFilesystem`:

```yaml
gateway:
  deployment:
    readOnlyRootFilesystem: true
```

The feature is **opt-in and default-off**. When false, the deployment is unchanged. When true, the chart:

- Sets the container `securityContext.readOnlyRootFilesystem: true` (also works alongside `strictSecurityPolicy.enabled`).
- Injects `READ_ONLY_ROOT_FS=true`, which tells the Gateway image to redirect its startup writes to writable volumes.
- Mounts `emptyDir` volumes for the paths the Gateway writes at runtime: `/tmp`, `/run`, `/akeyless/tmp`, `/akeyless/bin`, `/var/run/akeyless`, `/var/log/akeyless`, `/var/log/supervisor`, `/var/akeyless/conf`, `/app`, `/download_center`, `/usr/local/share/ca-certificates`, `/etc/ssl/certs`, and the Gateway config dir.
- On startup, the Gateway image seeds `/usr/local/share/ca-certificates` and `/etc/ssl/certs` from image-baked trust stores so `update-ca-certificates` and the CA Certificate Store work under read-only rootfs.

**Requirements and limitations:**

- **Minimum Gateway image version:** requires a Gateway image that supports `READ_ONLY_ROOT_FS` (image version `5.0.0` or later). CA Certificate Store with full OS trust store support requires an image that includes CA trust-store seed paths (`/opt/akeyless/ca-certificates-seed`, `/opt/akeyless/ssl-certs-seed`). Enabling the flag against an older image sets the env var but the image will attempt to write to the read-only rootfs and fail to start.
- **Logging:** logs go to stdout/stderr (collected by the container runtime). File-based logging to the rootfs is not supported in this mode — including the `LOG_FORWARDING` env that would write `~/.akeyless/logand.conf` (skipped when `READ_ONLY_ROOT_FS=true`).
- **Splunk forwarder / file-based log forwarding:** not supported under a read-only rootfs.
- **FIPS:** supported. Under a read-only rootfs the image activates FIPS via `OPENSSL_CONF` and selects the FIPS binary without mutating the rootfs.

## Argo CD Instructions
When deploying the Akeyless Gateway with Argo CD, follow these instructions:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  project: <argocd project>
  source:  
    chart: akeyless-gateway
    repoURL: https://akeylesslabs.github.io/helm-charts
    targetRevision: <chart version>
  ...
  destination:
    name: <k8s destination cluster name>
    namespace: <k8s destination namespace>
  ...
  syncPolicy:
    # automated:
    #   # prune: true
    #   # selfHeal: true
    syncOptions:
    - RespectIgnoreDifferences=true
    - ApplyOutOfSyncOnly=true # optional
    # - CreateNamespace=true # optional
  ignoreDifferences:
  - kind: Secret
    name: <release-name>-cache-secret
    namespace: <k8s destination namespace>
    jsonPointers:
      - /data/cache-pass
  - kind: Secret
    name: <release-name>-cluster-cache-ha
    namespace: <k8s destination namespace>
    jsonPointers:
      - /data/redis-password
  - kind: Secret
    name: <release-name>-cache-encryption-key
    namespace: <k8s destination namespace>
    jsonPointers:
      - /data/cluster-cache-encryption-key
  - kind: Secret
    name: <release-name>-cluster-cache-ha-tls
    namespace: <k8s destination namespace>
    jsonPointers:
      - /data/ca.crt
      - /data/tls.crt
      - /data/tls.key
```

## Changing the password or TLS certificates for Cache HA
After changing the password or TLS certificates for Cache HA, you need to recreate the pods to apply the changes.
```shell
kubectl -n <namespace> get pods -l app=cache-ha -o name | while read pod; do kubectl -n <namespace> delete pod $pod; done
```
