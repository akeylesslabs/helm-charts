# Akeyless API Gateway
 

## Introduction
This chart bootstraps API-GATEWAY deployment on a Kubernetes cluster using the Helm package manager.
This chart has been tested to work with [NGINX Ingress](https://kubernetes.github.io/ingress-nginx/) and [cert-manager](https://cert-manager.io/).


#### Preqrequisites

##### Horizonal Auto-Scaling
Horizontal auto-scaling is based on the HorizonalPodAutoscaler object.  
For it to work properly, Kubernetes metrics server must be installed in the cluster - https://github.com/kubernetes-sigs/metrics-server.

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
helm install RELEASE_NAME akeyless/akeyless-api-gateway
``` 

## Parameters

The following table lists the configurable parameters of the API Gateway chart and their default values.

### Deployment parameters

| Parameter                                 | Description                                                                                                          | Default                                                      |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `image.repository`                        | API Gateway image name                                                                                               | `akeyless/base`                                              |
| `image.tag`                               | API Gateway image tag                                                                                                | `latest`                                                     |      
| `image.pullPolicy`                        | API Gateway image pull policy                                                                                        | `Always`                                                     |  
| `containerName`                           | API Gateway container name                                                                                           | `api-gateway`                                                |    
| `replicaCount`                            | Number of API Gateway pods                                                                                           | `2`                                                          |
| `livenessProbe`                           | Liveness probe configuration for API Gateway                                                                         | Check `values.yaml` file                                     |                   
| `readinessProbe`                          | Readiness probe configuration for API Gateway                                                                        | Check `values.yaml` file                                     |         
| `resources.limits`                        | The resources limits for API Gateway (If HPA is enabled these must be set)                                           | `{}`                                                         |
| `resources.requests`                      | The requested resources for API Gateway (If HPA is enabled these must be set)                                        | `{}`                                                         |

### Exposure parameters

| Parameter                                 | Description                                                                                                          | Default                                                      |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `service.type`                            | Kubernetes service type                                                                                              | `LoadBalancer`                                               |
| `service.ports`                           | Service ports object, look at the comments for examples                                                              | Check `values.yaml` file                                     |
| `service.annotations`                     | Service extra annotations                                                                                            | `{}`                                                         |
| `ingress.enabled`                         | Enable ingress resource                                                                                              | `false`                                                      |
| `ingress.annotations`                     | Ingress annotations                                                                                                  | `[]`                                                         |
| `ingress.rules`                           | Ingress rules object, look at the comments for examples                                                              | Check `values.yaml` file                                     |
| `ingress.path`                            | Path for the default host                                                                                            | `/`                                                          |
| `ingress.tls`                             | Enable TLS configuration for the hostname                                                                            | `false`                                                      |
| `ingress.certManager`                     | Add annotations for cert-manager                                                                                     | `false`                                                      |

### HPA parameters

| Parameter                                 | Description                                                                                                          | Default                                                      |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `HPA.enabled`                             | Enable API Gateway Horizontal Pod Autoscaler                                                                         | `false`                                                      |
| `HPA.minReplicas`                         | Minimum desired number of replicas                                                                                   | `1`                                                          |
| `HPA.maxReplicas`                         | Minimum desired number of replicas                                                                                   | `14`                                                         |
| `HPA.cpuAvgUtil`                          | CPU average utilization                                                                                              | `50`                                                         |
| `HPA.memAvgUtil`                          | Memory average utilization                                                                                           | `50`                                                         |                                                                                        

### API-Gateway configuration parameters

| Parameter                                   | Description                                                                                                          | Default                                                      |
|---------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `akeylessUserAuth.adminAccessId`            | Akeyless Access ID (can used as email address)                                                                       | `nil`                                                        |
| `akeylessUserAuth.adminAccessKey`           | Akeyless Access Key                                                                                                  | `nil`                                                        |
| `akeylessUserAuth.adminPassword`            | Akeyless Access Password (should be used only when `akeylessUserAuth.adminAccessId` is email)                        | `nil`                                                        |
| `akeylessUserAuth.clusterName`              | API Gateway cluster name                                                                                             | `nil`                                                        |
| `akeylessUserAuth.initialClusterDisplayName`| API Gateway cluster display name                                                                                     | `nil`                                                        |
| `akeylessUserAuth.configProtectionKeyName`  | Akeyless Protection key name                                                                                         | `nil`                                                        |
| `akeylessUserAuth.allowedAccessIDs`         | List of allowed Access ID's to enable multiple users to be able to login and manage API GW.                          | `nil`                                                        |
| `customerFragments`                         | API Gateway customer fragment                                                                                        | `nil`                                                        |
| `existingSecret`                            | Specifies an existing secret to be used for API Gateway                                                              | `Check `values.yaml` file`                                   |                                  |


### API-Gateway defaults section configuration parameters

| Parameter                                   | Description                                                                                                          | Default                                                      |
|---------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `defaultsConf.defaultSamlAccessId`            | Default SAML Access ID to be used for initial WebUI login     | `nil`                                                        |
| `defaultsConf.defaultOidcAccessId`           | Default OIDC Access ID to be used for initial WebUI login      | `nil`                                                        |
| `defaultsConf.defaultEncryptionKey`            | This Default Encryption Key will be selected when creating the following items: Static Secrets, Dynamic Secret Producers and Secret Migration Configurations                        | `nil`                                                        |
| `defaultsConf.defaultSecretLocation`              | The location of the default path to save secrets                   | `nil`                                                        |


### API-Gateway caching section configuration parameters

| Parameter                                   | Description                                                                                                          | Default                                                      |
|---------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `cachingConf.enabled`            | Should Caching be enabled                                                                       | `false`                                                        |
| `cachingConf.cacheTTL`           | Stale timeout in minutes, cache entries which are not accessed within timeout will be removed from cache | `nil`                                                        |
| `cachingConf.proActiveCaching.enabled`            | Should Proactive Caching be enabled                           | `false`                                                        |
| `cachingConf.proActiveCaching.minimumFetchingTime`              | When using Caching or/and Proactive Caching, additional secrets will be fetched upon requesting a secret, based on the requestor's access policy. Define minimum fetching interval to avoid over fetching in a given time frame. name                                                                                                                                                                    | `nil`
| `cachingConf.proActiveCaching.dumpInterval`              | To ensure service continuity in case of power cycle and network outage secrets will be backed up periodically per backup interval.                                                                                              | `nil`                                                          |


### API-Gatewaylogand configuration

| Parameter                                   | Description                                                                                                          | Default                                                      |
|---------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `logandConf`            |  Specifies an initial configuration for log forwarding. for more details: https://docs.akeyless.io/docs/log-forwarding                                                                       |                                                         |