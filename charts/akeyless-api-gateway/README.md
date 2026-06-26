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

## Kubernetes Gateway API

This chart can expose the API Gateway through the [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
as an **alternative to** the Ingress API. The Gateway API is the long-term
successor to Ingress; major controllers (NGINX Gateway Fabric, Cilium, Istio,
Kong, Envoy Gateway) implement it, and [ingress-nginx is retiring in March 2026](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/).

`ingress` and `gatewayAPI` are **mutually exclusive** — enabling both fails the render.

### Resources rendered

| Values | Resource | API version |
|---|---|---|
| `gatewayAPI.gateway.create` | `Gateway` | `gateway.networking.k8s.io/v1` |
| `gatewayAPI.httpRoutes` | `HTTPRoute` | `gateway.networking.k8s.io/v1` |
| `gatewayAPI.tlsRoutes` | `TLSRoute` | `gateway.networking.k8s.io/v1alpha2` † |
| `gatewayAPI.tcpRoutes` | `TCPRoute` | `gateway.networking.k8s.io/v1alpha2` † |
| `gatewayAPI.referenceGrants` | `ReferenceGrant` | `gateway.networking.k8s.io/v1beta1` |

† `TLSRoute`/`TCPRoute` are served only by the Gateway API **Experimental** channel CRDs (see Prerequisites).

### Prerequisites

1. Install the Gateway API CRDs. The **standard** channel covers `Gateway`/`GatewayClass`/`HTTPRoute`/`ReferenceGrant`:
   ```sh
   kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
   ```
   For `tlsRoutes`/`tcpRoutes`, install the **experimental** channel instead:
   ```sh
   kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/experimental-install.yaml
   ```
2. Install a Gateway controller and note its GatewayClass name (e.g. `nginx`, `cilium`, `istio`). Raw `TCPRoute` support varies by controller — confirm yours implements it before enabling `tcpRoutes`.

### Quick start (HTTP, NGINX Gateway Fabric)

```yaml
ingress:
  enabled: false
gatewayAPI:
  enabled: true
  gateway:
    create: true
    gatewayClassName: nginx
  httpRoutes:
    - { hostname: api.example.com, servicePort: api }
    - { hostname: ui.example.com,  servicePort: web }
```

### HTTPS termination (Cilium)

```yaml
gatewayAPI:
  enabled: true
  gateway:
    gatewayClassName: cilium
    tls:
      enabled: true
      mode: Terminate
      certificateRefs:
        - name: akeyless-api-tls
  httpRoutes:
    - { hostname: api.example.com, servicePort: api }
```

### KMIP over raw TCP

```yaml
gatewayAPI:
  enabled: true
  gateway:
    gatewayClassName: cilium
  tcpRoutes:
    - { name: kmip, servicePort: kmip }   # TCP listener on 5696 + TCPRoute
```

### Attach to a shared cluster Gateway (cross-namespace)

```yaml
gatewayAPI:
  enabled: true
  gateway:
    create: false                  # do not create a Gateway
  parentRefs:
    - { name: shared-gateway, namespace: gateway, sectionName: https }
  httpRoutes:
    - { hostname: api.example.com, servicePort: api }
  referenceGrants:                 # authorize the cross-namespace reference
    - name: allow-gateway-ns
      from:
        - { group: gateway.networking.k8s.io, kind: HTTPRoute, namespace: gateway }
      to:
        - { group: "", kind: Service }
```

### Migrating from Ingress

The `httpRoutes` surface mirrors `ingress.rules`, so migration is close to a key rename:

| Ingress | Gateway API |
|---|---|
| `ingress.enabled: true` | `gatewayAPI.enabled: true` (and `ingress.enabled: false`) |
| `ingress.ingressClassName: nginx` | `gatewayAPI.gateway.gatewayClassName: nginx` |
| `ingress.rules[].{hostname,servicePort,path}` | `gatewayAPI.httpRoutes[].{hostname,servicePort,path}` |
| `ingress.tls: true` + cert secret | `gatewayAPI.gateway.tls: {enabled: true, mode: Terminate, certificateRefs}` |

### Fail-loud guards

The chart refuses to render an ambiguous or unusable Gateway API configuration:

| Guard | Rejected configuration |
|---|---|
| G1 | `ingress.enabled` **and** `gatewayAPI.enabled` both true |
| G2 | `gateway.create: true` with an empty `gatewayClassName` |
| G3 | `gateway.create: false` with empty `parentRefs` |
| G4 | a route `servicePort` not present in `service.ports` |
| G5 | `tlsRoutes` without a passthrough TLS listener |

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
| `gatewayAPI.enabled`                      | Render Gateway API resources instead of an Ingress (mutually exclusive with `ingress.enabled`) | `false` |
| `gatewayAPI.gateway.create`               | Create a Gateway (`false` = attach routes to an existing Gateway via `parentRefs`) | `true` |
| `gatewayAPI.gateway.gatewayClassName`     | GatewayClass selecting the controller (nginx/cilium/istio/...) — required when `gateway.create=true` | `""` |
| `gatewayAPI.gateway.tls`                  | 443 listener: `enabled`, `mode` (Terminate/Passthrough), `certificateRefs` | disabled |
| `gatewayAPI.parentRefs`                   | Gateways routes attach to (empty = the created Gateway) | `[]` |
| `gatewayAPI.httpRoutes`                   | HTTPRoutes — `{hostname, servicePort, path?}` (same shape as `ingress.rules`) | Check `values.yaml` file |
| `gatewayAPI.tlsRoutes`                    | TLSRoutes (SNI passthrough) — `{hostname, servicePort}` | `[]` |
| `gatewayAPI.tcpRoutes`                    | TCPRoutes (raw L4, e.g. KMIP) — `{name, servicePort}` | `[]` |
| `gatewayAPI.referenceGrants`              | ReferenceGrants authorizing cross-namespace references | `[]` |

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

