# Gateway `readOnlyRootFilesystem` — Full Test Plan

## Goal

Verify that Akeyless Gateway can run with Kubernetes `readOnlyRootFilesystem: true` when the chart flag is enabled, and that behavior is unchanged when the flag is off.

## Scope

| Component | What to test |
|---|---|
| Helm chart `akeyless-gateway` | Flag opt-in, volumes, env, securityContext |
| Gateway image | `READ_ONLY_ROOT_FS` redirects writes; FIPS path (optional) |
| Runtime | Pod Ready, health, real EROFS enforcement |
| UI | Login + basic CRUD still works |
| Gateway CA Certificate Store | Add/update/delete certs; bundle sync; log cleanliness |

Out of scope for this plan: Splunk forwarder, file-based logging, `akeyless-api-gateway` (deprecated).

---

## Prerequisites

- Kubernetes cluster (e.g. Docker Desktop)
- Helm 3+
- Image that includes the entrypoint/runner changes, e.g.:

  `akeyless/gateway-staging:5.0.0-readonlyfilesystem-<sha>`

- Docker Hub pull secret in the target namespace (example name: `docker-akeyless-staging`)
- Gateway auth credentials (Access ID + Access Key secret)

### Create pull secret (if missing)

```bash
kubectl apply -f docker-akeyless-staging-secret.yaml
# or:
kubectl create secret docker-registry docker-akeyless-staging \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username='<user>' \
  --docker-password='<pat>' \
  -n default
```

### Create Gateway credentials secret

```bash
kubectl create secret generic gw-creds -n default \
  --from-literal=gateway-access-key='<YOUR_GATEWAY_ACCESS_KEY>'
```

---

## Part A — Install with flag OFF (baseline / BC)

### A1. Install

```bash
helm upgrade --install gw charts/akeyless-gateway -n default \
  --set gateway.deployment.image.repository=akeyless/gateway-staging \
  --set gateway.deployment.image.tag=<IMAGE_TAG> \
  --set gateway.deployment.image.imagePullSecrets=docker-akeyless-staging \
  --set gateway.deployment.readOnlyRootFilesystem.enabled=false \
  --set globalConfig.gatewayAuth.gatewayAccessId='<ACCESS_ID>' \
  --set globalConfig.gatewayAuth.gatewayAccessType=access_key \
  --set globalConfig.gatewayAuth.gatewayCredentialsExistingSecret=gw-creds
```

### A2. Wait for Ready

```bash
kubectl rollout status deploy/unified-gw-akeyless-gateway -n default --timeout=300s
kubectl get pods -n default
```

**Pass:** Gateway pod `1/1 Running`.

### A3. Baseline checks

```bash
POD=$(kubectl get pod -n default -l app.kubernetes.io/name=akeyless-gateway -o name | head -1)

kubectl get pod -n default ${POD#pod/} -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}{"\n"}'
# expect: empty or false

kubectl exec -n default $POD -- sh -c 'echo "READ_ONLY_ROOT_FS=[$READ_ONLY_ROOT_FS]"'
# expect: READ_ONLY_ROOT_FS=[]

kubectl exec -n default $POD -- curl -s -o /dev/null -w "%{http_code}\n" localhost:8080/health
# expect: 200
```

**Pass criteria (flag OFF):**

| Check | Expected |
|---|---|
| Pod Ready | `1/1 Running` |
| `readOnlyRootFilesystem` | absent / `false` |
| `READ_ONLY_ROOT_FS` | unset |
| Health | `200` |
| No new emptyDir mounts for tmp/app/etc. | absent |

---

## Part B — Install / upgrade with flag ON

### B1. Enable the flag

```bash
helm upgrade gw charts/akeyless-gateway -n default --reuse-values \
  --set gateway.deployment.readOnlyRootFilesystem.enabled=true

kubectl rollout status deploy/unified-gw-akeyless-gateway -n default --timeout=300s
```

### B2. Confirm chart rendered correctly

