# Local Staging Gateway Install (Docker Desktop / kind)

How to install a **staging Gateway image** into a local Kubernetes cluster for feature testing.

Do **not** commit local staging overrides, pull secrets, or credentials.

---

## 1. What to change in `values.yaml`

Edit only these fields under `gateway.deployment` (and auth under `globalConfig` if you prefer values over `--set`):

```yaml
gateway:
  deployment:
    image:
      ## Staging repo (not akeyless/gateway)
      repository: akeyless/gateway-staging
      ## Replace with the tag you built / CI published
      tag: <STAGING_TAG>
      pullPolicy: IfNotPresent
      ## Must match the K8s docker-registry secret name
      imagePullSecrets: docker-akeyless-staging

    ## Optional feature flags for the test
    # readOnlyRootFilesystem:
    #   enabled: true

globalConfig:
  gatewayAuth:
    gatewayAccessId: <ACCESS_ID>          # e.g. p-xxxx
    gatewayAccessType: access_key         # MUST be the type string, NOT the key
    gatewayCredentialsExistingSecret: gw-creds
  ## Optional: make this Access ID a Gateway admin in the UI
  allowedAccessPermissions:
    - name: admin
      access_id: <ACCESS_ID>
```

### Common mistakes

| Wrong | Right |
|---|---|
| `repository: akeyless/staginig` / `akeyless/staging` | `akeyless/gateway-staging` |
| `gatewayAccessType: <access-key-value>` | `gatewayAccessType: access_key` |
| Missing `imagePullSecrets` | `docker-akeyless-staging` |
| Secret key named wrong | Secret must have key `gateway-access-key` |

### Verify the image exists before install

```bash
docker pull akeyless/gateway-staging:<STAGING_TAG>
```

---

## 2. One-time cluster setup

### 2.1 Pull secret (Docker Hub staging)

If the secret file exists:

```bash
kubectl apply -f docker-akeyless-staging-secret.yaml
```

Or create it manually:

```bash
kubectl create secret docker-registry docker-akeyless-staging \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username='<DOCKER_USER>' \
  --docker-password='<DOCKER_PAT>' \
  -n default
```

### 2.2 Gateway credentials secret

```bash
kubectl create secret generic gw-creds -n default \
  --from-literal=gateway-access-key='<ACCESS_KEY>'
```

If it already exists and you need to update the key:

```bash
kubectl create secret generic gw-creds -n default \
  --from-literal=gateway-access-key='<ACCESS_KEY>' \
  --dry-run=client -o yaml | kubectl apply -f -
```

---

## 3. Install / upgrade commands

From the `helm-charts` repo root:

### Fresh install

```bash
helm upgrade --install gw charts/akeyless-gateway -n default \
  --set gateway.deployment.image.repository=akeyless/gateway-staging \
  --set gateway.deployment.image.tag=<STAGING_TAG> \
  --set gateway.deployment.image.imagePullSecrets=docker-akeyless-staging \
  --set globalConfig.gatewayAuth.gatewayAccessId=<ACCESS_ID> \
  --set globalConfig.gatewayAuth.gatewayAccessType=access_key \
  --set globalConfig.gatewayAuth.gatewayCredentialsExistingSecret=gw-creds \
  --set 'globalConfig.allowedAccessPermissions[0].name=admin' \
  --set 'globalConfig.allowedAccessPermissions[0].access_id=<ACCESS_ID>'
```

### Upgrade only the image tag (keep other values)

```bash
helm upgrade gw charts/akeyless-gateway -n default --reuse-values \
  --set gateway.deployment.image.tag=<NEW_STAGING_TAG>
```

### Enable a feature flag (example: read-only rootfs)

```bash
helm upgrade gw charts/akeyless-gateway -n default --reuse-values \
  --set gateway.deployment.readOnlyRootFilesystem.enabled=true
```

---

## 4. Wait and verify

```bash
kubectl rollout status deploy/unified-gw-akeyless-gateway -n default --timeout=300s
kubectl get pods -n default
kubectl get svc -n default
```

### Names to remember

| Resource | Name pattern |
|---|---|
| Helm release | `gw` |
| Deployment | `unified-gw-akeyless-gateway` |
| UI / config Service | `gw-akeyless-gateway` |
| Internal API Service | `gw-akeyless-gateway-internal` |
| Cache | `gw-akeyless-gateway-cache-svc` |

### Health check

```bash
POD=$(kubectl get pod -n default -l app.kubernetes.io/name=akeyless-gateway -o name | head -1)
kubectl exec -n default $POD -- curl -s -o /dev/null -w "%{http_code}\n" localhost:8080/health
# expect: 200
```

### Open UI

```bash
kubectl port-forward -n default svc/gw-akeyless-gateway 8000:8000
```

Open: http://localhost:8000

Login with the same Access ID / Access Key used by the Gateway.

---

## 5. Everyday `k` (kubectl) commands

If you use the alias:

```bash
alias k=kubectl
```

All examples below use `k` and namespace `default`.

### Cluster / context

```bash
k config current-context
k config get-contexts
k cluster-info
k get nodes
k get ns
```

### See everything for this Gateway release

