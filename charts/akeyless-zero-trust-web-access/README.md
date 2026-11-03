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

> **Single-node and multi-node clusters**
>
> Session recording needs the same `/etc/shared` volume on the dispatcher, the web workers and the media server.
>
> - **Single-node clusters** (k3s, Minikube, kind) can use a node-scoped provisioner such as `local-path`.
> - **Clusters with more than one node** need a ReadWriteMany storage class, for example NFS, AWS EFS, Azure Files, GCP Filestore or Longhorn. The media server runs on every node and mounts the shared volume.
>
> Set the storage class in `persistence.shareStorageVolume.storageClassName`.

### Session Recording (Optional)

ZTWA records browser sessions to video files (`.mp4`) and can upload them to S3 or S3-compatible storage. All recording settings are in the `recording` section of `values.yaml`.

#### Prerequisites

1. **Shared Volume**: Configure `persistence.shareStorageVolume` with a `ReadWriteMany` PersistentVolumeClaim (for example NFS, Azure Files, EFS) so `/etc/shared` is mounted on the dispatcher, the web workers and the media server.
2. **Security Context**: The chart sets `securityContext.fsGroup: 10000` on the dispatcher and worker pods, so they can write to the shared volume. Without it, writes fail with permission denied.
3. **S3 Credentials** (for upload): the chart never accepts plain credentials in `values.yaml`. Choose one of:
   - **IAM roles** (AWS IRSA, GKE Workload Identity), recommended for production. Leave `recording.s3.existingSecretName` empty so the dispatcher picks up the AWS default credential chain.
   - **Kubernetes Secret**: create the Secret out-of-band and reference it in `recording.s3.existingSecretName`. See "Kubernetes Secret" below.

#### Configuration

```yaml
recording:
  # Record sessions on the media server
  enabled: true

  # Upload to S3 (done by the dispatcher)
  s3:
    enabled: true
    bucket: "my-ztwa-recordings"
    region: "us-east-1"
    # Optional: organize recordings in a prefix
    prefix: "recordings"
    # Optional: custom S3-compatible endpoint (MinIO, Wasabi, etc.)
    endpoint: ""
    # Optional: gzip the recordings before upload (reduces storage costs)
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

The render fails when `recording.s3.enabled` is true and `recording.s3.bucket` is empty, and when `recording.enabled` or `recording.s3.enabled` is true without `persistence.shareStorageVolume`.

**Credentials, Kubernetes Secret**: create the Secret out-of-band and reference it from `values.yaml`. The chart wires the dispatcher's `RECORDING_S3_ACCESS_KEY_ID` and `RECORDING_S3_ACCESS_KEY_SECRET` env vars to the Secret via `secretKeyRef`.

```bash
kubectl create secret generic ztwa-s3-credentials \
  --from-literal=access-key-id=<access-key-id> \
  --from-literal=secret-access-key=<secret-access-key>
```

```yaml
recording:
  s3:
    existingSecretName: ztwa-s3-credentials
    # Override the keys inside the Secret if you used different field names:
    # accessKeyIdKey: access-key-id
    # secretAccessKeyKey: secret-access-key
```

**Credentials, IAM roles (no Secret)**: leave `recording.s3.existingSecretName` unset. The dispatcher uses the AWS default credential chain, for example IRSA, an instance profile, or `AWS_*` env vars that `dispatcher.env` reads from a Secret with `valueFrom.secretKeyRef`. A plain `value:` in `dispatcher.env` puts the key in the Deployment spec. Use IAM roles in production, and the Secret when IAM is not available (on-prem, MinIO).

#### Upload Behavior and Limitations

- **Upload time**: a recording is uploaded about 1 to 2 minutes after its session ends.
- **Recording Format**: The media server writes each session as `recordings/rec_*.mp4` on the shared volume, and the dispatcher uploads it as is.
- **Worker Recycle**: When the liveness probe restarts a worker, the media server closes the recording with what it captured up to that point.
- **Storage**: Ensure shared volume has sufficient capacity for concurrent sessions and upload backlog
- **Retention**: Configure S3 lifecycle policies for long-term retention management

#### Troubleshooting

- **Permission Denied**: check that the dispatcher pod has `fsGroup: 10000` (the chart default).
- **No Recordings Created**: Check `recording.enabled`, and that the MediaMTX pod mounts the shared volume. Its log shows a "recording" line per session (`kubectl logs <mediamtx-pod>`).
- **Upload Failures**: Check dispatcher logs for S3 errors. Verify bucket/region/credentials. Test with `aws s3 ls s3://<bucket>` using the same credentials.
- **Truncated Sessions**: When a worker is recycled mid-session, the media server closes the recording with what was captured, and the dispatcher uploads it as a valid, shorter `.mp4`.

