# Strict Security Policy for Kyverno/PSA Compliance

## Overview

The `strictSecurityPolicy` toggle enables Kyverno and Pod Security Admission (PSA) `restricted` profile compliance across Akeyless Gateway, Cache, and SRA Web Bastion workloads.

When enabled, the chart enforces:
- **Non-root execution:** `runAsNonRoot: true`, `runAsUser: 1001`
- **Capability drops:** `capabilities.drop: ["ALL"]`
- **No privilege escalation:** `allowPrivilegeEscalation: false`
- **Explicit resource limits:** CPU and memory requests/limits
- **Seccomp profile:** `RuntimeDefault`

## Quick Start

### Enable Strict Security Policy

Add to your `values.yaml`:

```yaml
strictSecurityPolicy:
  enabled: true
```

That's it. The chart will automatically apply hardening to Gateway, Cache, and SRA Web.

### Custom UIDs/Resources

Override defaults if needed:

```yaml
strictSecurityPolicy:
  enabled: true
  uid: 1001        # numeric UID (default: 1001)
  gid: 1001        # numeric GID (default: 1001)
  fsGroup: 1001    # volume ownership GID (default: 1001)
  resources:
    requests:
      cpu: "2"
      memory: "4G"
    limits:
      cpu: "4"
      memory: "8G"
```

## What Gets Hardened

### Gateway

- Pod `securityContext`: `runAsNonRoot`, `runAsUser: 1001`, `fsGroup: 1001`, `seccompProfile: RuntimeDefault`
- Container `securityContext`: `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`
- Resource limits: defaults to 1 CPU / 2G memory requests, 2 CPU / 4G limits (overridable)
- Image: already non-root (`akeyless/gateway` uses UID 1001)

### Cache (Redis)

- Same hardening as Gateway
- Image: `public.ecr.aws/docker/library/redis:8.2.5-alpine` (runs as UID 999 by default; we override to 1001)

### SRA Web Bastion

- Same hardening as Gateway
- Image: `akeyless/zero-trust-bastion:latest` (supports UID 1001 when `REMOTE_ACCESS_TYPE=web`)

### SRA SSH Bastion (Phase A — Interim Hardening)

**The SSH bastion is partially excluded** from full strict hardening because it requires root for per-session chroot/jail operations. Phase A applies:

- **Drop `privileged: true`** (no longer fully privileged)
- **Narrow capabilities:** Only `SYS_ADMIN`, `MKNOD`, `DAC_OVERRIDE`, `CHOWN`, `SETUID`, `SETGID`, `FOWNER` (minimum needed for `mount --bind`, `adduser`, `mknod`)
- **SSH listens on port 2222** inside the container (Service port stays 22)
- **Still runs as root (UID 0)** — documented Kyverno exception required

**Kyverno Exception Required:**

Add this to your Kyverno policy to allow the SSH bastion:

```yaml
apiVersion: kyverno.io/v1
kind: Policy
metadata:
  name: restrict-pod-security
spec:
  rules:
  - name: restricted-profile
    match:
      any:
      - resources:
          kinds:
          - Pod
    exclude:
      any:
      - resources:
          namespaces:
          - akeyless-system  # your namespace
          names:
          - ssh-*  # SSH bastion Deployment pods
```

**Phase B (Future — Separate Epic):**

A follow-up refactor will:
- Replace `mount --bind /dev/pts` with a devpts-less jail
- Replace `adduser`/`deluser` with user-namespace-mapped sessions
- Run sshd as `akeyless` (UID 1001) with only `CAP_NET_BIND_SERVICE`
- Target: `drop ALL`, `add NET_BIND_SERVICE` only, `runAsNonRoot: true`

## Validation

### Verify Rendered Manifests

```bash
helm template my-release akeyless-gateway/ \
  --set strictSecurityPolicy.enabled=true \
  --set globalConfig.gatewayAuth.gatewayAccessId=p-test \
  --set globalConfig.gatewayAuth.gatewayAccessType=access_key \
  --set globalConfig.gatewayAuth.gatewayCredentialsExistingSecret=my-secret \
  | grep -A 10 "securityContext:"
```

Expected output:
- `runAsNonRoot: true`
- `runAsUser: 1001`
- `allowPrivilegeEscalation: false`
- `capabilities: drop: [ALL]` (except SSH bastion)

### Test with Kyverno

Apply your Kyverno policies:

```bash
helm template my-release akeyless-gateway/ \
  --set strictSecurityPolicy.enabled=true \
  --set globalConfig.gatewayAuth.gatewayAccessId=p-test \
  --set globalConfig.gatewayAuth.gatewayAccessType=access_key \
  --set globalConfig.gatewayAuth.gatewayCredentialsExistingSecret=my-secret \
  | kyverno apply your-policy.yaml --resource -
```

### Runtime Validation

After deploying:

