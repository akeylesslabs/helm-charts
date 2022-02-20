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