### Chromium Worker (chart 4.0.0+)

The web worker runs a Chromium-based browser (`akeyless/zero-trust-web-worker`). Key defaults:

- **Managed policies**: Chrome Enterprise JSON in `webWorker.config.policies`. Use the Chrome schema (`URLAllowlist`, `URLBlocklist` and so on), not the Firefox `policies.json` format.
- **Ephemeral `/config`**: an in-memory `emptyDir`, so no Chromium profile data stays after a pod restart.
- **`/dev/shm`**: a `2Gi` memory-backed `emptyDir`.

#### Upgrading from chart 3.x

1. Rewrite any custom `webWorker.config.policies` from Firefox schema to Chrome Enterprise JSON.
2. Review the worker pod spec changes (`/config` emptyDir, policy mount path) before rollout.
3. Open the live view's network path. Browsers now get the video straight from a media server on each node, over UDP `mediamtx.iceUDPPort` (default `8189`), on top of the dispatcher's port. Allow it from users' networks to every node that runs workers, or to the addresses in `mediamtx.additionalHosts`. There is no TCP fallback. The port is a hostPort, so the cluster's CNI must support hostPort, and two releases in one cluster need different ports. Namespaces under Pod Security `baseline` or `restricted`, and OpenShift's `restricted` SCC, refuse a hostPort, and there the media server does not start. Install into a namespace that allows it.
4. Keep the supported layout: one dispatcher per worker pool, on the same node as its workers.
5. Recording now comes from the media server, out of the live stream:
   - The 4 hour cap is gone. A session is recorded for its full length, in files of up to 24 hours.
   - The live view and the recording fail together.
   - The old recording quality, watchdog and `webWorker.config.recording` settings are removed and ignored.
   - A session hour takes about 0.15 to 0.25 GB, up to 0.9 GB with constant full screen motion. Size the shared volume and the S3 bucket for that.
   - The S3 object is now `rec_<session>_<time>.mp4`, without the worker name. A session longer than 24 hours makes more than one object.
   - Finished recordings wait in `recordings/` on the shared volume. `.mkv` recordings an older worker left on the volume are uploaded as they are.
6. A chart upgrade does not restart the media server, so live sessions survive it. To move a node's media server to the new version, delete its pod while no sessions run on that node.
7. A proxy or ingress in front of the dispatcher must keep the browser's `Host` header. The live routes compare the browser's `Origin` with it, and answer 403 when they differ.
8. Move your values to the 4.0.0 layout, see the next section.

#### Upgrading to the 4.0.0 values layout

Chart 4.0.0 reorders `values.yaml`: the ZTWA settings come first in `config`, then the Kubernetes settings shared by all workloads, then one section per service, then session recording in `recording`. The render fails when it finds a key from the old layout, and the error names the new key.

Upgrade with your values file (`-f <values file>`) or `--reset-then-reuse-values`. With `--reuse-values`, Helm keeps the old release values in place of the new chart defaults, and the render fails with a nil pointer error.

