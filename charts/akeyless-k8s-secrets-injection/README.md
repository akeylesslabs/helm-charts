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

## Configuration

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

Set `webhook.tls.existingSecretName` to a Secret you manage yourself to turn certificate generation
off. The chart then stops emitting the Secret, and the rendered output becomes byte-for-byte stable
across renders. The webhook server watches the Secret and reloads the certificate in place when it
is rotated, so renewal does not require a pod restart.

Because the chart no longer owns a CA in this mode, you must also tell the API server which CA to
trust, using either `webhook.tls.caBundle` or `webhook.tls.caBundleAnnotations`. Rendering fails if
neither is set.

With cert-manager issuing the certificate and injecting the CA bundle:

```yaml
webhook:
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

With a CA you manage outside the cluster, supply the PEM directly instead — the chart
base64-encodes it:

```yaml
webhook:
  tls:
    existingSecretName: akeyless-injector-tls
    caBundle: |
      -----BEGIN CERTIFICATE-----
      ...
      -----END CERTIFICATE-----
```

The Secret must contain `tls.crt` and `tls.key`, and must exist before the webhook pods start. The
webhook reads the mounted certificate at startup and exits if it is missing, so pods will crash-loop
until the issuer has populated the Secret and then recover on their own.

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
| `webhook.tls.existingSecretName`  | Existing Secret with `tls.crt`/`tls.key` for the webhook server. When set, the chart does not generate or manage a certificate. | `""` |
| `webhook.tls.caBundle`            | PEM CA certificate written to the `MutatingWebhookConfiguration` `caBundle`. Only used with `existingSecretName`. | `""` |
| `webhook.tls.caBundleAnnotations` | Annotations on the `MutatingWebhookConfiguration`, for controllers that inject `caBundle` themselves (for example cert-manager's ca-injector). Only used with `existingSecretName`. | `{}` |
| `deployment.nodeSelector`         | Node selector for webhook pods | `null` |
| `deployment.tolerations`          | Tolerations configuration for webhook pods | `{ enabled: false, data: [] }` |
| `deployment.affinity`             | Affinity configuration for webhook pods | `{ enabled: false }` |
| `resources`                       | Webhook container resource requests/limits | See `values.yaml` |
| `service.externalPort`            | Webhook service external port | `443` |
| `service.internalPort`            | Webhook service internal port | `8443` |
| `service.name`                    | Webhook service name | `secrets-webhook` |
| `service.type`                    | Webhook service type | `ClusterIP` |
