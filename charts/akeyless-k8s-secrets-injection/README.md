# Akeyless Kubernetes Secrets Injection

This chart will install a mutating admission webhook, that injects an executable to containers in pods which than can request secrets from Akeyless Vault through environment variable definitions or local file on the container.
This chart has been tested to work with Kubernetes version 1.16, and above. 

## Before you start

Before you install this chart you must create a namespace for it, this is due to the order in which the resources in the charts are applied (Helm collects all of the resources in a given Chart and it's dependencies, groups them by resource type, and then installs them in a predefined order (see [here](https://github.com/helm/helm/blob/master/pkg/releaseutil/kind_sorter.go#L31)).

The `MutatingWebhookConfiguration` gets created before the actual backend Pod which serves as the webhook itself, Kubernetes would like to mutate that pod as well, but it is not ready to mutate yet (infinite recursion in logic).

### Creating the namespace

The default `namespaceSelector` uses the `kubernetes.io/metadata.name` label, which Kubernetes (1.21+) automatically applies to all namespaces. No manual labeling is required.

set the target namespace name or skip for the default name: vswh

```bash
export WEBHOOK_NS=`<namespace>`
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
helm install RELEASE_NAME akeyless/akeyless-secrets-injection --namespace "${WEBHOOK_NS}"
``` 

## Deleting the Chart
```bash
helm delete RELEASE_NAME --namespace "${WEBHOOK_NS}"
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

## Configuration

### OAuth2 / JWT authentication

Requires injector **≥ the JWT release** (image supporting `AKEYLESS_ACCESS_TYPE=jwt`).
0.39.0 exits on `jwt`.

For `AKEYLESS_ACCESS_TYPE: jwt` (alias `oauth2`), `jwtProjectedToken.enabled` is
**required**. Do not put a static JWT in `env`, and do not point
`AKEYLESS_JWT_FILE` at the automounted kube API token.

```yaml
env:
  AKEYLESS_ACCESS_TYPE: jwt
  AKEYLESS_ACCESS_ID: "<oauth2/jwt auth-method access id>"
  # Optional: set only to force Gateway routing.
  # AKEYLESS_API_GW_URL: "https://your-gateway.example"

jwtProjectedToken:
  enabled: true
  audience: akeyless.io   # must match the auth method --audience
```

**Auth method / authorization scoping**

1. Sync cluster JWKS / issuer into an oauth2 auth method (`--jwks-json-file` /
   `--jwks-uri`, `--issuer`, `--unique-identifier sub`, `--audience`, prefer
   `--force-sub-claims`).
2. Associate roles with **sub-claims**, not a shared claim, e.g.
   `akeyless assoc-role-am --role-name <role> --am-name <am> \
     --sub-claims sub=system:serviceaccount:<ns>:<sa>`
   Namespace-wide: `sub=system:serviceaccount:<ns>:*`.
3. Without `--force-sub-claims` / sub-claims, every ServiceAccount that can mint
   a projected token for this audience inherits the role.
4. The webhook ServiceAccount also authenticates (registry creds, restart
   rollout, cert events) and needs its own association, limited to those paths.
5. `jwtProjectedToken.expirationSeconds` applies only to the webhook Deployment
   (min 600). Workload projected tokens use 3600s.

### Registry credential secrets (BREAKING)

Image entrypoint lookup requires each registry-cred secret JSON to include
`"registry": "<image host>"` (use `docker.io` for Docker Hub; include non-default ports).
Optional: `AKEYLESS_REGISTRY_CREDS_PATH_TEMPLATE=/registry/{namespace}/` to scope
`akeyless/registry_creds` annotations, or `AKEYLESS_DISABLE_REGISTRY_CREDS_ANNOTATION=enable`.

### Admission auth (SEC-001)

Chart render **fails** unless one of these is set (the injector binary also
fail-closes without `WEBHOOK_ADMISSION_TOKEN_FILE` or an explicit allow):

1. `admissionAuth.enabled=true`, or
2. `networkPolicy.enabled=true` with nonempty `allowedCIDRs`, or
3. `admissionAuth.allowUnauthenticated=true` (explicit insecure escape).

`env` values are quoted by the chart. Use plain booleans via `--set`
(`--set admissionAuth.require=true`); remove any extra quotes from older workarounds.

**Self-managed clusters**

```yaml
admissionAuth:
  enabled: true
  require: false          # stage 1: mount Secret, do not enforce yet
  existingSecret: ""      # prefer a pre-created Secret for GitOps stability
```

1. Install/upgrade with `require: false` so the Secret is mounted while you
   configure the API server.
2. Point API-server `kubeConfigFile` at that bearer token
   ([Authenticate API servers](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#authenticate-apiservers)).
3. Flip `require: true` to enforce. Prefer `existingSecret` so upgrades do not
   rotate the token out from under the API server.

**Managed clouds (EKS/GKE/AKS)**

These usually cannot set kubeConfigFile. Use an explicit control-plane allowlist.
The cluster CNI must enforce NetworkPolicy ingress (Calico/Cilium/Azure NPM/etc.);
a policy alone is not a guarantee on every CNI:

```yaml
networkPolicy:
  enabled: true
  allowedCIDRs:
    - 10.0.0.0/16   # replace with your API-server / control-plane source CIDRs
```

Validate that legitimate admissions succeed and that a tenant Pod cannot reach
`/pods` on the webhook Service.

**Upgrade note (2.6.0)**

Existing releases must set one of the three SEC-001 options above on upgrade,
or Helm fails with a clear SEC-001 message. Env values are now always quoted.

### Upgrading to chart 2.0.0

The top-level `webhookFailurePolicy` value was removed. Move it under `mutatingWebhook.failurePolicy`:

```yaml
# before
webhookFailurePolicy: Fail

# after
mutatingWebhook:
  failurePolicy: Fail
```

### Webhook serving certificate (GitOps / cert-manager)

By default the chart generates a self-signed CA and serving certificate while rendering. That
generation is non-deterministic, so every `helm template` or `helm upgrade` produces a different
keypair. GitOps controllers such as ArgoCD render the chart on every sync cycle, so with auto-sync
and self-heal enabled they continuously detect drift and push a new certificate. This produces
`tls: bad certificate` handshake errors and rolls the webhook pods on every sync.

Set `mutatingWebhook.tls.existingSecretName` to a Secret you manage yourself to turn certificate generation
off. The chart then stops emitting the Secret, and the rendered output becomes byte-for-byte stable
across renders. The webhook server watches the Secret and reloads the certificate in place when it
is rotated, so renewal does not require a pod restart.

Because the chart no longer owns a CA in this mode, you must also tell the API server which CA to
trust, using either `mutatingWebhook.tls.caBundle` or `mutatingWebhook.tls.caBundleAnnotations`. Rendering fails if
neither is set. Both belong to this mode only: rendering also fails if `caBundleAnnotations` is set
without `existingSecretName`, since the chart writes its own generated CA into `caBundle` there and
an injector would overwrite it with an unrelated one.

With cert-manager issuing the certificate and injecting the CA bundle:

```yaml
mutatingWebhook:
  tls:
    existingSecretName: akeyless-injector-tls
    caBundleAnnotations:
      cert-manager.io/inject-ca-from: "akeyless/akeyless-injector-tls"
```

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: akeyless-injector-tls
  namespace: akeyless
spec:
  secretName: akeyless-injector-tls
  dnsNames:
    - RELEASE_NAME-akeyless-secrets-injection.akeyless.svc
  issuerRef:
    name: my-issuer
    kind: Issuer
```

`caBundleAnnotations` leaves `caBundle` out of the rendered `MutatingWebhookConfiguration` and lets
ca-injector write it into the live object. A GitOps controller renders the chart without that field,
reads the live value as drift, and with self-heal enabled strips it on the next sync, leaving the API
server unable to validate the webhook. Exclude the field from drift detection. ArgoCD:

```yaml
syncPolicy:
  syncOptions:
    - RespectIgnoreDifferences=true
ignoreDifferences:
  - group: admissionregistration.k8s.io
    kind: MutatingWebhookConfiguration
    name: RELEASE_NAME-akeyless-secrets-injection
    jsonPointers:
      - /webhooks/0/clientConfig/caBundle
```

`ignoreDifferences` alone only affects how ArgoCD calculates the diff. Without
`RespectIgnoreDifferences=true` the sync still applies the manifest without `caBundle` and
removes the injected value.

Flux, on the HelmRelease:

```yaml
driftDetection:
  mode: enabled
  ignore:
    - paths: ["/webhooks/0/clientConfig/caBundle"]
      target:
        kind: MutatingWebhookConfiguration
```

With a CA you manage outside the cluster, supply the PEM directly instead. The chart
base64-encodes it:

```yaml
mutatingWebhook:
  tls:
    existingSecretName: akeyless-injector-tls
    caBundle: |
      -----BEGIN CERTIFICATE-----
      ...
      -----END CERTIFICATE-----
```

The Secret must not be named after the chart's own generated full name, which is
`RELEASE_NAME-akeyless-secrets-injection` by default and whatever you set in `fullnameOverride`
otherwise. The chart stops emitting a Secret at that name in this mode, so `helm upgrade` on an
existing release would delete the Secret the pods mount. The chart rejects that name at render time,
including the `fullnameOverride` case.

The Secret must contain `tls.crt` and `tls.key`, and must exist before the webhook pods start. The
three failure modes differ, and so does what you will see:

- **Secret absent.** The kubelet cannot mount the volume, so the pod never starts and stays in
  `ContainerCreating` with a `FailedMount` event. There is no crash-loop, because no container runs.
- **Secret present but missing `tls.crt` or `tls.key`.** The volume has no `items` list, so whatever
  keys exist are mounted and the container starts. The webhook then finds no certificate at
  `/var/serving-cert` and exits, so the pod crash-loops.
- **Secret present with invalid TLS data.** The container starts and the webhook fails at handshake
  time, which surfaces as `tls: bad certificate` on the API server rather than as a pod failure.

The first two resolve on their own once the issuer populates the Secret; neither needs manual
intervention.

The following tables lists configurable parameters of the vault-secrets-webhook chart and their default values.

| Parameter                         | Description | Default |
| --------------------------------- | ----------- | ------- |
| `debug`                           | Enable debug logs for the webhook | `false` |
| `image.pullPolicy`                | Webhook image pull policy | `IfNotPresent` |
| `image.repository`                | Image repo that contains the admission server | `akeyless/k8s-webhook-server` |
| `image.agentImage`                | Image repo for the injected secrets sidecar | `akeyless/k8s-secrets-sidecar` |
| `replicaCount`                    | Number of webhook replicas | `2` |
| `mutatingWebhook`                 | Additional fields to render on the generated `MutatingWebhook`, such as `failurePolicy`, selectors, `timeoutSeconds`, `matchPolicy`, `reinvocationPolicy`, and `matchConditions`. Chart-owned fields like `clientConfig` and `rules` are not overridden here. | See `values.yaml` |
| `mutatingWebhook.failurePolicy`   | Failure policy for the mutating webhook | `Ignore` |
| `mutatingWebhook.namespaceSelector` | Namespace selector for the mutating webhook. Rendered with `tpl`, so values can reference release context. | Excludes `kube-system`, `kube-node-lease`, and the release namespace |
| `mutatingWebhook.objectSelector`  | Object selector for the mutating webhook. Rendered with `tpl`, so values can reference release context. | Excludes the release name |
| `mutatingWebhook.timeoutSeconds`  | Webhook request timeout in seconds | `10` |
| `mutatingWebhook.matchConditions` | CEL match conditions for the mutating webhook. Rendered with `tpl`, so values can reference release context. | `[]` |
| `mutatingWebhook.tls.existingSecretName`  | Existing Secret with `tls.crt`/`tls.key` for the webhook server. When set, the chart does not generate or manage a certificate. | `""` |
| `mutatingWebhook.tls.caBundle`            | PEM CA certificate written to the `MutatingWebhookConfiguration` `caBundle`. Only used with `existingSecretName`. | `""` |
| `mutatingWebhook.tls.caBundleAnnotations` | Annotations on the `MutatingWebhookConfiguration`, for controllers that inject `caBundle` themselves (for example cert-manager's ca-injector). Only used with `existingSecretName`. | `{}` |
| `deployment.nodeSelector`         | Node selector for webhook pods | `null` |
| `deployment.tolerations`          | Tolerations configuration for webhook pods | `{ enabled: false, data: [] }` |
| `deployment.affinity`             | Affinity configuration for webhook pods | `{ enabled: false }` |
| `resources`                       | Webhook container resource requests/limits | See `values.yaml` |
| `service.externalPort`            | Webhook service external port | `443` |
| `service.internalPort`            | Webhook service internal port | `8443` |
| `service.name`                    | Webhook service name | `secrets-webhook` |
| `service.type`                    | Webhook service type | `ClusterIP` |
