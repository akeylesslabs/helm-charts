{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "akeyless-api-gw.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "akeyless-api-gw.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "akeyless-api-gw.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "akeyless-api-gw.labels" -}}
helm.sh/chart: {{ include "akeyless-api-gw.chart" . }}
{{ include "akeyless-api-gw.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "akeyless-api-gw.selectorLabels" -}}
app.kubernetes.io/name: {{ include "akeyless-api-gw.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "akeyless-api-gw.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "akeyless-api-gw.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Set the default values of existing certificate files if not provided
*/}}
{{- define "akeyless-api-gw.certFileName" -}}
{{- default "akeyless-api-cert.crt" .Values.TLSConf.overrideCertFileName -}}
{{- end -}}

{{- define "akeyless-api-gw.keyFileName" -}}
{{- default "akeyless-api-cert.key" .Values.TLSConf.overrideKeyFileName -}}
{{- end -}}

{{/*
Get the Ingress TLS secret.
*/}}
{{- define "akeyless-api-gw.ingressSecretTLSName" -}}
    {{- if .existingSecret -}}
        {{- printf "%s" .existingSecret -}}
    {{- else -}}
        {{- printf "%s-tls" .hostname -}}
    {{- end -}}
{{- end -}}

{{- define "akeyless-api-gw.allowedAccessIDs" -}}
{{- join "," .Values.akeylessUserAuth.allowedAccessIDs }}
{{- end -}}

{{/*
Generate chart secret name
*/}}
{{- define "akeyless-api-gw.secretName" -}}
    {{- if .Values.existingSecret -}}
        {{- printf "%s" .Values.existingSecret -}}
    {{- else -}}
        {{- printf "%s-conf-secret" $.Release.Name -}}
    {{- end -}}
{{- end -}}

{{- define "akeyless-api-gw.tlsSecretName" -}}
    {{- if .Values.TLSConf.tlsExistingSecretName -}}
        {{- printf "%s" .Values.TLSConf.tlsExistingSecretName -}}
    {{- else -}}
        {{ $.Release.Name }}-conf-tls
    {{- end -}}
{{- end -}}

{{- define "akeyless-api-gw.logandSecretName" -}}
    {{- if .Values.logandExistingSecretName -}}
        {{- printf "%s" .Values.logandExistingSecretName -}}
    {{- else -}}
        logand-conf
    {{- end -}}
{{- end -}}

{{- define "akeyless-api-gw.cacheSecretName" -}}
        {{ $.Release.Name }}-cache-secret
{{- end -}}

{{- define "akeyless-api-gw.clusterCacheEncryptionKeyExist" -}}
        {{- if .Values.cachingConf.clusterCache.encryptionKeyExistingSecret -}}
            {{- printf "%s" .Values.cachingConf.clusterCache.encryptionKeyExistingSecret -}}
        {{- end -}}
{{- end -}}

{{- define "akeyless-api-gw.redisMaxmemory" -}}
{{- default "2gb" .Values.cache.maxmemory -}}
{{- end -}}

{{/*
Check customer fragment
*/}}

{{- define "akeyless-api-gw.root.config.path" -}}
{{- if or (.Values.akeylessStrictMode) (hasSuffix "-akeyless" .Values.image.tag)   }}
     {{- printf "/home/akeyless" -}}
{{- else }}
     {{- printf "/root" -}}
{{- end -}}
{{- end -}}
{{- define "akeyless-api-gw.customerFragmentExist" -}}
    {{- if .Values.customerFragments -}}
        {{ include "akeyless-api-gw.secretName" . }}
    {{- else if .Values.customerFragmentsEncoded -}}
        {{ include "akeyless-api-gw.secretName" . }}
    {{- else if .Values.customerFragmentsExistingSecret -}}
        {{- printf "%s" .Values.customerFragmentsExistingSecret -}}
    {{- else if .Values.customerFragmentsEncodedExistingSecret -}}
        {{- printf "%s" .Values.customerFragmentsEncodedExistingSecret -}}
    {{- else if and (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" .)) .Values.existingSecret -}}
        {{- if hasKey (get (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" . )) "data") "customer-fragments" -}}
            {{ include "akeyless-api-gw.secretName" . }}
        {{- end -}}
    {{- end -}}
{{- end -}}

{{/*
Check admin access-id 
*/}}
{{- define "akeyless-api-gw.adminAccessIdExist" -}}
    {{- if .Values.akeylessUserAuth.adminAccessId -}}
        {{ include "akeyless-api-gw.secretName" . }}
    {{- else if .Values.akeylessUserAuth.adminAccessIdExistingSecret -}}
        {{- printf "%s" .Values.akeylessUserAuth.adminAccessIdExistingSecret -}}
    {{- else if and (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" .)) .Values.existingSecret -}}
        {{- if hasKey (get (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" . )) "data") "admin-access-id" -}}
            {{ include "akeyless-api-gw.secretName" . }}
        {{- end -}}
    {{- end -}}
{{- end -}}

{{/*
Check admin access-id 
*/}}
{{- define "akeyless-api-gw.adminAccessUidExist" -}}
    {{- if .Values.akeylessUserAuth.adminUIDInitToken -}}
        {{ include "akeyless-api-gw.secretName" . }}
    {{- else if .Values.akeylessUserAuth.adminUIDInitTokenExistingSecret -}}
        {{- printf "%s" .Values.akeylessUserAuth.adminUIDInitTokenExistingSecret -}}
    {{- else if and (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" .)) .Values.existingSecret -}}
        {{- if hasKey (get (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" . )) "data") "admin-uid-init-token" -}}
            {{ include "akeyless-api-gw.secretName" . }}
        {{- end -}}
    {{- end -}}
{{- end -}}

{{/*
Check allowed Access IDs 
*/}}
{{- define "akeyless-api-gw.allowedAccessIDsExist" -}}
    {{- if .Values.akeylessUserAuth.allowedAccessIDs -}}
        {{ include "akeyless-api-gw.secretName" . }}
    {{- else if .Values.akeylessUserAuth.allowedAccessIDsExistingSecret -}}
        {{- printf "%s" .Values.akeylessUserAuth.allowedAccessIDsExistingSecret -}}
    {{- else if and (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" .)) .Values.existingSecret -}}
        {{- if hasKey (get (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" . )) "data") "allowed-access-ids" -}}
            {{ include "akeyless-api-gw.secretName" . }}
        {{- end -}}
    {{- end -}}
{{- end -}}

{{- define "akeyless-api-gw.allowedAccessPermissionsExist" -}}
    {{- if .Values.akeylessUserAuth.allowedAccessPermissions -}}
        {{ include "akeyless-api-gw.secretName" . }}
    {{- else if .Values.akeylessUserAuth.allowedAccessPermissionsExistingSecret -}}
        {{- printf "%s" .Values.akeylessUserAuth.allowedAccessPermissionsExistingSecret -}}
    {{- else if and (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" .)) .Values.existingSecret -}}
        {{- if hasKey (get (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" . )) "data") "allowed-access-permissions" -}}
            {{ include "akeyless-api-gw.secretName" . }}
        {{- end -}}
    {{- end -}}
{{- end -}}

{{/*
Check admin access-key
*/}}
{{- define "akeyless-api-gw.adminAccessKeyExist" -}}
    {{- if .Values.akeylessUserAuth.adminAccessKey -}}
        {{ include "akeyless-api-gw.secretName" . }}
    {{- else if .Values.akeylessUserAuth.adminAccessKeyExistingSecret -}}
        {{- printf "%s" .Values.akeylessUserAuth.adminAccessKeyExistingSecret -}}
    {{- else if and (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" .)) .Values.existingSecret -}}
        {{- if hasKey (get (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" . )) "data") "admin-access-key" -}}
            {{ include "akeyless-api-gw.secretName" . }}
        {{- end -}}
    {{- end -}}
{{- end -}}

{{/*
Check admin password
*/}}
{{- define "akeyless-api-gw.adminPasswordExist" -}}
    {{- if .Values.akeylessUserAuth.adminPassword -}}
        {{ include "akeyless-api-gw.secretName" . }}
    {{- else if .Values.akeylessUserAuth.adminPasswordExistingSecret -}}
        {{- printf "%s" .Values.akeylessUserAuth.adminPasswordExistingSecret -}}
    {{- else if and (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" .)) .Values.existingSecret -}}
        {{- if hasKey (get (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" . )) "data") "admin-password" -}}
            {{ include "akeyless-api-gw.secretName" . }}
        {{- end -}}
    {{- end -}}
{{- end -}}

{{/*
Check admin cert
*/}}
{{- define "akeyless-api-gw.adminAccessCertExist" -}}
    {{- if .Values.akeylessUserAuth.adminBase64Certificate -}}
        {{ include "akeyless-api-gw.secretName" . }}
    {{- else if .Values.akeylessUserAuth.adminBase64CertificateExistingSecret -}}
        {{- printf "%s" .Values.akeylessUserAuth.adminBase64CertificateExistingSecret -}}
    {{- else if and (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" .)) .Values.existingSecret -}}
        {{- if hasKey (get (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" . )) "data") "admin-certificate" -}}
            {{ include "akeyless-api-gw.secretName" . }}
        {{- end -}}
    {{- end -}}
{{- end -}}

{{/*
Check admin cert-key
*/}}
{{- define "akeyless-api-gw.adminAccessCertKeyExist" -}}
    {{- if .Values.akeylessUserAuth.adminBase64CertificateKey -}}
        {{ include "akeyless-api-gw.secretName" . }}
    {{- else if .Values.akeylessUserAuth.adminBase64CertificateKeyExistingSecret -}}
        {{- printf "%s" .Values.akeylessUserAuth.adminBase64CertificateKeyExistingSecret -}}
    {{- else if and (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" .)) .Values.existingSecret -}}
        {{- if hasKey (get (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" . )) "data") "admin-certificate-key" -}}
            {{ include "akeyless-api-gw.secretName" . }}
        {{- end -}}
    {{- end -}}
{{- end -}}

{{/*
Check logand conf
*/}}
{{- define "akeyless-api-gw.logandConfExist" -}}
    {{- if  or .Values.logandConf .Values.logandExistingSecretName -}}
        {{- printf "true" -}}
    {{- else -}}
        {{- printf "false" -}}
    {{- end -}}
{{- end -}}

{{/*
Check tlsCertificate
*/}}
{{- define "akeyless-api-gw.tlsCertificateExist" -}}
    {{- if .Values.TLSConf.tlsCertificate -}}
        {{- printf "true" -}}
    {{- else if and (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.tlsSecretName" .)) .Values.TLSConf.tlsExistingSecretName -}}
        {{- if hasKey (get (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.tlsSecretName" . )) "data") ( default "akeyless-api-cert.crt" .Values.TLSConf.overrideCertFileName ) -}}
            {{- printf "true" -}}
        {{- else -}}
            {{- printf "false" -}}
        {{- end -}}
    {{- else -}}
        {{- printf "false" -}}
    {{- end -}}
{{- end -}}

{{/*
Check tlsPrivateKey
*/}}
{{- define "akeyless-api-gw.tlsPrivateKeyExist" -}}
    {{- if .Values.TLSConf.tlsPrivateKey -}}
        {{- printf "true" -}}
    {{- else if and (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.tlsSecretName" .)) .Values.TLSConf.tlsExistingSecretName -}}
        {{- if hasKey (get (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.tlsSecretName" . )) "data") ( default "akeyless-api-cert.key" .Values.TLSConf.overrideKeyFileName ) -}}
            {{- printf "true" -}}
        {{- else -}}
            {{- printf "false" -}}
        {{- end -}}
    {{- else -}}
        {{- printf "false" -}}
    {{- end -}}
{{- end -}} 

{{/*
Checks kubernetes API version support for ingress BC
*/}}
{{- define "checkIngressVersion.ingress.apiVersion" -}}
  {{- if .Capabilities.APIVersions.Has "networking.k8s.io/v1" -}}
      {{- print "networking.k8s.io/v1" -}}
  {{- else if .Capabilities.APIVersions.Has "networking.k8s.io/v1beta1" -}}
    {{- print "networking.k8s.io/v1beta1" -}}
  {{- else -}}
    {{- print "extensions/v1beta1" -}}
  {{- end -}}
{{- end -}}

{{/*
Get serviceAccountName
*/}}
{{- define "akeyless-api-gw.getServiceAccountName" -}}
    {{- if and (not .Values.deployment.service_account.serviceAccountName) ( not .Values.deployment.service_account.create )  }}
        {{- printf "default" -}}
    {{- else if not .Values.deployment.service_account.serviceAccountName }}
        {{- printf "%s-akeyless-gateway" .Release.Name }}
    {{- else -}}
        {{- printf "%s" $.Values.deployment.service_account.serviceAccountName }}
    {{- end -}}
{{- end -}}

{{/*
Get metrics secret name 
*/}}
{{- define "akeyless-api-gw.metricsSecretName" -}}
    {{- if .Values.metrics.existingSecretName -}}
        {{- printf "%s" .Values.metrics.existingSecretName -}}
    {{- else -}}
        {{- printf "%s-metrics-conf" $.Release.Name -}}
    {{- end -}}
{{- end -}}

{{/*
Check metrics configuration Secret
*/}}
{{- define "akeyless-api-gw.metricsSecretExist" -}}
    {{- if .Values.metrics.config -}}
        {{ include "akeyless-api-gw.metricsSecretName" . }}
    {{- else if .Values.metrics.existingSecretName -}}
        {{- printf "%s" .Values.metrics.existingSecretName -}}
    {{- else if and (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.metricsSecretName" .)) .Values.metrics.existingSecretName -}}  
        {{- if hasKey (get (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.metricsSecretName" . )) "data") "otel-config.yaml" -}}
            {{ include "akeyless-api-gw.metricsSecretName" . }}
        {{- end -}}
    {{- end -}}
{{- end -}}

{{- define "hpa.api.version" }}
    {{- if .Capabilities.APIVersions.Has "autoscaling/v2" }}
        {{- printf "autoscaling/v2" }}
    {{- else }}
        {{- printf "autoscaling/v2beta2" }}
    {{- end }}
{{- end }}

{{- define "deyploymant.type" -}}
    {{- if .Values.deploymentType -}}
        {{- if eq .Values.deploymentType "DaemonSet" -}}
            {{- printf "DaemonSet" -}}
        {{- else -}}
            {{- printf "Deployment" -}}
        {{- end -}}
    {{- else -}}
        {{- printf "Deployment" -}}
    {{- end -}}
{{- end -}}

{{- define "version" -}}
{{ .Values.version  | default .Chart.AppVersion | printf }}
{{- end }}

{{- define "health_check_path" -}}
{{- if not (regexMatch "^[0-9]+(\\.[0-9]+){2}$" (include "version" .)) -}}
/health
{{- else -}}
{{- $parts :=  split "." (include "version" .) -}}
{{- $major := index $parts "_0" | int }}
{{- $minor := index $parts "_1" | int }}
{{- $patch := index $parts "_2" | int }}
{{- if or (gt $major 4) (and (eq $major 4) (or (gt $minor 10) (and (eq $minor 10) (ge $patch 0)))) -}}
/health
{{- else -}}
/
{{- end }}
{{- end }}
{{- end }}