```bash
kubectl get deploy unified-gw-akeyless-gateway -n default -o jsonpath='{.spec.template.spec.containers[0].securityContext}{"\n"}'
# expect: includes "readOnlyRootFilesystem":true

kubectl get deploy unified-gw-akeyless-gateway -n default -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}' | grep READ_ONLY
# expect: READ_ONLY_ROOT_FS=true

kubectl get deploy unified-gw-akeyless-gateway -n default -o jsonpath='{range .spec.template.spec.volumes[*]}{.name}{"\n"}{end}'
# expect includes: tmp, run, akeyless-tmp, akeyless-bin, var-run-akeyless,
#                  var-log-akeyless, var-log-supervisor, var-akeyless-conf, app,
#                  download-center, usr-local-ca-certificates, etc-ssl-certs
```

---

## Part C — Prove it is real read-only mode

> Important: `Permission denied` is **not** proof of read-only rootfs (that can be non-root UID).  
> Real proof is: `Read-only file system` (EROFS).

```bash
POD=$(kubectl get pod -n default -l app.kubernetes.io/name=akeyless-gateway -o name | head -1)
```

### C1. Kubernetes securityContext

```bash
kubectl get pod -n default ${POD#pod/} -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}{"\n"}'
# expect: true
```

### C2. Root filesystem rejects writes

```bash
kubectl exec -n default $POD -- sh -c 'touch /etc/probe; touch /usr/probe; touch /bin/probe'
# expect: Read-only file system
```

### C3. Writable mounts still work

```bash
kubectl exec -n default $POD -- sh -c '
touch /tmp/ok && echo "/tmp writable"
touch /app/ok && echo "/app writable"
touch /var/run/akeyless/ok && echo "/var/run/akeyless writable"
'
# expect: all succeed
```

### C4. Entrypoint redirected writes

```bash
kubectl exec -n default $POD -- ls -la /tmp/passwd /tmp/setupnss /app/akeyless-api-proxy
# expect: all exist
```

### C5. Health

```bash
kubectl exec -n default $POD -- curl -s -o /dev/null -w "%{http_code}\n" localhost:8080/health
# expect: 200
```

### C6. Optional — inspect mounts

```bash
kubectl exec -n default $POD -- sh -c 'mount | grep -E " /tmp | /app | /var/run/akeyless | /var/log/supervisor "'
```

**Pass criteria (flag ON):**

| Check | Expected |
|---|---|
| `securityContext.readOnlyRootFilesystem` | `true` |
| `READ_ONLY_ROOT_FS` | `true` |
| Write to `/etc` or `/usr` | `Read-only file system` |
| Write to `/tmp`, `/app` | succeeds |
| `/tmp/passwd`, `/tmp/setupnss` | exist |
| Health | `200` |

---

## Part D — UI smoke (must not break)

### D1. Port-forward

```bash
kubectl port-forward -n default svc/gw-akeyless-gateway 8000:8000
```

Open:

- Config UI: http://localhost:8000
- Gateway UI: port-forward pod directly if needed (service may not expose 18888)

Login with the same Access ID / Access Key used by the Gateway.

### D2. UI checklist

| # | Action | Pass criteria |
|---|---|---|
| 1 | Login to Gateway UI | Lands on home/dashboard |
| 2 | Open Cluster / Gateway info (or status) | Shows healthy status / version |
| 3 | Open Secrets list | List loads (even if empty) |
| 4 | Create static secret (e.g. `/test/ro-fs-secret`) | Create succeeds; appears in list |
| 5 | Get / view secret value | Value returns correctly |
| 6 | Update the secret | Update succeeds |
| 7 | Delete the secret | Delete succeeds |
| 8 | Open Targets (or Auth Methods) | Page loads |
| 9 | Create a simple target (optional) | Create succeeds |
| 10 | Open Dynamic Secrets / Producers | Page loads without crash |
| 11 | Open Rotated Secrets | Page loads without crash |
| 12 | Open Logs / Audit (if available) | Page loads |
| 13 | Hard refresh browser (Cmd+Shift+R) | UI still works; no broken assets |

### D3. Persistence across restart (optional)

```bash
kubectl delete pod -n default -l app.kubernetes.io/name=akeyless-gateway
kubectl rollout status deploy/unified-gw-akeyless-gateway -n default
```

Re-login and confirm previously created config/secrets still work.

---

## Part E — Flag OFF again (regression / BC)

```bash
helm upgrade gw charts/akeyless-gateway -n default --reuse-values \
  --set gateway.deployment.readOnlyRootFilesystem.enabled=false

kubectl rollout status deploy/unified-gw-akeyless-gateway -n default
```

Re-check:

- UI login still works
- Previously created secret still readable
- `READ_ONLY_ROOT_FS` unset
- `securityContext.readOnlyRootFilesystem` absent / `false`
- Health `200`

---

## Part F — FIPS + read-only (optional follow-up)

```bash
helm upgrade gw charts/akeyless-gateway -n default --reuse-values \
  --set gateway.deployment.readOnlyRootFilesystem.enabled=true \
  --set fipsEnabled=true
```

(Use the chart’s actual FIPS value key if different in your values.)

Verify:

```bash
POD=$(kubectl get pod -n default -l app.kubernetes.io/name=akeyless-gateway -o name | head -1)
kubectl logs -n default ${POD#pod/} | grep -i "FIPS mode enabled"
kubectl exec -n default $POD -- sh -c 'echo OPENSSL_CONF=$OPENSSL_CONF'
# expect: /usr/local/ssl/openssl-fips.cnf
kubectl exec -n default $POD -- curl -s -o /dev/null -w "%{http_code}\n" localhost:8080/health
# expect: 200
kubectl exec -n default $POD -- sh -c 'touch /etc/probe'
# expect: Read-only file system
```

---

## Part G — CA Certificate Store (flag ON)

The **Gateway CA Certificate Store** (Gateway Config → Certificates) lets admins upload custom root/intermediate CAs the Gateway should trust (internal PKI, private endpoints, etc.).

When a cert is added, the Gateway does two things:

1. **Bundle sync** — writes `/tmp/akeyless-gw-ca-cert-store-bundle.pem` (used by Gateway-native TLS, e.g. WinRM).
2. **Linux trust store sync** — writes `/usr/local/share/ca-certificates/*.crt` and runs `update-ca-certificates` to symlink into `/etc/ssl/certs/`.

Under read-only rootfs, the chart mounts writable `emptyDir` volumes at both paths. The Gateway entrypoint seeds them from image-baked copies (`/opt/akeyless/ca-certificates-seed`, `/opt/akeyless/ssl-certs-seed`) on startup, then the normal sync flow runs unchanged.

> **Minimum image:** requires a Gateway image with `READ_ONLY_ROOT_FS` support **and** CA trust-store seed paths in the image.

### G1. Add a test CA via Gateway UI

1. Open Gateway Config UI → **Certificates** (Certificate Store).
2. Add a CA cert (e.g. name `ro-fs-test-ca`) with a valid PEM.
3. Save / apply.

**Pass:** UI reports success; no error toast.

### G2. Verify logs are clean

```bash
POD=$(kubectl get pod -n default -l app.kubernetes.io/name=akeyless-gateway -o name | head -1)

kubectl logs -n default ${POD#pod/} --tail=100 | grep -iE 'read-only|writeCertFile|CaCertificates|ca.cert'
```

**Pass (after fix):** no `read-only file system` errors for `writeCertFile` or `CaCertificates`.

**Fail (before fix):**

```
failed to write ca certificate '<name>': open /usr/local/share/ca-certificates/<name>-*.crt: read-only file system
```

### G3. Verify cert files and bundle inside the pod

```bash
POD=$(kubectl get pod -n default -l app.kubernetes.io/name=akeyless-gateway -o name | head -1)

# Standard CA store path (writable emptyDir, seeded on startup)
kubectl exec -n default $POD -- ls -la /usr/local/share/ca-certificates/

# PEM bundle used by Gateway-native TLS
kubectl exec -n default $POD -- ls -la /tmp/akeyless-gw-ca-cert-store-bundle.pem

# Manifest tracks cert hashes
kubectl exec -n default $POD -- cat /var/akeyless/conf/ca_cert_store_manifest.json

# OS trust store symlink after update-ca-certificates
kubectl exec -n default $POD -- sh -c 'ls /etc/ssl/certs/ | grep -i <cert-name> || true'
```

**Pass:**

| Check | Expected |
|---|---|
| `/usr/local/share/ca-certificates/` | Contains `<name>-*.crt` plus seeded image CAs (e.g. `aws-rds-global-bundle.crt`) |
| `/tmp/akeyless-gw-ca-cert-store-bundle.pem` | Exists, non-empty |
| `ca_cert_store_manifest.json` | Contains entry for cert name |
| `/etc/ssl/certs/` | Contains symlink for gateway-added cert (from `update-ca-certificates`) |

