# Akeyless Zero Trust Web Access
 

## Introduction
This chart bootstraps a Akeyless-Zero-Trust-Web-Access deployment on a Kubernetes cluster using the Helm package manager.
This chart has been tested to work with [NGINX Ingress](https://kubernetes.github.io/ingress-nginx/) and [cert-manager](https://cert-manager.io/).


## Preparation

### Network
When using Embedded browser session behind load balancer such as ELB, the session can be closed due to **idle connection timeout**, so its advise to increase it
to a reasonable high value, or event unlimited.

e.g when running on AWS with ELB:
https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/config-idle-timeout.html?icmpid=docs_elb_console

## Storage
To be able to download files to your local machine, the helm chart requires a storage class with ReadWriteMany access modes.  
Since a storage class is more environment specific, you will need to provide one before proceeding.
In addition, please provide 1 PersistentVolumes and reference those PVs under `persistence` section in the `values.yaml` file

e.g when running on AWS with EKS:
https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html

For security reason, please limit the PersistentVolumes mount permissions to `0650`, example: 
```mountOptions:
   - dir_mode=0650
   - file_mode=0650
```

### Session Recording (Optional)

ZTWA can capture Firefox web sessions to video files (`.mp4`) and optionally upload them to S3-compatible storage.

#### Prerequisites

1. **Shared Volume**: Configure `persistence.shareStorageVolume` with a `ReadWriteMany` PersistentVolumeClaim (e.g., NFS, Azure Files, EFS) so `/etc/shared` is mounted on both dispatcher and web-worker pods.
2. **Security Context**: The chart automatically sets `securityContext.fsGroup: 10000` on dispatcher and worker pods to allow the non-root `nobody` user (supplementary group `shared` GID 10000) to write recordings and state files. Omitting `fsGroup` commonly yields permission denied errors.
3. **S3 Credentials** (for upload):
   - **Recommended**: Use IAM roles (AWS IRSA, GKE Workload Identity) or inject secrets via `dispatcher.env` with `valueFrom.secretKeyRef`
   - **Not Recommended**: Hardcoding `s3AccessKeyId` and `s3AccessKeySecret` in `values.yaml`

#### Configuration (Recommended: Unified Model)

Use the unified `sessionRecording` section for simplified configuration:

```yaml
sessionRecording:
  # Enable video capture on web-worker pods
  enabled: true
  
  # Recording quality: 144p|240p|360p|480p|720p|1080p (affects file size and CPU)
  quality: "360p"
  
  # S3 upload configuration (dispatcher-side)
  upload:
    enabled: true
    s3Bucket: "my-ztwa-recordings"
    s3Region: "us-east-1"
    # Optional: organize recordings in a prefix
    s3Prefix: "recordings"
    # Optional: custom S3-compatible endpoint (MinIO, Wasabi, etc.)
    s3Endpoint: ""
    # Optional: enable gzip compression before upload (reduces storage costs)
    compress: true
    # Server-side encryption
    sse:
      # type: "" (none), "sse-s3" (AES-256), or "sse-kms"
      type: "sse-s3"
      # kmsKeyId: optional KMS key ARN for sse-kms
      kmsKeyId: ""

persistence:
  shareStorageVolume:
    name: share-storage
    storageClassName: "efs-sc"  # Example: EFS storage class
    accessModes:
      - ReadWriteMany
    size: 10Gi
```

**Credentials**: Use IAM roles or inject via secrets:

```yaml
dispatcher:
  env:
    - name: RECORDING_S3_ACCESS_KEY_ID
      valueFrom:
        secretKeyRef:
          name: s3-credentials
          key: access-key-id
    - name: RECORDING_S3_ACCESS_KEY_SECRET
      valueFrom:
        secretKeyRef:
          name: s3-credentials
          key: secret-access-key
```

#### Advanced Configuration (Per-Service Overrides)

For advanced use cases (e.g., different quality per worker pool, separate S3 buckets), use service-specific overrides. These take precedence over the unified `sessionRecording` section:

```yaml
# Unified config provides defaults
sessionRecording:
  enabled: true
  quality: "360p"
  upload:
    enabled: true
    s3Bucket: "default-bucket"

# Override dispatcher upload settings (takes precedence)
dispatcher:
  config:
    recording:
      enabled: true
      s3Bucket: "high-priority-bucket"
      s3Region: "eu-west-1"
      compress: true

# Override worker capture settings (takes precedence)
webWorker:
  config:
    recording:
      enabled: true
      quality: "720p"  # Higher quality for specific worker pool
```

**Precedence Rules**:
- Dispatcher: `dispatcher.config.recording.*` > `sessionRecording.upload.*` > `dispatcher.env[]`
- Worker: `webWorker.config.recording.*` > `sessionRecording.*` > `webWorker.env[]`

#### Upload Behavior and Limitations

- **Asynchronous Upload**: Recordings are uploaded 60-90+ seconds after session end (60s poll interval + 30s stability check)
- **Worker Capture Format**: Workers write Matroska (`rec_*.mkv`) to the shared volume. The dispatcher remuxes to standard `rec_*.mp4` with `ffmpeg` before S3 upload, so the customer-facing artifact in S3 stays `.mp4`. MKV-on-disk is truncation-resilient: if a worker is terminated mid-session (liveness recycle, eviction, manual restart) the partial bytes already written are still playable, and the dispatcher remuxes whatever it finds.
- **Worker Recycle**: Worker liveness probes terminate inactive sessions (default `webWorker.sessionCleanup.staleGraceSeconds: 30`). The recorder receives `SIGTERM` and flushes; whatever was captured up to that point is retained.
- **Storage**: Ensure shared volume has sufficient capacity for concurrent sessions and upload backlog
- **Retention**: Configure S3 lifecycle policies for long-term retention management

#### Credential Mechanisms (Priority Order)

The dispatcher upload service tries credentials in this order:

1. **Explicit S3 keys**: `sessionRecording.upload.s3AccessKeyId` / `s3AccessKeySecret` (or `dispatcher.config.recording.*`)
2. **AWS Default Credential Chain**: Environment variables, IAM instance profile, IRSA, shared credentials file
3. **Log Forwarding Fallback**: Extracts bucket/region/credentials from `dispatcher.config.logForward` when `target_log_type=aws_s3` and S3 bucket is empty

**Best Practice**: Use option #2 (IAM roles) for production deployments.

#### Troubleshooting

- **Permission Denied on State File**: Ensure `fsGroup: 10000` is set on dispatcher pod (chart default). State file lives at `/etc/shared/upload/recording_uploader_state.json` by default (group-writable).
- **No Recordings Created**: Check `ENABLE_RECORDING=true` on worker pods (`kubectl logs <worker-pod>`). Verify the `session_recorder` service started cleanly (it preflights `/etc/shared` and `/bin/ffmpeg` on boot and fails fast otherwise). Verify the shared volume is mounted at `/etc/shared`.
- **Upload Failures**: Check dispatcher logs for S3 errors. Verify bucket/region/credentials. Test with `aws s3 ls s3://<bucket>` using the same credentials. The dispatcher also remuxes `.mkv` -> `.mp4` before upload; remux failures are logged and the source `.mkv` is retained for retry.
- **Truncated Sessions**: When a worker is recycled mid-session, the recording captured up to `SIGTERM` is uploaded as a valid (shorter) `.mp4`. To extend in-progress sessions, raise `webWorker.sessionCleanup.staleGraceSeconds`.

#### Backward Compatibility

Existing deployments using `dispatcher.config.recording.*` and `webWorker.config.recording.*` continue to function identically. The unified `sessionRecording.*` section is **opt-in** and recommended for new deployments.

### Prerequisites

#### Horizonal Auto-Scaling
Horizontal auto-scaling is based on the HorizonalPodAutoscaler object.  
For it to work properly, Kubernetes metrics server must be installed in the cluster - https://github.com/kubernetes-sigs/metrics-server

To Support auto-scaling for `webWorker` pods based on **busy workers percentage**, please do the following:

Install `Prometheus adapter` - https://github.com/kubernetes-sigs/prometheus-adapter

```bash
helm install --name my-release-name stable/prometheus-adapter
```

Configure the adapter with akeyless custom rule

```bash
prometheus-adapter:
  prometheus:
    url: <prometheus-url>
    port: <prometheus-port>

  rules:
      custom:
        - seriesQuery: 'zero_trust_web_access_workers_stats_busy_workers{namespace!="",pod!="",service!=""}'
          resources:
            overrides:
              namespace:
                resource: namespace
              pod:
                resource: pod
              service:
                resource: service
          name:
            matches: "^(.*)"
            as: "workers_utilization"
          metricsQuery: round(zero_trust_web_access_workers_stats_busy_workers{<<.LabelMatchers>>})
     
```    

## Get Repo Info

```bash
$ helm repo add akeyless https://akeylesslabs.github.io/helm-charts
$ helm repo update
```
See [helm repo](https://helm.sh/docs/helm/helm_repo/) for command documentation.

## Installing the Chart

The `values.yaml` file holds default values, replace the values with the ones from your environment where needed.  

To install the chart run:
```bash
helm install RELEASE_NAME akeyless/akeyless-zero-trust-web-access
``` 

## Parameters

The following table lists the configurable parameters of the Zero Trust Web Access chart and their default values.

### Deployment parameters

| Parameter                                 | Description                                                                                                          | Default                                                      |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `image.imagePullSecrets`                  | List of `{ name: <secret> }` merged into `spec.imagePullSecrets` for every pod (with per-workload lists, deduplicated) | `[]`                                                         |
| `image.dockerRepositoryCreds`             | **Deprecated** — base64 dockerconfig; when set, creates the pre-install secret `akeyless-docker-hub-web-access`, merged with `image.imagePullSecrets`. Prefer pre-created `kubernetes.io/dockerconfigjson` secrets; will be removed in a future version | `nil`                                                        |
| `dispatcher.initContainer.imagePullSecrets` | Extra pull secret refs for the dispatcher init container; merged at the pod (with global and main)                  | `[]`                                                         |
| `dispatcher.initContainer.resources`     | Init container resource requests/limits; defaults match the dispatcher main container                                 | `requests: cpu: 100m, memory: 128Mi; limits: memory: 512Mi` |
| `dispatcher.image.imagePullSecrets`       | Extra pull secret refs for the dispatcher main container; merged at the pod                                         | `[]`                                                         |
| `webWorker.initContainer.imagePullSecrets` | Extra pull secret refs for the web worker init; merged at the pod                                                     | `[]`                                                         |
| `webWorker.initContainer.resources`      | Init resource requests/limits; same dispatcher-style defaults as the web dispatcher (bootstrap is short-lived)        | `requests: cpu: 100m, memory: 128Mi; limits: memory: 512Mi`  |
| `webWorker.image.imagePullSecrets`        | Extra pull secret refs for the web worker main; merged at the pod                                                     | `[]`                                                         |
| `validator.image.imagePullSecrets`         | Extra pull secret refs for the post-install validator Pod; merged with `image.imagePullSecrets`                    | `[]`                                                         |
| `dispatcher.image.repository`             | Zero Trust Web Access Dispatcher image name                                                                          | `akeyless/zero-trust-web-dispatcher`                         |
| `dispatcher.image.tag`                    | Zero Trust Web Access Dispatcher image tag                                                                           | `latest`                                                     |      
| `dispatcher.image.pullPolicy`             | Zero Trust Web Access Dispatcher image pull policy                                                                   | `Always`                                                     |  
| `dispatcher.containerName`                | Zero Trust Web Access Dispatcher container name                                                                      | `web-dispatcher`                                             |    
| `dispatcher.replicaCount`                 | Number of Zero Trust Web Access Dispatcher nodes                                                                     | `1`                                                          |
| `dispatcher.livenessProbe`                | Liveness probe configuration for Zero Trust Web Access Dispatcher                                                    | Check `values.yaml` file                                     |                   
| `dispatcher.readinessProbe`               | Readiness probe configuration for Zero Trust Web Access Dispatcher                                                   | Check `values.yaml` file                                     |         
| `dispatcher.resources.limits`             | The resources limits for Zero Trust Web Access Dispatcher containers (If HPA is enabled these must be set)           | `memory: 512Mi`                                              |
| `dispatcher.resources.requests`           | The requested resources for Zero Trust Web Access Dispatcher containers (If HPA is enabled these must be set)        | `cpu: 100m, memory: 128Mi`                                   |
| `webWorker.image.repository`              | Zero Trust Web Access Web Worker image name                                                                          | `akeyless/zero-trust-web-worker`                             |
| `webWorker.image.tag`                     | Zero Trust Web Access Web Worker image tag                                                                           | `latest`                                                     |      
| `webWorker.image.pullPolicy`              | Zero Trust Web Access Web Worker image pull policy                                                                   | `Always`                                                     |
| `webWorker.containerName`                 | Zero Trust Web Access Web Worker container name                                                                      | `web-worker`                                                 |
| `webWorker.replicaCount`                  | Number of Zero Trust Web Access Web Worker nodes                                                                     | `5`                                                          |
| `webWorker.livenessProbe`                 | Liveness probe configuration for Zero Trust Web Access Web Worker                                                    | Check `values.yaml` file                                     |                   
| `webWorker.readinessProbe`                | Readiness probe configuration for Zero Trust Web Access Web Worker                                                   | Check `values.yaml` file                                     |         
| `webWorker.resources.limits`              | The resources limits for Zero Trust Web Access Web Worker containers (If HPA is enabled these must be set)           | `memory: 2Gi`                                                |
| `webWorker.resources.requests`            | The requested resources for Zero Trust Web Access Web Worker containers (If HPA is enabled these must be set)        | `cpu: 1000m, memory: 1Gi`                                    |

A **Heavy browsing workload** example for the web worker main `resources` is in `values.yaml` as a commented block under `webWorker.resources` (see `akeyless-zero-trust-web-access/values.yaml`).

### Exposure parameters

| Parameter                                 | Description                                                                                                          | Default                                                      |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `dispatcher.service.type`                 | Kubernetes service type                                                                                              | `LoadBalancer`                                               |
| `dispatcher.service.port`                 | Dispatcher service port                                                                                              | `9000`                                                       |
| `dispatcher.service.annotations`          | Dispatcher service extra annotations                                                                                 | `{}`                                                         |
| `webProxy.service.port`                   | Web Proxy service port                                                                                               | `19414`                                                      |
| `webWorker.service.port`                  | Web Worker service port                                                                                              | `5800`                                                       |
| `webWorker.service.annotations`           | Web Worker service extra annotations                                                                                 | `{}`                                                         |
| `dispatcher.ingress.enabled`              | Enable ingress resource                                                                                              | `false`                                                      |
| `dispatcher.ingress.path`                 | Path for the default host                                                                                            | `/`                                                          |
| `dispatcher.ingress.certManager`          | Add annotations for cert-manager                                                                                     | `false`                                                      |
| `dispatcher.ingress.hostname`             | Default host for the ingress resource                                                                                | `aztwa.local`                                                |
| `dispatcher.ingress.annotations`          | Ingress annotations                                                                                                  | `[]`                                                         |
| `dispatcher.ingress.tls`                  | Enable TLS configuration for the hostname defined at `ingress.hostname` parameter                                    | `false`                                                      |
| `dispatcher.ingress.existingSecret`       | Existing secret for the Ingress TLS certificate                                                                      | `nil`                                                        |  
| `httpProxySettings.http_proxy`            | Standard linux HTTP Proxy, should contain the URLs of the proxies for HTTP                                           | `nil`                                                        |  
| `httpProxySettings.https_proxy`           | Standard linux HTTP Proxy, should contain the URLs of the proxies for HTTPS                                          | `nil`                                                        |  
| `httpProxySettings.no_proxy`              | Standard linux HTTP Proxy, should contain a comma-separated list of domain extensions proxy should not be used for   | `nil`                                                        |  

### HPA parameters

| Parameter                                 | Description                                            | Default |
|-------------------------------------------|--------------------------------------------------------|---------|
| `HPA.enabled`                             | Enable Zero Trust Web Access Horizontal Pod Autoscaler | `false` |
| `HPA.dispatcher.minReplicas`              | Dispatcher Minimum desired number of replicas          | `1`     |
| `HPA.dispatcher.maxReplicas`              | Dispatcher Minimum desired number of replicas          | `14`    |
| `HPA.dispatcher.cpuAvgUtil`               | Dispatcher CPU average utilization                     | `50`    |
| `HPA.dispatcher.memAvgUtil`               | Dispatcher Memory average utilization                  | `50`    |
| `HPA.webWorker.busyWorkersPercentage`     | Busy Workers utilization percentage                    | `50`    |

### Zero Trust Web Access configuration parameters

| Parameter                                                            | Description                                                                                                        | Default                    |
|----------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------|----------------------------|
| `dispatcher.config.privilegedAccess.accessID`                        | Access ID with "read" capability for privileged access.                                                            | `nil`                      |
| `dispatcher.config.privilegedAccess.accessKey`                       | Access Key of the provided access ID. (not required on cloud identity)                                             | `nil`                      |
| `dispatcher.config.privilegedAccess.allowedAccessIDs`                | Access will be permitted only to these access IDs. By default, any access ID is accepted.                          | `[]`                       |
| `dispatcher.config.privilegedAccess.existingSecretNames.access`      | Read accessID and accessKey from an existing secret (accessKey value can be left empty when using cloud identity)  | `nil`                      |
| `dispatcher.config.privilegedAccess.existingSecretNames.allowedIDs`  | Read permitted access IDs from an existing secret. By default, any access ID is accepted.                          | `nil`                      |
| `dispatcher.config.privilegedAccess.accessKey`                       | Access Key of the provided access ID. (not required on cloud identity)                                             | `nil`                      |
| `config.listOnlyCredentials.samlAccessID`                            | Non-privileged SAML credentials with "list" only access.                                                           | `nil`                      |
| `dispatcher.config.apiGatewayURL`                                    | API Gateway URL to use to fetch the secrets.                                                                       | `https://rest.akeyless.io` |
| `dispatcher.config.disableSecureCookie`                              | Use browser secure cookie only (HTTPS)                                                                             | `true`                     |
| `webWorker.config.displayWidth`                                      | Web worker display Width (in pixels) of the application's window.                                                  | `2560`                     |
| `webWorker.config.displayHeight`                                     | Web worker display Height (in pixels) of the application's window.                                                 | `1200`                     |
| `dispatcher.config.allowedBastionUrls`                               | List of URLs that will be considered valid for redirection from the Portal back to the bastion                     | `[]`                       |
| `dispatcher.config.allowedProxyUrls`                                 | List of URLs that will be considered valid for redirection from the Portal back to the web proxy service           | `[]`                       |