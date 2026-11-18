# Akeyless CSI Provider Helm Chart

This repository contains the official Akeyless Helm chart for installing Akeyless CSI Provider on Kubernetes.

## Prerequisites

To use the charts here, [Helm](https://helm.sh/) must be configured for your
Kubernetes cluster. Setting up Kubernetes and Helm is outside the scope of
this README. Please refer to the Kubernetes and Helm documentation.

The versions required are:

  * **Helm 3.0+** - This is the earliest version of Helm tested. It is possible
    it works with earlier versions but this chart is untested for those versions.
  * **Kubernetes 1.14+** - This is the earliest version of Kubernetes tested.
    It is possible that this chart works with earlier versions but it is
    untested.

## Usage

To install the latest version of this chart, add the Hashicorp helm repository
and run `helm install`:

```console
$ helm repo add akeyless https://akeylesslabs.github.io/helm-charts

```

## Azure Workload Identity

To authenticate the CSI provider to Akeyless with `azure_ad` (via `akeyless-go-cloud-id`
`DefaultAzureCredential`), configure AKS Workload Identity on the **provider** DaemonSet.
The Azure identity is that of the CSI provider pod, not individual application pods.

1. Create a user-assigned managed identity and federated identity credential whose
   `subject` matches the provider ServiceAccount
   (`system:serviceaccount:<namespace>:<release>-csi-provider`).
2. Set Helm values for the provider ServiceAccount annotation and pod label so the
   AKS Workload Identity webhook injects `AZURE_*` env vars into the provider pods.

```yaml
csi:
  serviceAccount:
    annotations:
      azure.workload.identity/client-id: "<MI_CLIENT_ID>"
  pod:
    labels:
      azure.workload.identity/use: "true"
```

In your `SecretProviderClass`, use `akeylessAccessType: azure_ad` and leave
`akeylessAzureObjectID` unset (empty) so token acquisition uses Workload Identity
rather than the Azure IMDS endpoint.

See also: [Akeyless CSI Provider](https://github.com/akeylesslabs/akeyless-csi-provider)
and [Akeyless Azure AD auth method](https://docs.akeyless.io/docs/azure-ad).
