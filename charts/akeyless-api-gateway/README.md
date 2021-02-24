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

### API-Gatewayconfiguration parameters

| Parameter                                 | Description                                                                                                          | Default                                                      |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `akeylessUserAuth.adminAccessId`          | Akeyless Access ID (can used as email address)                                                                       | `nil`                                                        |
| `akeylessUserAuth.adminAccessKey`         | Akeyless Access Key                                                                                                  | `nil`                                                        |
| `akeylessUserAuth.adminPassword`          | Akeyless Access Password (should be used only when `akeylessUserAuth.adminAccessId` is email)                        | `nil`                                                        |
| `akeylessUserAuth.clusterName`            | API Gateway cluster name                                                                                             | `nil`                                                        |
| `akeylessUserAuth.configProtectionKeyName`| Akeyless Protection key name                                                                                         | `nil`                                                        |
                       