### G4. Update and delete

1. Update the cert PEM in the UI (or change metadata).
2. Confirm logs stay clean and manifest hash changes.
3. Delete the cert from the UI.
4. Confirm cert file removed from `/usr/local/share/ca-certificates/` and bundle updated/removed.

**Pass:** CRUD succeeds; no read-only errors in logs.

### G5. Persistence across pod restart

```bash
kubectl delete pod -n default -l app.kubernetes.io/name=akeyless-gateway
kubectl rollout status deploy/unified-gw-akeyless-gateway -n default --timeout=120s
POD=$(kubectl get pod -n default -l app.kubernetes.io/name=akeyless-gateway -o name | head -1)
kubectl exec -n default $POD -- ls -la /usr/local/share/ca-certificates/
kubectl exec -n default $POD -- ls -la /tmp/akeyless-gw-ca-cert-store-bundle.pem
```

**Pass:** Certs re-synced from Gateway config on startup; files, bundle, and OS symlinks recreated.

### G6. OS trust store (full support)

```bash
POD=$(kubectl get pod -n default -l app.kubernetes.io/name=akeyless-gateway -o name | head -1)

kubectl exec -n default $POD -- sh -c 'ls /etc/ssl/certs/ | grep -i <cert-name>'
```

**Pass:** Symlink exists in `/etc/ssl/certs/` for the gateway-added cert.

### G7. curl inside pod (optional)

```bash
kubectl exec -n default $POD -- curl -s -o /dev/null -w "%{http_code}\n" https://<host-using-custom-ca>
```

**Pass:** TLS succeeds when the host cert chains to a CA in the Certificate Store.

---

## CA Certificate Store — customer expectations (flag ON)

With the chart CA trust-store mounts and a Gateway image that includes seed paths, behavior matches flag OFF.

### What works

| Capability | Notes |
|---|---|
| Add / update / delete CAs in Gateway Config UI or API | Same as flag OFF |
| Gateway-native TLS using custom CAs | PEM bundle + OS trust store |
| WinRM HTTPS validation with custom CA | Uses bundle |
| `update-ca-certificates` / OS trust store | Writable `/etc/ssl/certs` seeded from image on startup |
| `curl` and other OS tools trusting gateway-added CAs | System store is updated |
| Built-in / public CAs | Seeded from image on each pod start |
| Certs survive pod restart | Re-synced from Gateway config on startup |

### One-line customer message

> Read-only mode supports the full Gateway CA Certificate Store, including OS-level trust, when using a Gateway image with CA trust-store seeding and the updated Helm chart.

---

## Final pass / fail summary

**PASS** if all are true:

1. Flag OFF: pod Ready, health 200, no read-only behavior
2. Flag ON: pod Ready, health 200
3. Flag ON: `touch /etc` returns `Read-only file system`
4. Flag ON: `/tmp/passwd` and `/tmp/setupnss` exist
5. UI login + secret CRUD works
6. At least one Targets / Dynamic / Rotated page loads
7. Flag OFF again still works (no regression)
8. CA Certificate Store: add cert succeeds; no `read-only file system` errors in logs
9. CA cert files in `/usr/local/share/ca-certificates/`; bundle in `/tmp`; OS symlink in `/etc/ssl/certs/`
10. Certs re-sync after pod restart

**FAIL** if any of:

- `ImagePullBackOff` / `CrashLoopBackOff`
- Health not `200`
- UI login fails / blank page / spinner hang
- Secret create/get fails
- Write to `/etc` returns only `Permission denied` while claiming read-only mode
- Pod restarts during UI actions
- CA cert add/update produces `read-only file system` errors in logs
- CA cert CRUD fails in UI while flag is ON

---

## Notes

- Helm flag `gateway.deployment.readOnlyRootFilesystem.enabled` is the **user-facing opt-in**.
- Chart sets K8s `securityContext.readOnlyRootFilesystem: true` and injects env `READ_ONLY_ROOT_FS=true`.
- Default is `false` → existing deployments unchanged.
- Do not commit local test values (staging image, pull secret, credentials).
- Splunk / file-based logging are not supported under read-only mode in this iteration.
- **CA Certificate Store:** fully supported when using a Gateway image with trust-store seed paths and chart `usr-local-ca-certificates` / `etc-ssl-certs` mounts.
