# Akeyless Secure Remote Access

Combines both Zero Trust Bastion and SSH-Bastion capabilities.

Akeyless Zero Trust Bastion provides zero trust access to remote resources using Akeyless JIT credentials (dynamic secrets and SSH certificate issuers).

[Akeyless SSH Bastion](https://docs.akeyless.io/docs/how-to-configure-ssh#akeyless-ssh-bastion) Traffic SSH connections with signed certificate authentication, together with session recording. 

## Introduction
This chart bootstraps a Akeyless Zero Trust Bastion deployment and a Akeyless SSH bastion statefulset on Kubernetes cluster using the Helm package manager.

## Preparation

### Storage
Currently, the Akeyless SSH bastion requires a storage class with ReadWriteMany access modes.  
Since a storage class is more environment specific, you will need to provide one before proceeding.
In addition, please provide 2 PersistentVolumes with `persistentVolumeReclaimPolicy: retain` and reference those PVs in the `values.yaml` file

e.g when running on AWS with EKS:
https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html

### Network
Currently, when using DB applications (mysql, mongodb, mssql, postgres) via the Akeyless Zero Trust Bastion, it'll only work properly when using
load balancer with "sticky" session:
- Ingress - Make sure to use sticky session annotation, for example `nginx.ingress.kubernetes.io/affinity: "cookie"` in Nginx
- Cloud Provider LB - Make sure to config the LB to support sticky session, for example is AWS, using ELB:
https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/elb-sticky-sessions.html
- When using SSH sessions behind load balancer such as ELB, the session can be closed due to **idle connection timeout**, so its advised to increase it to a reasonably high value, or even unlimited.

### Prerequisites

#### Horizonal Auto-Scaling
Horizontal auto-scaling is based on the HorizonalPodAutoscaler object.
For it to work properly, Kubernetes metrics server must be installed in the cluster - https://github.com/kubernetes-sigs/metrics-server

## Get Repo Info

```bash
$ helm repo add helm-charts https://akeylesslabs.github.io/helm-charts
$ helm repo update
```
See [helm repo](https://helm.sh/docs/helm/helm_repo/) for command documentation.

## Installing the Chart

The `values.yaml` file holds default values, replace the values with the ones from your environment where needed.

To install the chart run:
```bash
helm install RELEASE_NAME akeyless/akeyless-sra -f values.yaml
```
## Global Parameters

| Parameter                                 | Description                                                                                                          | Default                                                      |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|                                                
| `dockerRepositoryCreds`             | Akeyless docker repository credentials. Please contact Akeyless. **Required**                                                                                | `nil` 
| `apiGatewayURL`                    | API Gateway URL to use to fetch the secrets **Required**                                                                      | `https://rest.akeyless.io`
| `privilegedAccess`                    | Supported auth methods: AWS IAM, Azure AD, GCP and API Key.For AWS IAM or Azure AD, or GCP provide only accessID. For API Key, provide both accessID and accessKey                                                                       | ` `
| `legacySigningAlg`                 | When set to "true", will sign ssh certificates using the legacy 'ssh-rsa-cert-v01@openssh.com' signing algorithm name in the certificate. | `"false"`
| `usernameSubClaim`                 | Optional, provide a key-name to extract the username (value) of that key in sub-claims. The extracted username will be used to authenticated to the remote target (RDP or SSH).
| `privilegedAccess.accessID`                    | Privileged access ID (API Key, Azure AD, GCP, AWS IAM) **Required**                                                              | ` `
| `privilegedAccess.accessKey`                    | API key accessKey                                                                           | ` `
| `privilegedAccess.allowedAccessIDs`                    | limit access to privileged items only for these end user access ids. If left empty, all access ids are allowedCredentials                                                                           | `[]`
| `privilegedAccess.azureObjectID`                    | Azure Object ID to use with privileged credentials of type Azure AD                                                                           | `nil`
| `privilegedAccess.gcpAudience`                    | Audience to use with privileged credentials of type GCP                                                                           | `akeyless.io`
| `httpProxySettings.http_proxy`            | Standard linux HTTP Proxy, should contain the URLs of the proxies for HTTP                                           | `nil`                                                        |  
| `httpProxySettings.https_proxy`           | Standard linux HTTP Proxy, should contain the URLs of the proxies for HTTPS                                          | `nil`                                                        |  
| `httpProxySettings.no_proxy`              | Standard linux HTTP Proxy, should contain a comma-separated list of domain extensions proxy should not be used for   | `nil`                                                        |


## Zero Trust Bastion Parameters

The following table lists the configurable parameters of the Zero Trust Bastion chart, and their default values.

### Deployment parameters

| Parameter                      | Description                                                                                                                                | Default                       |
|--------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------|
| `ztbConfig.enabled`            | Enable Zero Trust Bastion                                                                                                                  | `true`                        |
| `ztbConfig.image.repository`   | Zero Trust Bastion image name                                                                                                              | `akeyless/zero-trust-bastion` |
| `ztbConfig.image.tag`          | Zero Trust Bastion image tag                                                                                                               | `latest`                      |
| `ztbConfig.image.pullPolicy`   | Zero Trust Bastion image pull policy                                                                                                       | `Always`                      |                                                        |
| `ztbConfig.updateStrategy`     | Updating statefulset strategy                                                                                                              | `ztbConfig.RollingUpdate`     |
| `ztbConfig.containerName`      | Zero Trust Bastion container name                                                                                                          | `zero-trust-bastion`          |
| `ztbConfig.replicaCount`       | Number of Zero Trust Bastion nodes                                                                                                         | `1`                           |
| `ztbConfig.livenessProbe`      | Liveness probe configuration for Zero Trust Bastion                                                                                        | Check `values.yaml` file      |
| `ztbConfig.readinessProbe`     | Readiness probe configuration for Zero Trust Bastion                                                                                       | Check `values.yaml` file      |
| `ztbConfig.resources.limits`   | The resources limits for Zero Trust Bastion containers                                                                                     | `{}`                          |
| `ztbConfig.resources.requests` | The requested resources for Zero Trust Bastion containers                                                                                  | `{}`                          |
| `ztbConfig.allowedBastionUrls` | Comma separated list of the URLs that will be considered valid for redirection to this bastion (security measure to prevent Open Redirect) | `[]`                          |

### Exposure parameters

| Parameter                                 | Description                                                                                                          | Default                                                      |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `ztbConfig.service.type`                            | Kubernetes Service type                                                                                              | `LoadBalancer`                                               |
| `ztbConfig.service.port`                            | API port                                                                                                             | `8888`                                                       |
| `ztbConfig.ingress.enabled`                         | Enable ingress resource                                                                                              | `false`                                                      |
| `ztbConfig.ingress.path`                            | Path for the default host                                                                                            | `/`                                                          |
| `ztbConfig.ingress.certManager`                     | Add annotations for cert-manager                                                                                     | `false`                                                      |
| `ztbConfig.ingress.hostname`                        | Default host for the ingress resource                                                                                | `zero-trust-bastion.local`                                   |
| `ztbConfig.ingress.annotations`                     | Ingress annotations                                                                                                  | `[]`                                                         |
| `ztbConfig.ingress.tls`                             | Enable TLS configuration for the hostname defined at `ingress.hostname` parameter                                    | `false`                                                      |
| `ztbConfig.ingress.existingSecret`                  | Existing secret for the Ingress TLS certificate                                                                      | `nil`                                                        |


### configuration parameters

| Parameter                                 | Description                                                                                                          | Default                                                      |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `ztbConfig.config.rdpRecord.enabled`                | Enable RDP session recording                                                                                         | `false`                                                      |
| `ztbConfig.config.rdpRecord.s3.bucketName`          | AWS S3 bucket name to store RDP recording                                                                            | `nil`                                                        |
| `ztbConfig.config.rdpRecord.s3.bucketPrefix`        | AWS S3 bucket prefix                                                                                                 | `nil`                                                        |
| `ztbConfig.config.rdpRecord.s3.region`              | AWS S3 bucket region                                                                                                 | `nil`                                                        |
| `ztbConfig.config.rdpRecord.s3.awsAccessKeyId`      | AWS Access Key ID, not required if using EC2 IAM roles                                                               | `nil`                                                        |
| `ztbConfig.config.rdpRecord.s3.awsSecretAccessKey`  | AWS Secret Access Key, not required if using EC2 IAM roles                                                           | `nil`                                                        |
| `ztbConfig.config.rdpRecord.existingSecret`         | Specifies an existing secret to be used for bastion, management AWS credentials                                      | `nil`                                                        |

### HPA parameters

| Parameter                                 | Description                                                                                                          | Default                                                      |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `ztbConfig.HPA.enabled`                             | Enable Zero Trust Bastion Horizontal Pod Autoscaler                                                                  | `false`                                                      |
| `ztbConfig.HPA.minReplicas`                         | Minimum desired number of replicas                                                                                   | `1`                                                          |
| `ztbConfig.HPA.maxReplicas`                         | Minimum desired number of replicas                                                                                   | `14`                                                         |
| `ztbConfig.HPA.cpuAvgUtil`                          | CPU average utilization                                                                                              | `50`                                                         |
| `ztbConfig.HPA.memAvgUtil`                          | Memory average utilization                                                                                           | `50`                                                         |

## SSH-Bastion Parameters

The following table lists the configurable parameters of the SSH Bastion chart and their default values.

### Statefulset parameters

| Parameter                                 | Description                                                                                                          | Default                                                      |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `ssgConfig.enabled`                        | Enable SSH Bastion                                                                                         | `true`
| `sshConfig.image.repository`                        | SSH Bastion image name                                                                                               | `akeyless/ssh-bastion`                                         |
| `sshConfig.image.tag`                               | SSH Bastion image tag                                                                                                | `latest`                                                     |      
| `sshConfig.image.pullPolicy`                        | SSH Bastion image pull policy                                                                                        | `Always`                                                     |                                                       |
| `sshConfig.updateStrategy`                          | Updating statefulset strategy                                                                                        | `RollingUpdate`                                              |  
| `sshConfig.containerName`                           | SSH Bastion container name                                                                                           | `ssh-proxy`                                                  |  
| `sshConfig.replicaCount`                            | Number of SSH-Bastion nodes                                                                                          | `1`                                                          |
| `sshConfig.livenessProbe`                           | Liveness probe configuration for SSH Bastion                                                                         | Check `values.yaml` file                                     |                   
| `sshConfig.readinessProbe`                          | Readiness probe configuration for SSH Bastion                                                                        | Check `values.yaml` file                                     |         
| `sshConfig.resources.limits`                        | The resources limits for SSH Bastion containers  (If HPA is enabled these must be set)                               | `{}`                                                         |
| `sshConfig.resources.requests`                      | The requested resources for SSH-Bastion containers (If HPA is enabled these must be set)                             | `{}`                                                         |


### Exposure parameters

| Parameter                                 | Description                                                                                                          | Default                                                      |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `sshConfig.service.type`                            | Kubernetes Service type                                                                                              | `LoadBalancer`                                               |
| `sshConfig.service.port`                            | ssh port                                                                                                             | `22`                                                         |
| `sshConfig.service.curlProxyPort`                   | Akeyless curl proxy port                                                                                             | `9900`                                                       |

### Configuration parameters

| Parameter                                 | Description                                                                                                          | Default                                                      |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `sshConfig.config.CAPublicKey`                      | CA’s public key (ca.pub) - **Required**                                                                                  | `nil`                                                        |
| `sshConfig.config.sessionTermination.enabled`       | Enable session termination, ex. OKTA, Keycloak                                                                       | `false`                                                      |
| `sshConfig.config.sessionTermination.apiURL`        | API URL                                                                                                              | `nil`                                                        |
| `sshConfig.config.sessionTermination.apiToken`      | API Token                                                                                                            | `nil`                                                        |
| `sshConfig.config.logForwarding.enabled`            | Enable [log forwarding](https://docs.akeyless.io/docs/ssh-log-forwarding)                                            | `false`                                                      |
| `sshConfig.config.logForwarding.settings`           | Log forwarding configuration                                                                                         | `nil`                                                        |

### Persistence parameters

| Parameter                                 | Description                                                                                                          | Default                                                      |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `sshConfig.persistence.volumes`                     | requires data persistence to be shared within all pods in the cluster, only ReadWriteMany is supported               | Check `values.yaml` file                                     |


### HPA parameters
#### Enable only when using a shared persistent storage!

| Parameter                                 | Description                                                                                                          | Default                                                      |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| `sshConfig.HPA.enabled`                             | Enable SSH Bastion Horizontal Pod Autoscaler                                                                         | `false`                                                      |
| `sshConfig.HPA.minReplicas`                         | Minimum desired number of replicas                                                                                   | `1`                                                          |
| `sshConfig.HPA.maxReplicas`                         | Minimum desired number of replicas                                                                                   | `14`                                                         |
| `sshConfig.HPA.cpuAvgUtil`                          | CPU average utilization                                                                                              | `50`                                                         |
| `sshConfig.HPA.memAvgUtil`                          | Memory average utilization                                                                                           | `50`                                                         |
                                                                                        
                       
