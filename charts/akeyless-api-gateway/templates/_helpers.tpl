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
        {{ $.Release.Name }}-conf-secret
    {{- end -}}
{{- end -}}

{{- define "akeyless-api-gw.tlsSecretName" -}}
        {{ $.Release.Name }}-conf-tls
{{- end -}}

{{- define "akeyless-api-gw.cacheSecretName" -}}
        {{ $.Release.Name }}-cache-secret
{{- end -}}

{{/*
Check customer fragment
*/}}
{{- define "akeyless-api-gw.customerFragmentExist" -}}
    {{- if .Values.customerFragments -}}
        {{- printf "true" -}}
    {{- else if and (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" .)) .Values.existingSecret -}}
        {{- if hasKey (get (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" . )) "data") "customer-fragments" -}}
            {{- printf "true" -}}
        {{- else -}}
            {{- printf "false" -}}
        {{- end -}}
    {{- else -}}
        {{- printf "false" -}}
    {{- end -}}
{{- end -}}

{{/*
Check admin access-id 
*/}}
{{- define "akeyless-api-gw.adminAccessIdExist" -}}
    {{- if .Values.akeylessUserAuth.adminAccessId -}}
        {{- printf "true" -}}
    {{- else if and (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" .)) .Values.existingSecret -}}
        {{- if hasKey (get (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" . )) "data") "admin-access-id" -}}
            {{- printf "true" -}}
        {{- else -}}
            {{- printf "false" -}}
        {{- end -}}
    {{- else -}}
        {{- printf "false" -}}
    {{- end -}}
{{- end -}}

{{/*
Check admin access-id 
*/}}
{{- define "akeyless-api-gw.adminAccessUidExist" -}}
    {{- if .Values.akeylessUserAuth.adminUIDInitToken -}}
        {{- printf "true" -}}
    {{- else if and (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" .)) .Values.existingSecret -}}
        {{- if hasKey (get (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" . )) "data") "admin-uid-init-token" -}}
            {{- printf "true" -}}
        {{- else -}}
            {{- printf "false" -}}
        {{- end -}}
    {{- else -}}
        {{- printf "false" -}}
    {{- end -}}
{{- end -}}

{{/*
Check allowed Access IDs 
*/}}
{{- define "akeyless-api-gw.allowedAccessIDsExist" -}}
    {{- if .Values.akeylessUserAuth.allowedAccessIDs -}}
        {{- printf "true" -}}
    {{- else if and (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" .)) .Values.existingSecret -}}
        {{- if hasKey (get (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" . )) "data") "allowed-access-ids" -}}
            {{- printf "true" -}}
        {{- else -}}
            {{- printf "false" -}}
        {{- end -}}
    {{- else -}}
        {{- printf "false" -}}
    {{- end -}}
{{- end -}}

{{/*
Check admin access-key
*/}}
{{- define "akeyless-api-gw.adminAccessKeyExist" -}}
    {{- if .Values.akeylessUserAuth.adminAccessKey -}}
        {{- printf "true" -}}
    {{- else if and (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" .)) .Values.existingSecret -}}
        {{- if hasKey (get (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" . )) "data") "admin-access-key" -}}
            {{- printf "true" -}}
        {{- else -}}
            {{- printf "false" -}}
        {{- end -}}
    {{- else -}}
        {{- printf "false" -}}
    {{- end -}}
{{- end -}}

{{/*
Check admin password
*/}}
{{- define "akeyless-api-gw.adminPasswordExist" -}}
    {{- if .Values.akeylessUserAuth.adminPassword -}}
        {{- printf "true" -}}
    {{- else if and (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" .)) .Values.existingSecret -}}
        {{- if hasKey (get (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" . )) "data") "admin-password" -}}
            {{- printf "true" -}}
        {{- else -}}
            {{- printf "false" -}}
        {{- end -}}
    {{- else -}}
        {{- printf "false" -}}
    {{- end -}}
{{- end -}}

{{/*
Check logand conf
*/}}
{{- define "akeyless-api-gw.logandConfExist" -}}
    {{- if .Values.logandConf -}}
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
    {{- else if and (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" .)) .Values.existingSecret -}}
        {{- if hasKey (get (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" . )) "data") "tls-certificate" -}}
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
    {{- else if and (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" .)) .Values.existingSecret -}}
        {{- if hasKey (get (lookup "v1" "Secret" .Release.Namespace (include "akeyless-api-gw.secretName" . )) "data") "tls-private-key" -}}
            {{- printf "true" -}}
        {{- else -}}
            {{- printf "false" -}}
        {{- end -}}
    {{- else -}}
        {{- printf "false" -}}
    {{- end -}}
{{- end -}}