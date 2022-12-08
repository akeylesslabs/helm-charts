# Akeyless Secrets Injection manifests

## Table of Contents

<!-- TOC -->
- [Table of Contents](#table-of-contents)
- [Description](#description)
- [Replacement Fields](#replacement-fields)
    - [Helm Functions Used](#helm-functions-used)
    - [Helm Function Explanation](#helm-function-explanation)
- [Output Directory](#output-directory)
<!-- /TOC -->

## Description

The output manifests for the Akeyless Secrets Injector deployment using mostly default values with the auth method type set to k8s authentication. Each time a new helm release is published, a workflow in this repository will be triggered to output new manifests through a pull request to better visualize the changes.

## Replacement Fields

The [Helm Chart for the Akeyless Secrets Injector](https://github.com/akeylesslabs/helm-charts/tree/main/charts/akeyless-k8s-secrets-injection) automatically generate several cryptographic tools using built-in functions that will need to be replaced by an external process.

In order to help make replacing these built-in tools easier we may need to explain what they are doing and how the deployment utilizes them.

You can search for the phrase `replaceMe` to find inputs that need to be replaced for a successful deployment.

### Helm Functions Used

The following helm functions are used within the `Secret` kind manifest as well as the `MutatingWebhookConfiguration` manifest

```yaml
{{ $ca := genCA "svc-cat-ca" 3650 }}
{{ $svcName := include "vault-secrets-webhook.fullname" . }}
{{ $cn := printf "%s.%s.svc" $svcName .Release.Namespace }}
{{ $server := genSignedCert $cn nil (list $cn "") 365 $ca }}
```

### Helm Function Explanation

```yaml
{{ $ca := genCA "svc-cat-ca" 3650 }}
```

Helm Docs:
The `genCA` function generates a new, self-signed x509 certificate authority.

It takes the following parameters:

Subject's common name (cn)
Cert validity duration in days

Akeyless Explanation:
The "Subject's common name" is set to `svc-cat-ca` and the expiration is set to 3650 days

```yaml
{{ $svcName := include "vault-secrets-webhook.fullname" . }}
```

Akeyless Explanation:
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
`$svcName` is only used within the `Secret` manifest on the data properties `servingCert` and `servingKey` as part of the generated signed cert.

```yaml
{{ $cn := printf "%s.%s.svc" $svcName .Release.Namespace }}
```

Helm Docs:
Returns a string based on a formatting string and the arguments to pass to it in order.

```yaml
{{ $server := genSignedCert $cn nil (list $cn "") 365 $ca }}
```

Helm Docs:
The `genSignedCert` function generates a new, x509 certificate signed by the specified CA.

It takes the following parameters:

Subject's common name `(cn)`
Optional list of IPs; may be nil
Optional list of alternate DNS names; may be nil
Cert validity duration in days

## Output Directory

Manifests for the Akeyless Secrets Injector deployment are stored in this directory