```bash
k get all -n default
k get pods -n default
k get pods -n default -o wide
k get deploy,sts,ds -n default
k get svc -n default
k get secret -n default
k get pvc -n default
k get events -n default --sort-by=.lastTimestamp | tail -30
```

### Gateway-specific selectors

```bash
# Gateway pods
k get pods -n default -l app.kubernetes.io/name=akeyless-gateway

# Cache pods
k get pods -n default -l component=cache

# One-liner: set POD
POD=$(k get pod -n default -l app.kubernetes.io/name=akeyless-gateway -o name | head -1)
echo $POD
```

### Describe / logs / exec

```bash
k describe pod -n default -l app.kubernetes.io/name=akeyless-gateway
k describe deploy unified-gw-akeyless-gateway -n default
k describe svc gw-akeyless-gateway -n default

k logs -n default deploy/unified-gw-akeyless-gateway --tail=100
k logs -n default deploy/unified-gw-akeyless-gateway -f
k logs -n default $POD --previous   # previous crashed container

k exec -n default $POD -- sh
k exec -n default $POD -- curl -s localhost:8080/health
```

### Scale

```bash
# Scale Gateway to 2 replicas
k scale deploy unified-gw-akeyless-gateway -n default --replicas=2

# Scale back to 1
k scale deploy unified-gw-akeyless-gateway -n default --replicas=1

# Scale to 0 (stop Gateway, keep release)
k scale deploy unified-gw-akeyless-gateway -n default --replicas=0
```

### Restart / delete pods (recreate)

```bash
# Soft restart (rollout restart)
k rollout restart deploy/unified-gw-akeyless-gateway -n default
k rollout status deploy/unified-gw-akeyless-gateway -n default

# Delete pod (Deployment recreates it)
k delete pod -n default -l app.kubernetes.io/name=akeyless-gateway

# Delete a specific pod
k delete pod -n default <pod-name>

# Force delete stuck pod
k delete pod -n default <pod-name> --force --grace-period=0
```

### Delete resources

```bash
# Delete only the Gateway deployment pods via scale-down (keeps Helm release)
k scale deploy unified-gw-akeyless-gateway -n default --replicas=0

# Delete a service (usually don't; Helm owns it)
k delete svc gw-akeyless-gateway -n default

# Delete secrets used for local testing
k delete secret gw-creds docker-akeyless-staging -n default --ignore-not-found

# Full uninstall of the Helm release (preferred cleanup)
helm uninstall gw -n default

# Nuclear: delete everything with the release label (careful)
k delete all -n default -l app.kubernetes.io/instance=gw
```

### Port-forward / UI

```bash
k port-forward -n default svc/gw-akeyless-gateway 8000:8000
# UI: http://localhost:8000

# Or forward pod ports directly
k port-forward -n default $POD 8000:8000 8080:8080 18888:18888
```

### Image / auth quick checks

```bash
k get deploy unified-gw-akeyless-gateway -n default -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'

k get deploy unified-gw-akeyless-gateway -n default \
  -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}' \
  | grep -iE 'GATEWAY_ACCESS|ALLOWED|READ_ONLY'

k describe pod -n default -l app.kubernetes.io/name=akeyless-gateway | grep -iE 'Image:|Failed|Back-off|pull'
```

---

## 6. Useful debug commands

```bash
# Image + pull errors
kubectl describe pod -n default -l app.kubernetes.io/name=akeyless-gateway | grep -iE 'Image:|Failed|Back-off|pull'

# Auth-related env
kubectl get deploy unified-gw-akeyless-gateway -n default \
  -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}' \
  | grep -iE 'GATEWAY_ACCESS|ALLOWED|READ_ONLY'

# Recent Gateway errors
kubectl logs -n default deploy/unified-gw-akeyless-gateway --tail=100 | grep -iE 'error|admin|invalid|ImagePull'

# Current helm values
helm get values gw -n default
```

### If UI shows "Cluster Admin is invalid"

Usually auth misconfig:

1. `gatewayAccessType` must be `access_key` (not the key value)
2. Secret `gw-creds` must contain key `gateway-access-key`
3. Prefer setting `allowedAccessPermissions` for that Access ID

Then:

```bash
helm upgrade gw charts/akeyless-gateway -n default --reuse-values \
  --set globalConfig.gatewayAuth.gatewayAccessType=access_key \
  --set globalConfig.gatewayAuth.gatewayCredentialsExistingSecret=gw-creds \
  --set 'globalConfig.allowedAccessPermissions[0].name=admin' \
  --set 'globalConfig.allowedAccessPermissions[0].access_id=<ACCESS_ID>'
```

---

## 7. Cleanup

```bash
helm uninstall gw -n default
k delete secret gw-creds docker-akeyless-staging -n default --ignore-not-found
```

---

## 8. Checklist for each new staging feature test

1. Build / publish staging image → note the exact tag
2. `docker pull akeyless/gateway-staging:<TAG>` succeeds
3. Update `tag` in values (or pass `--set ...tag=`)
4. Ensure pull secret + `gw-creds` exist
5. `helm upgrade --install ...`
6. Wait for Ready + health `200`
7. Port-forward UI and verify the feature
8. Revert local `values.yaml` changes before committing