| Old key | New key |
|---------|---------|
| `dispatcher.config.apiGatewayURL`, `apiGatewayCert`, `clusterName`, `allowedBastionUrls`, `allowedProxyUrls`, `allowedInternalAuth`, `disableSecureCookie` | The same names under `config` |
| `dispatcher.config.privilegedAccess.accessID` | `config.privilegedAccess.accessID` |
| `dispatcher.config.privilegedAccess.accessKey` | Removed. Put the key in the Secret named in `config.privilegedAccess.existingSecretNames.access`, with the keys `accessID` and `accessKey` |
| `dispatcher.config.privilegedAccess.allowedAccessIDs` | `config.privilegedAccess.authorizedAccessIDs`, now required |
| `dispatcher.config.privilegedAccess.existingSecretNames.access` | `config.privilegedAccess.existingSecretNames.access` |
| `dispatcher.config.privilegedAccess.existingSecretNames.allowedIDs` | `config.privilegedAccess.existingSecretNames.authorizedAccessIDs`. The key inside the Secret stays `allowedAccessIDs` |
| `dispatcher.config.cloudIdentity.type` | `config.privilegedAccess.accessType` |
| `dispatcher.config.logForward`, `dispatcher.config.existingLogForwardSecretName` | Removed. Set the recording upload in `recording.s3` |
| `dispatcher.config.recording` (`enabled`, `s3Bucket`, `s3Region`, `s3Prefix`, `s3Endpoint`, `compress`, `sseType`, `sseKmsKeyId`) | `recording.s3` (`enabled`, `bucket`, `region`, `prefix`, `endpoint`, `compress`, `sse.type`, `sse.kmsKeyId`) |
| `dispatcher.config.listOnlyCredentials` | Removed |
| `sessionRecording.enabled` | `recording.enabled` |
| `sessionRecording.quality`, `sessionRecording.watchdog` | Removed. The media server records the full screen |
| `sessionRecording.upload.enabled` | `recording.s3.enabled` |
| `sessionRecording.upload.s3Bucket`, `s3Region`, `s3Prefix`, `s3Endpoint` | `recording.s3.bucket`, `region`, `prefix`, `endpoint` |
| `sessionRecording.upload.existingSecretNames.s3` | `recording.s3.existingSecretName` |
| `sessionRecording.upload.existingSecretNames.s3AccessKeyIdKey`, `s3SecretAccessKeyKey` | `recording.s3.accessKeyIdKey`, `secretAccessKeyKey` |
| `sessionRecording.upload.compress`, `sse.type`, `sse.kmsKeyId` | `recording.s3.compress`, `sse.type`, `sse.kmsKeyId` |
| `sessionRecording.upload.uploaderStatePath`, `dispatcher.config.recording.uploaderStatePath` | Removed |
| `dlp` | Removed |
| `webWorker.config.dispatcherDNS` | `dispatcher.dispatcherDNS` |
| `HPA.webWorker.sessionTerminationGracePeriodSeconds` | `webWorker.terminationGracePeriodSeconds` |
| `HPA.dispatcher` | Removed. The chart runs one dispatcher per worker pool |

When a field was set in both `sessionRecording.upload` and `dispatcher.config.recording`, keep the `dispatcher.config.recording` value. The old chart used that one.

The render also fails when:

- `config.privilegedAccess.authorizedAccessIDs` and `config.privilegedAccess.existingSecretNames.authorizedAccessIDs` are both empty, and `ALLOWED_ACCESS_IDS` is not set in both `dispatcher.env` and `webProxy.env`. The dispatcher and the web proxy accept no user without them.
- `config.privilegedAccess.accessType` is `access_key` and `config.privilegedAccess.existingSecretNames.access` is not set.
- `config.privilegedAccess.accessType` is `aws_iam`, `azure_ad` or `gcp` and `config.privilegedAccess.existingSecretNames.access` is set.

### Privileged Access Type (`config.privilegedAccess.accessType`)

The dispatcher reads the secrets of the web targets with the privileged access ID. `accessType` sets the type of its auth method:

- `""` (default): auto detect, from `existingSecretNames.access` or from the instance metadata service (IMDS).
- `access_key`: [API key](https://docs.akeyless.io/docs/auth-with-api-key). Needs `existingSecretNames.access`, a Secret with the keys `accessID` and `accessKey`.
- `aws_iam`, `azure_ad`, `gcp`: cloud identity ([AWS IAM](https://docs.akeyless.io/docs/auth-with-aws), [Azure AD](https://docs.akeyless.io/docs/auth-with-azure), [GCP](https://docs.akeyless.io/docs/auth-with-gcp)). Set `accessID`, not `existingSecretNames.access`.

Set a cloud type when the dispatcher cannot reach IMDS at `169.254.169.254`. Without it, sessions exit with `unknown-cloud-provider`. Common causes:

- EKS with the IMDSv2 hop limit `1`, the AWS default. See the [AWS IAM guide](https://docs.akeyless.io/docs/auth-with-aws#aws-instance-metadata-service).
- An egress `NetworkPolicy` that denies the link-local subnet.
- Non-cloud Kubernetes (on-prem k3s, kind, bare metal).

```yaml
config:
  privilegedAccess:
    accessID: "<AWS_IAM_ACCESS_ID>"
    accessType: "aws_iam"   # or "azure_ad" / "gcp"
    authorizedAccessIDs:
      - "<USER_ACCESS_ID>"
```

API key:

```bash
kubectl create secret generic ztwa-privileged-access \
  --from-literal=accessID=<ACCESS_ID> \
  --from-file=accessKey=./access-key
```

```yaml
config:
  privilegedAccess:
    accessType: "access_key"
    existingSecretNames:
      access: ztwa-privileged-access
    authorizedAccessIDs:
      - "<USER_ACCESS_ID>"
```

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

## Parameters

The following table lists the configurable parameters of the Zero Trust Web Access chart and their default values.

### Deployment parameters

| Parameter                                 | Description                                                                                                          | Default                                                      |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `image.imagePullSecrets`                  | List of `{ name: <secret> }` merged into `spec.imagePullSecrets` for every pod (with per-workload lists, deduplicated) | `[]`                                                         |
| `image.dockerRepositoryCreds`             | **Deprecated**, use `image.imagePullSecrets`. Base64 dockerconfig for the Akeyless registry                           | `nil`                                                        |
| `dispatcher.initContainer.imagePullSecrets` | Extra pull secret refs for the dispatcher init container; merged at the pod (with global and main)                  | `[]`                                                         |
| `dispatcher.initContainer.resources`     | Init container resource requests/limits; defaults match the dispatcher main container                                 | `requests: cpu: 100m, memory: 128Mi, limits: memory: 512Mi` |
| `dispatcher.image.imagePullSecrets`       | Extra pull secret refs for the dispatcher main container; merged at the pod                                         | `[]`                                                         |
| `webWorker.initContainer.imagePullSecrets` | Extra pull secret refs for the web worker init; merged at the pod                                                     | `[]`                                                         |
| `webWorker.initContainer.resources`      | Init container resource requests/limits                                                                               | `requests: cpu: 100m, memory: 128Mi, limits: memory: 512Mi`  |
| `webWorker.image.imagePullSecrets`        | Extra pull secret refs for the web worker main; merged at the pod                                                     | `[]`                                                         |
| `validator.image.imagePullSecrets`         | Extra pull secret refs for the post-install validator Pod; merged with `image.imagePullSecrets`                    | `[]`                                                         |
| `dispatcher.image.repository`             | Zero Trust Web Access Dispatcher image name                                                                          | `akeyless/zero-trust-web-dispatcher`                         |
| `dispatcher.image.tag`                    | Zero Trust Web Access Dispatcher image tag                                                                           | `latest`                                                     |      
| `dispatcher.image.pullPolicy`             | Zero Trust Web Access Dispatcher image pull policy                                                                   | `Always`                                                     |  
| `dispatcher.containerName`                | Zero Trust Web Access Dispatcher container name                                                                      | `web-dispatcher`                                             |    
| `dispatcher.replicaCount`                 | Number of dispatchers. Must be `1`, one dispatcher per worker pool                                                                     | `1`                                                          |
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
| `webProxy.image.repository`               | Zero Trust Web Access Proxy image name                                                                              | `akeyless/zero-trust-web-proxy`                              |
| `webProxy.image.tag`                      | Zero Trust Web Access Proxy image tag (defaults to the chart `appVersion`)                                          | `nil`                                                        |
| `webProxy.image.pullPolicy`               | Zero Trust Web Access Proxy image pull policy                                                                       | `Always`                                                     |
| `webProxy.image.imagePullSecrets`         | Extra pull secret refs for the web proxy main container; merged at the pod                                         | `[]`                                                         |
| `webProxy.initContainer.imagePullSecrets` | Extra pull secret refs for the web proxy init container; merged at the pod                                         | `[]`                                                         |
| `webProxy.initContainer.resources`        | Init container resource requests/limits                                                                            | `requests: cpu: 100m, memory: 128Mi, limits: memory: 512Mi` |
| `webProxy.containerName`                  | Zero Trust Web Access Proxy container name                                                                          | `web-proxy`                                                  |
| `webProxy.replicaCount`                   | Number of Zero Trust Web Access Proxy nodes (unset → inherits `dispatcher.replicaCount`)                            | `nil`                                                        |
| `webProxy.env`                            | Extra env for the proxy container (e.g. `WEB_PROXY_TYPE: SOCKS`)                                                    | `[]`                                                         |
| `webProxy.livenessProbe`                  | Liveness probe configuration for Zero Trust Web Access Proxy                                                        | Check `values.yaml` file                                     |
| `webProxy.readinessProbe`                 | Readiness probe configuration for Zero Trust Web Access Proxy                                                       | Check `values.yaml` file                                     |
| `webProxy.resources.limits`               | The resources limits for Zero Trust Web Access Proxy containers                                                    | `memory: 1Gi`                                                |
| `webProxy.resources.requests`             | The requested resources for Zero Trust Web Access Proxy containers                                                 | `cpu: 500m, memory: 512Mi`                                   |

A **Heavy browsing workload** example for the web worker main `resources` is in `values.yaml` as a commented block under `webWorker.resources` (see `akeyless-zero-trust-web-access/values.yaml`).

### Exposure parameters

| Parameter                                 | Description                                                                                                          | Default                                                      |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `dispatcher.service.type`                 | Kubernetes service type                                                                                              | `LoadBalancer`                                               |
| `dispatcher.service.port`                 | Dispatcher service port                                                                                              | `9000`                                                       |
| `dispatcher.service.annotations`          | Dispatcher service extra annotations                                                                                 | `{}`                                                         |
| `webProxy.service.type`                   | Web Proxy Kubernetes service type (portable external exposure; override to NodePort/ClusterIP)                       | `LoadBalancer`                                               |
| `webProxy.service.port`                   | Web Proxy service port                                                                                               | `19414`                                                      |
| `webProxy.service.annotations`            | Web Proxy service extra annotations                                                                                  | `{}`                                                         |
| `webProxy.ingress.enabled`                | Enable the optional Gateway API `TCPRoute` for the proxy (L4; requires a Gateway API controller)                     | `false`                                                      |
| `webProxy.ingress.parentGateway`          | Name of the pre-existing Gateway (TCP listener) the `TCPRoute` attaches to                                           | `""`                                                         |
| `webProxy.ingress.sectionName`            | Listener name on the parent Gateway (required by most controllers when it has multiple listeners)                    | `""`                                                         |
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
| `HPA.webWorker.busyWorkersPercentage`     | Busy Workers utilization percentage                    | `50`    |
| `HPA.webWorker.minReplicas`               | Minimum number of web workers                          | `3`     |
| `HPA.webWorker.maxReplicas`               | Maximum number of web workers                          | `14`    |

### Zero Trust Web Access configuration parameters

| Parameter                                                              | Description                                                                                                         | Default                   |
|------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------|---------------------------|
| `config.apiGatewayURL`                                                 | Akeyless API URL. Keep the default for the Akeyless SaaS, or set the API URL of your Akeyless Gateway               | `https://api.akeyless.io` |
| `config.apiGatewayCert.tlsCertsSecretName`                             | Existing Secret with the Gateway TLS certificate in the key `tls.crt`                                               | `nil`                     |
| `config.clusterName`                                                   | ZTWA cluster name. A change to it, or to the privileged access ID, registers a new bastion                          | `defaultCluster`          |
| `config.privilegedAccess.accessID`                                     | Access ID with "Read" and "List" permissions on the target secrets. Ignored when `existingSecretNames.access` is set | `""`                      |
| `config.privilegedAccess.accessType`                                   | `""` (auto detect), `access_key`, `aws_iam`, `azure_ad` or `gcp`                                                    | `""`                      |
| `config.privilegedAccess.existingSecretNames.access`                   | Existing Secret with the keys `accessID` and `accessKey`. Required for `access_key`, not allowed with a cloud type  | `nil`                     |
| `config.privilegedAccess.existingSecretNames.authorizedAccessIDs`      | Existing Secret with the key `allowedAccessIDs`, a comma separated list. Replaces `authorizedAccessIDs`              | `nil`                     |
| `config.privilegedAccess.authorizedAccessIDs`                          | Access IDs of the users that can open ZTWA sessions. Required when the Secret above is not set                      | `[]`                      |
| `config.allowedBastionUrls`                                            | External URLs of the dispatcher (port 9000 or the ingress host). The Portal redirects users back only to these URLs | `[]`                      |
| `config.allowedProxyUrls`                                              | External URLs of the web proxy Service (port 19414). The Portal redirects users back only to these URLs             | `[]`                      |
| `config.allowedInternalAuth`                                           | When `false`, the dispatcher accepts only requests with preemptive JWT auth                                         | `"false"`                 |
| `config.disableSecureCookie`                                           | When `false`, the browser sends the dispatcher session cookie only over HTTPS                                       | `"true"`                  |
| `dispatcher.dispatcherDNS`                                             | Host name the dispatcher serves inside its pod. Keep the default                                                    | `rbi.dispatcher`          |
| `webWorker.config.displayWidth`                                        | Web worker display Width (in pixels) of the application's window.                                                   | `2560`                    |
| `webWorker.config.displayHeight`                                       | Web worker display Height (in pixels) of the application's window.                                                  | `1200`                    |
| `webWorker.config.policies`                                            | Chromium managed policies, as Chrome Enterprise JSON                                                                | Check `values.yaml` file  |
| `webWorker.terminationGracePeriodSeconds`                              | Time a worker pod gets to finish its live session before Kubernetes stops it                                        | `3600`                    |

### Session recording parameters

| Parameter                         | Description                                                                                | Default             |
|-----------------------------------|--------------------------------------------------------------------------------------------|---------------------|
| `recording.enabled`               | Record sessions on the media server. Needs `persistence.shareStorageVolume`                | `false`             |
| `recording.s3.enabled`            | Upload the recordings to S3, done by the dispatcher                                        | `false`             |
| `recording.s3.bucket`             | Bucket name. Required when `recording.s3.enabled` is true                                  | `""`                |
| `recording.s3.region`             | Bucket region                                                                              | `""`                |
| `recording.s3.prefix`             | Prefix for the uploaded objects                                                            | `""`                |
| `recording.s3.endpoint`           | Endpoint of an S3-compatible service. Empty for AWS S3                                     | `""`                |
| `recording.s3.existingSecretName` | Existing Secret with the S3 credential pair. Empty uses the AWS default credential chain   | `""`                |
| `recording.s3.accessKeyIdKey`     | Key of the access key ID in that Secret                                                    | `access-key-id`     |
| `recording.s3.secretAccessKeyKey` | Key of the secret access key in that Secret                                                | `secret-access-key` |
| `recording.s3.compress`           | Gzip the recordings before upload                                                          | `false`             |
| `recording.s3.sse.type`           | Server-side encryption: `""` (none), `sse-s3` or `sse-kms`                                 | `""`                |
| `recording.s3.sse.kmsKeyId`       | KMS key ID or ARN for `sse-kms`                                                            | `""`                |
