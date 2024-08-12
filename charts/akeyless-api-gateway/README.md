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

| Parameter                       | Description                                                                                                        | Default                  |
|---------------------------------|--------------------------------------------------------------------------------------------------------------------|--------------------------|
| `image.repository`              | API Gateway image name                                                                                             | `akeyless/base`          |
| `image.tag`                     | API Gateway image tag                                                                                              | `latest`                 |      
| `image.pullPolicy`              | API Gateway image pull policy                                                                                      | `Always`                 |  
| `containerName`                 | API Gateway container name                                                                                         | `api-gateway`            |    
| `replicaCount`                  | Number of API Gateway pods                                                                                         | `2`                      |
| `livenessProbe`                 | Liveness probe configuration for API Gateway                                                                       | Check `values.yaml` file |                   
| `readinessProbe`                | Readiness probe configuration for API Gateway                                                                      | Check `values.yaml` file |         
| `resources.limits`              | The resources limits for API Gateway (If HPA is enabled these must be set)                                         | `{}`                     |
| `resources.requests`            | The requested resources for API Gateway (If HPA is enabled these must be set)                                      | `{}`                     |
| `httpProxySettings.http_proxy`  | Standard linux HTTP Proxy, should contain the URLs of the proxies for HTTP                                         | `nil`                    |  
| `httpProxySettings.https_proxy` | Standard linux HTTP Proxy, should contain the URLs of the proxies for HTTPS                                        | `nil`                    |  
| `httpProxySettings.no_proxy`    | Standard linux HTTP Proxy, should contain a comma-separated list of domain extensions proxy should not be used for | `nil`                    |
| `cache.resources.limits`        | The resources limits for the redis cluster cache                                                                   | `{}`                     |

### Exposure parameters

| Parameter                                 | Description                                                                                                          | Default                  |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------|
| `service.type`                            | Kubernetes service type                                                                                              | `LoadBalancer`           |
| `service.ports`                           | Service ports object, look at the comments for examples                                                              | Check `values.yaml` file |
| `service.annotations`                     | Service extra annotations                                                                                            | `{}`                     |
| `ingress.enabled`                         | Enable ingress resource                                                                                              | `false`                  |
| `ingress.ingressClassName`                | A reference to an IngressClass resource                                                                              | `nil`                    |
| `ingress.annotations`                     | Ingress annotations                                                                                                  | `[]`                     |
| `ingress.rules`                           | Ingress rules object, look at the comments for examples                                                              | Check `values.yaml` file |
| `ingress.path`                            | Path for the default host                                                                                            | `/`                      |
| `ingress.tls`                             | Enable TLS configuration for the hostname                                                                            | `false`                  |
| `ingress.certManager`                     | Add annotations for cert-manager                                                                                     | `false`                  |

### HPA parameters

| Parameter                                 | Description                                                                                                          | Default                                                      |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `HPA.enabled`                             | Enable API Gateway Horizontal Pod Autoscaler                                                                         | `false`                                                      |
| `HPA.minReplicas`                         | Minimum desired number of replicas                                                                                   | `1`                                                          |
| `HPA.maxReplicas`                         | Minimum desired number of replicas                                                                                   | `14`                                                         |
| `HPA.cpuAvgUtil`                          | CPU average utilization                                                                                              | `50`                                                         |
| `HPA.memAvgUtil`                          | Memory average utilization                                                                                           | `50`                                                         |                                                                                        

### API-Gateway configuration parameters

| Parameter                                     | Description                                                                                                                                                                     | Default                  |
|-----------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------|
| `akeylessUserAuth.adminAccessId`              | Akeyless Access ID (can used as email address)                                                                                                                                  | `nil`                    |
| `akeylessUserAuth.adminAccessKey`             | Akeyless Access Key                                                                                                                                                             | `nil`                    |
| `akeylessUserAuth.adminPassword`              | Akeyless Access Password (should be used only when `akeylessUserAuth.adminAccessId` is email)                                                                                   | `nil`                    |
| `akeylessUserAuth.clusterName`                | API Gateway cluster name                                                                                                                                                        | `nil`                    |
| `akeylessUserAuth.initialClusterDisplayName`  | API Gateway cluster display name                                                                                                                                                | `nil`                    |
| `akeylessUserAuth.configProtectionKeyName`    | Akeyless Protection key name                                                                                                                                                    | `nil`                    |
| `akeylessUserAuth.allowedAccessIDs`           | List of allowed Access ID's to enable multiple users to be able to login and manage API GW.                                                                                     | `nil`                    |
| `akeylessUserAuth.restrictServiceToAccessIds`           | Explicity restrict access to the following AccessIds                                                                                    | `nil`                    |
| `akeylessUserAuth.blockedAccessIds`    | List of blocked AccessIds                                                                                    | `nil`                    
| `akeylessUserAuth.allowedAccessPermissions`   | List of allowed accesses to enable multiple users to be able to login and manage the Gateway with specific permissions and sub claims. See `values.yaml` file for more details. | `nil`                    |
| `akeylessUserAuth.useGwForOidc`   | If set to true, the oidc login will use the gateway as callback redirect target  | false                   |
| `customerFragments`                           | API Gateway customer fragment                                                                                                                                                   | `nil`                    |
| `adminAccessIdExistingSecret`                 | Use k8s existing secret, must include the following key: admin-access-id                                                                                                        | Check `values.yaml` file |
| `adminAccessKeyExistingSecret`                | Use k8s existing secret, must include the following key: admin-access-key                                                                                                       | Check `values.yaml` file |
| `adminPasswordExistingSecret`                 | Use k8s existing secret, must include the following key: admin-password                                                                                                         | Check `values.yaml` file |
| `adminBase64CertificateExistingSecret`        | Use k8s existing secret, must include the following key: admin-certificate (base64)                                                                                             | Check `values.yaml` file |
| `adminBase64CertificateKeyExistingSecret`     | Use k8s existing secret, must include the following key: admin-certificate-key (base64)                                                                                         | Check `values.yaml` file |
| `adminUIDInitTokenExistingSecret`             | Use k8s existing secret, must include the following key: admin-uid-init-token                                                                                                   | Check `values.yaml` file |
| `allowedAccessIDsExistingSecret`              | Use k8s existing secret, must include the following key: allowed-access-ids                                                                                                     | Check `values.yaml` file |
| `allowedAccessPermissionsExistingSecret`      | Use k8s existing secret, must include the following key: allowed-access-permissions                                                                                             | Check `values.yaml` file |
| `customerFragmentsExistingSecret`             | Use k8s existing secret, must include the following key: customer-fragments                                                                                                     | Check `values.yaml` file |
| `customerFragmentsEncodedExistingSecret`      | Use k8s existing secret, must include the following key: customer-fragments (base64)                                                                                            | Check `values.yaml` file |


