{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}

{{- define "akeyless-secure-remote-access.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}

{{- define "akeyless-secure-remote-access.fullname" -}}
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
{{- define "akeyless-secure-remote-access.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}

{{- define "akeyless-secure-remote-access.labels" -}}
helm.sh/chart: {{ include "akeyless-secure-remote-access.chart" . }}
{{ include "akeyless-secure-remote-access.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}

{{- define "akeyless-secure-remote-access.selectorLabels" -}}
app.kubernetes.io/name: {{ include "akeyless-secure-remote-access.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Get the Ingress TLS secret.
*/}}
{{- define "akeyless-zero-trust-bastion.ingressSecretTLSName" -}}
    {{- if .Values.ztbConfig.ingress.existingSecret -}}
        {{- printf "%s" .Values.ztbConfig.ingress.existingSecret -}}
    {{- else -}}
        {{- printf "%s-tls" .Values.ztbConfig.ingress.hostname -}}
    {{- end -}}
{{- end -}}

{{/*
Generate chart secret name
*/}}
{{- define "akeyless-zero-trust-bastion.secretName" -}}
{{ default (include "akeyless-secure-remote-access.fullname" .) .Values.ztbConfig.config.rdpRecord.existingSecret }}
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
Checks persistent volume
*/}}
{{- define "checkPersistenceVolume" -}}
  {{ range .Values.sshConfig.persistence.volumes }}
    {{- $used := .name -}}
    {{- if $used }}
      {{- printf "true" }}
    {{- end }}  
  {{- end }}
{{- end }}



{{/*
Get serviceAccountName
*/}}
{{- define "akeyless-api-gw.getServiceAccountName" -}}
    {{- if .Values.sshConfig.service_account}}
        {{- if and (not .Values.sshConfig.service_account.serviceAccountName) ( not .Values.sshConfig.service_account.create )  }}
            {{- printf "default" -}}
        {{- else if not .Values.sshConfig.service_account.serviceAccountName }}
            {{.Release.Name}}-secure-remote-access
        {{- else }}
            {{- printf .Values.sshConfig.service_account.serviceAccountName}}
    {{- end -}}
    {{- else if .Values.privilegedAccess.serviceAccount }}
        {{- if and (not .Values.privilegedAccess.serviceAccount.serviceAccountName) ( not .Values.privilegedAccess.serviceAccount.create ) }}
            {{- printf "default" }}
        {{- else if not .Values.privilegedAccess.serviceAccount.serviceAccountName }}
            {{.Release.Name}}-secure-remote-access
        {{- else }}
            {{- printf .Values.privilegedAccess.serviceAccount.serviceAccountName}}
        {{- end -}}
    {{- end }}
{{- end -}}
{{- define "hpa.api.version" }}
    {{- if .Capabilities.APIVersions.Has "autoscaling/v2" }}
        {{- printf "autoscaling/v2" }}
    {{- else }}
        {{- printf "autoscaling/v2beta2" }}
    {{- end }}
{{- end }}

{{- define "secret-exist" }}
  {{- if .Root }}
    {{- if (get .Root .Name) }}
        {{- print "true" -}}
    {{- else }}
       {{- print "false" -}}
    {{- end }}
  {{- else }}
    {{- print "false" -}}
  {{- end }}
{{- end }}

{{- define "akeyless-zero-trust-portal.getServiceAccountName" -}}
    {{- if .Values.ztpConfig.service_account}}
        {{- if and (not .Values.ztpConfig.service_account.serviceAccountName) ( not .Values.ztpConfig.service_account.create )  }}
            {{- printf "default" -}}
        {{- else if not .Values.ztpConfig.service_account.serviceAccountName }}
            {{.Release.Name}}-zero-trust-portal
        {{- else }}
            {{- printf .Values.ztpConfig.service_account.serviceAccountName}}
    {{- end -}}
    {{- else if .Values.privilegedAccess.serviceAccount }}
        {{- if and (not .Values.privilegedAccess.serviceAccount.serviceAccountName) ( not .Values.privilegedAccess.serviceAccount.create ) }}
            {{- printf "default" }}
        {{- else if not .Values.privilegedAccess.serviceAccount.serviceAccountName }}
            {{.Release.Name}}-zero-trust-portal
        {{- else }}
            {{- printf .Values.privilegedAccess.serviceAccount.serviceAccountName}}
        {{- end -}}
    {{- end }}
{{- end -}}

{{/*
Get the Ingress TLS secret.
*/}}
{{- define "akeyless-zero-trust-portal.ingressSecretTLSName" -}}
    {{- if .Values.ztpConfig.ingress.existingSecret -}}
        {{- printf "%s" .Values.ztpConfig.ingress.existingSecret -}}
    {{- else -}}
        {{- printf "%s-tls" .Values.ztpConfig.ingress.hostname -}}
    {{- end -}}
{{- end -}}

{{- define "akeylessTenantUrl" -}}
{{- default "akeyless.io" .Values.ztpConfig.akeylessTenantUrl -}}
{{- end -}}

{{- define "akeyless-zero-trust-portal.storageSecretName" -}}
        {{ $.Release.Name }}-storage-secret
{{- end -}}

{{- define "akeyless-zero-trust-portal.redisStorageImage" -}}
    {{- if .Values.redisStorage.image -}}
        image: "{{ .Values.redisStorage.image.repository }}:{{ .Values.redisStorage.image.tag }}"
        imagePullPolicy: {{ .Values.redisStorage.image.pullPolicy }}
    {{- else }}
        image: "docker.io/bitnami/redis:6.2"
        imagePullPolicy: "Always"
    {{- end -}}
{{- end -}}