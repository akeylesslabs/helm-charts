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
    readOnlyRootFilesystem:
      enabled: true
```

The feature is **opt-in and default-off**. When disabled, the deployment is unchanged. When enabled, the chart:

- Sets the container `securityContext.readOnlyRootFilesystem: true` (also works alongside `strictSecurityPolicy.enabled`).
- Injects `READ_ONLY_ROOT_FS=true`, which tells the Gateway image to redirect its startup writes to writable volumes.
- Mounts `emptyDir` volumes for the paths the Gateway writes at runtime: `/tmp`, `/run`, `/akeyless/tmp`, `/akeyless/bin`, `/var/run/akeyless`, `/var/log/akeyless`, `/var/log/supervisor`, `/var/akeyless/conf`, `/app`, `/download_center`, `/usr/local/share/ca-certificates`, `/etc/ssl/certs`, and the Gateway config dir.
- On startup, the Gateway image seeds `/usr/local/share/ca-certificates` and `/etc/ssl/certs` from image-baked trust stores so `update-ca-certificates` and the CA Certificate Store work under read-only rootfs.

**Requirements and limitations:**

- **Minimum Gateway image version:** requires a Gateway image that supports `READ_ONLY_ROOT_FS` (image version `5.0.0` or later). CA Certificate Store with full OS trust store support requires an image that includes CA trust-store seed paths (`/opt/akeyless/ca-certificates-seed`, `/opt/akeyless/ssl-certs-seed`). Enabling the flag against an older image sets the env var but the image will attempt to write to the read-only rootfs and fail to start.
- **Logging:** logs go to stdout/stderr (collected by the container runtime). File-based logging to the rootfs is not supported in this mode.
- **Splunk forwarder:** not supported under a read-only rootfs.
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