### API-Gateway defaults section configuration parameters

| Parameter                                   | Description                                                                                                          | Default                                                      |
|---------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `defaultsConf.defaultSamlAccessId`            | Default SAML Access ID to be used for initial WebUI login     | `nil`                                                        |
| `defaultsConf.defaultOidcAccessId`           | Default OIDC Access ID to be used for initial WebUI login      | `nil`                                                        |
| `defaultsConf.defaultCertificateAccessId`    | Default Certificate Access ID to be used for initial WebUI login | `nil`                                                        |
| `defaultsConf.defaultEncryptionKey`            | This Default Encryption Key will be selected when creating the following items: Static Secrets, Dynamic Secret Producers and Secret Migration Configurations                        | `nil`                                                        |
| `defaultsConf.defaultSecretLocation`              | The location of the default path to save secrets                   | `nil`                                                        |


### API-Gateway general section configuration parameters

| Parameter                                   | Description                                                                                                                        | Default                                                      |
|---------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `TLSConf.minimumTlsVersion`            | Minimum TLS version that is acceptable, can be one of the following <TLSv1/TLSv1.1/TLSv1.2/TLSv1.3>                                | `nil`   
| `TLSConf.excludeCipherSuites`            | Comma separated list of cipher suites to exclude (e.g. "TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA,TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA") | `nil`                                                        |

### API-Gateway caching section configuration parameters

| Parameter                                              | Description                                                                                                                                                                                                                           | Default |
|--------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------|
| `cachingConf.enabled`                                  | Should Caching be enabled                                                                                                                                                                                                             | `false` |
| `cachingConf.cacheTTL`                                 | Stale timeout in minutes, cache entries which are not accessed within timeout will be removed from cache                                                                                                                              | `nil`   |
| `cachingConf.proActiveCaching.enabled`                 | Should Proactive Caching be enabled                                                                                                                                                                                                   | `false` |
| `cachingConf.proActiveCaching.minimumFetchingTime`     | When using Caching or/and Proactive Caching, additional secrets will be fetched upon requesting a secret, based on the requestor's access policy. Define minimum fetching interval to avoid over fetching in a given time frame. name | `nil`   |
| `cachingConf.proActiveCaching.dumpInterval`            | To ensure service continuity in case of power cycle and network outage secrets will be backed up periodically per backup interval.                                                                                                    | `nil`   |
| `cachingConf.clusterCache.enabled`                     | Should cluster caching be enabled                                                                                                                                                                                                     | `false` |
| `cachingConf.clusterCache.encryptionKeyExistingSecret` | In case clusterCache is enabled, you must specify an existing secret for the cluster cache configuration, must include the following key: cluster-cache-encryption-key                                                                | `nil`   |

### API-Gateway logand configuration

| Parameter                                   | Description                                                                                                          | Default                                                      |
|---------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `logandConf`            |  Specifies an initial configuration for log forwarding. for more details: https://docs.akeyless.io/docs/log-forwarding                                                                       |                                                         |

### API-Gateway Metrics configuration

| Parameter                                   | Description                                                                                                          | Default                                                      |
|---------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `metrics.enabled`            | Enable metrics streaming                                                                         | `false`                                                        |
| `metrics.config`           | Configure the metrics streaming exporter(backend). Must be in YAML foramt. For more details: docs-ref | `nil`
| `metrics.existingSecretName`                            | Specifies an existing secret to be used for Metrics streaming configuration, instead of using `metrics.config`                                                              | Check `values.yaml` file                                  |

### API-Gateway custom agreements configuration

| Parameter                                         | Description                                                                 | Default |
|---------------------------------------------------|-----------------------------------------------------------------------------|---------|
| `loginPageAgreementLinks.endUserLicenseAgreement` | Specifies a custom end user license agreement link to be used on login page | `nil`   |
| `loginPageAgreementLinks.privacyPolicy`           | Specifies a custom privacy policy agreement link to be used on login page   | `nil`   |

### API-Gateway gRPC configuration

| Parameter                                   | Description                                                                                                          | Default                                                      |
|---------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `grpc.enabled`            |  Should the gRPC API be enabled enabled                                                     | false 

