# Akeyless Gateway

This repository contains the official Akeyless Gateway Helm chart for installing and configuring the Gateway on Kubernetes.

For full documentation on this Helm chart please see the [official docs](https://docs.akeyless.io/docs/gateway-chart)


## Prerequisites

To use the charts here, [Helm](https://helm.sh/) must be configured for your
Kubernetes cluster. Setting up Kubernetes and Helm is outside the scope of
this README. Please refer to the Kubernetes and Helm documentation.

### Horizontal Autoscaling

The Kubernetes [metrics server](https://github.com/kubernetes-sigs/metrics-server) must be configured in your cluster.

### Architecture support (amd64 / arm64)

The Gateway and SRA (`zero-trust-bastion`) images are published as multi-arch
manifests (`linux/amd64` and `linux/arm64`), so the chart runs on both x86_64 and
arm64 nodes (e.g. AWS Graviton) with no changes — Kubernetes pulls the image
variant matching each node's architecture. The chart sets no architecture
`nodeSelector` by default.

On a **mixed-architecture cluster**, pin the Gateway/SRA workloads to a specific
node pool via the existing `nodeSelector` fields, for example:

```yaml
gateway:
  deployment:
    nodeSelector:
      kubernetes.io/arch: arm64
sra:
  webConfig:
    deployment:
      nodeSelector:
        kubernetes.io/arch: arm64
  sshConfig:
    deployment:
      nodeSelector:
        kubernetes.io/arch: arm64
```


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