```bash
# Check Gateway runs as UID 1001
kubectl exec -it deployment/unified-my-release-akeyless-gateway -- id
# Expected: uid=1001(akeyless) gid=1001(akeyless)

# Check no privileged pods
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].securityContext.privileged}{"\n"}{end}'
# Expected: empty or only ssh-* pods missing (Phase A still needs some caps)

# Check capabilities
kubectl get pods -o json | jq '.items[] | select(.metadata.name | contains("ssh") | not) | .spec.containers[].securityContext.capabilities.drop'
# Expected: ["ALL"] for Gateway, Cache, Web
```

## Secrets Policy

When `strictSecurityPolicy.enabled`, the chart validates that **no plaintext secrets** are passed via `globalConfig.env` or `sra.env`.

If you try:

```yaml
strictSecurityPolicy:
  enabled: true
globalConfig:
  env:
    - name: MY_PASSWORD
      value: "secret123"  # ❌ FAILS
```

You'll get:

```
Error: strictSecurityPolicy.enabled: detected potential secret 'MY_PASSWORD' in globalConfig.env. Use secretKeyRef or existingSecret instead
```

**Correct way:**

```yaml
globalConfig:
  env:
    - name: MY_PASSWORD
      valueFrom:
        secretKeyRef:
          name: my-k8s-secret
          key: password
```

## Compatibility

### Images

- **Gateway:** `akeyless/gateway:*` — already non-root (UID 1001). No rebuild needed.
- **Cache:** `public.ecr.aws/docker/library/redis:8.2.5-alpine` — works with UID 1001 override.
- **SRA Web:** `akeyless/zero-trust-bastion:*` — supports UID 1001 (postgres pre-initialized at build time).
- **SRA SSH:** `akeyless/zero-trust-bastion:*` — Phase A (narrow caps, root UID); Phase B (non-root) TBD.

### Volumes

If you use `fsGroup: 1001`, ensure your PVs support `fsGroup` (most cloud CSI drivers do). Verify with:

```bash
kubectl exec -it deployment/unified-my-release-akeyless-gateway -- ls -ld /path/to/mount
# Expected: drwxrwsr-x ... akeyless 1001 ...
```

### Upgrade Path

Enabling `strictSecurityPolicy` changes:
- Pod UID/GID (0 → 1001)
- Container capabilities (none → drop ALL)
- Resource limits (none → explicit)

**Breaking change:** Existing pods will be recreated. Plan maintenance window.

**Volume ownership:** If you have existing PVs with UID 0 files, you may need to chown at initContainer:

```yaml
gateway:
  deployment:
    initContainers:
      - name: fix-perms
        image: busybox
        command: ['sh', '-c', 'chown -R 1001:1001 /data']
        volumeMounts:
          - name: persistent-storage
            mountPath: /data
```

## Troubleshooting

### Gateway cron not running

**Symptom:** `/usr/bin/restart-poller` cron (15-min interval) doesn't execute.

**Cause:** The gateway base image has `chmod gu+s /usr/sbin/cron` (setgid). When `allowPrivilegeEscalation: false` (which sets `no_new_privs`), the setgid bit is neutralized.

**Fix:** Runtime validation needed. If cron breaks:

1. **Option A:** Add a Kyverno exception for the gateway Deployment allowing `allowPrivilegeEscalation: true` just for cron.
2. **Option B:** Replace cron with supercronic (image already ships it).

**Check:**

```bash
kubectl exec -it deployment/unified-my-release-akeyless-gateway -- sh -c 'crontab -l && tail -20 /var/log/cron.log'
```

### Redis fails to start with "Permission denied"

**Cause:** Alpine Redis image may not honor `runAsUser: 1001` override.

**Fix:** Use Bitnami Redis image which better supports non-root:

```yaml
globalConfig:
  clusterCache:
    image:
      repository: bitnami/redis
      tag: 7.0
```

### SRA Web fails to start postgres

**Symptom:** `pg_ctlcluster 14 portal start` fails.

**Cause:** Postgres cluster not pre-initialized at build time.

**Fix:** Rebuild `akeyless/zero-trust-bastion` image from the updated Dockerfile (includes `pg_createcluster` at build time, ownership transferred to UID 1001).

## docker-compose Parity

For standalone POC deployments, `docker-compose.yaml` mirrors the hardening:

**Gateway & Web:**

```yaml
akeyless-gateway:
  user: "1001:1001"
  security_opt:
    - no-new-privileges:true
  cap_drop:
    - ALL
  mem_limit: 4g
  cpus: "2"
```

**SSH (Phase A):**

```yaml
akeyless-ssh:
  cap_add:
    - SYS_ADMIN
    - MKNOD
    - DAC_OVERRIDE
    - CHOWN
    - SETUID
    - SETGID
    - FOWNER
  security_opt:
    - no-new-privileges:false  # mount needs this
```

## Support

For questions or issues:
- Docs: https://docs.akeyless.io/docs/gateway-chart
- Slack: #akeyless-support
- Jira: ASM-17961 (original hardening epic)
