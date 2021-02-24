# Akeyless Kubernetes Secrets Injection

This chart will install a mutating admission webhook, that injects an executable to containers in a deployment/statefulset which than can request secrets from Akeyless Vault through environment variable definitions or local file on the container.

## Before you start

Before you install this chart you must create a namespace for it, this is due to the order in which the resources in the charts are applied (Helm collects all of the resources in a given Chart and it's dependencies, groups them by resource type, and then installs them in a predefined order (see [here](https://github.com/helm/helm/blob/master/pkg/releaseutil/kind_sorter.go#L31)).

The `MutatingWebhookConfiguration` gets created before the actual backend Pod which serves as the webhook itself, Kubernetes would like to mutate that pod as well, but it is not ready to mutate yet (infinite recursion in logic).

### Creating the namespace

The namespace must have a label of `name` with the namespace name as it's value.

set the target namespace name or skip for the default name: vswh

```bash
export WEBHOOK_NS=`<namepsace>`
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

The following tables lists configurable parameters of the vault-secrets-webhook chart and their default values.

|               Parameter             |                    Description                    |                  Default                 |
| ----------------------------------- | ------------------------------------------------- | -----------------------------------------|
|affinity                             |affinities to use                                  |{}                                        |
|debug                                |debug logs for webhook                             |false                                     |
|image.pullPolicy                     |image pull policy                                  |Always                                    |
|image.repository                     |image repo that contains the admission server      |akeyless/k8s-webhook-server               |
|image.tag                            |image tag                                          |latest                                    |
|namespaceSelector                    |namespace selector to use, will limit webhook scope|{}                                        |
|nodeSelector                         |node selector to use                               |{}                                        |
|replicaCount                         |number of replicas                                 |1                                         |
|resources                            |resources to request                               |{}                                        |
|service.externalPort                 |webhook service external port                      |443                                       |
|service.internalPort                 |webhook service external port                      |8443                                      |
|service.name                         |webhook service name                               |secrets-webhook                           |
|service.type                         |webhook service type                               |ClusterIP                                 |
|tolerations                          |tolerations to add                                 |[]                                        |