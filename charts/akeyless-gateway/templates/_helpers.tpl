{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "akeyless-gateway.name" -}}
    {{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "akeyless-gateway.fullname" -}}
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
{{- define "akeyless-gateway.chart" -}}
    {{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "akeyless-gateway.namePrefix" -}}
{{- if .Values.gateway.namePrefix -}}
{{- .Values.gateway.namePrefix -}}
{{- else -}}
unified
{{- end -}}
{{- end -}}

{{/*
Check provided imagePullSecrets
*/}}
{{- define "akeyless-gateway.imagePullSecrets" -}}
  {{- if not (empty .Values.gateway.deployment.image.imagePullSecrets) }}
    imagePullSecrets:
      - name: {{ printf "%s" .Values.gateway.deployment.image.imagePullSecrets }}
  {{- end -}}
{{- end -}}
{{- define "cache.imagePullSecrets" -}}
  {{- if not (empty .Values.globalConfig.clusterCache.imagePullSecrets) }}
    imagePullSecrets:
      - name: {{ printf "%s" .Values.globalConfig.clusterCache.imagePullSecrets }}
  {{- end -}}
{{- end -}}
{{/*
Common labels
*/}}
{{- define "akeyless-gateway.labels" -}}
helm.sh/chart: {{ include "akeyless-gateway.chart" . }}
{{ include "akeyless-gateway.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: Helm
app.kubernetes.io/part-of: {{ include "akeyless-gateway.name" . }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "akeyless-gateway.selectorLabels" -}}
app.kubernetes.io/name: {{ include "akeyless-gateway.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "akeyless-gateway.containerName" -}}
  {{- print "akeyless-gateway" -}}
{{- end -}}
{{/*
Create the name of the service account to use
*/}}
{{- define "akeyless-gateway.serviceAccountName" -}}
{{- if .Values.globalConfig.serviceAccount.create -}}
    {{ default (include "akeyless-gateway.fullname" .) .Values.globalConfig.serviceAccount.serviceAccountName }}
{{- else -}}
    {{ default "default" .Values.globalConfig.serviceAccount.serviceAccountName }}
{{- end -}}
{{- end -}}

{{/*
Get the Ingress TLS secret.
*/}}
{{- define "akeyless-gateway.ingressSecretTLSName" -}}
    {{- if .existingSecret -}}
        {{- printf "%s" .existingSecret -}}
    {{- else -}}
        {{- printf "%s-tls" .hostname -}}
    {{- end -}}
{{- end -}}

{{/*
Generate chart secret name
*/}}
{{- define "akeyless-gateway.secretName" -}}
    {{- if .Values.existingSecret -}}
        {{- printf "%s" .Values.existingSecret -}}
    {{- else -}}
        {{- printf "%s-conf-secret" $.Release.Name -}}
    {{- end -}}
{{- end -}}

{{- define "akeyless-gateway.clusterCacheImage" -}}
  {{- if .Values.globalConfig.clusterCache.image -}}
  {{- printf "image: %s:%s\n" (required "A valid .Values.globalConfig.clusterCache.image.repository entry required!" .Values.globalConfig.clusterCache.image.repository) (required "A valid .Values.globalConfig.clusterCache.image.tag entry required!" .Values.globalConfig.clusterCache.image.tag | toString)  -}}
  {{- printf "imagePullPolicy: %s" (.Values.globalConfig.clusterCache.image.imagePullPolicy | default "IfNotPresent"  | quote ) -}}
  {{- else -}}
  {{- printf "image: %s\n" ("public.ecr.aws/docker/library/redis:8.2.2-alpine" | quote) -}}
  {{- printf "imagePullPolicy: %s\n" ("IfNotPresent" | quote) -}}
  {{- end -}}
{{- end -}}

{{/* Define REDIS_MAXMEMORY as 80% of the pod's memory limit */}}
{{- define "akeyless-gateway.redisMaxmemory" -}}
{{- $memoryLimit := .Values.globalConfig.clusterCache.resources.limits.memory | toString -}}
{{- $memoryLimitBytes := 0 -}}
{{- if regexMatch "^[0-9]+$" $memoryLimit -}}
  {{- $memoryLimitBytes = $memoryLimit | mulf 1 -}} {{/* Direct byte value */}}
{{- else if regexMatch "^[0-9]+Gi$" $memoryLimit -}}
  {{- $memoryLimitBytes = (trimSuffix "Gi" $memoryLimit | mulf 1073741824) -}} {{/* GiB to bytes */}}
{{- else if regexMatch "^[0-9]+Mi$" $memoryLimit -}}
  {{- $memoryLimitBytes = (trimSuffix "Mi" $memoryLimit | mulf 1048576) -}} {{/* MiB to bytes */}}
{{- else if regexMatch "^[0-9]+[M]$" $memoryLimit -}}
    {{- $memoryLimitBytes = (trimSuffix "M" $memoryLimit | mulf 1048576) -}} {{/* Megabytes to bytes */}}
{{- else if regexMatch "^[0-9]+e[0-9]+$" $memoryLimit -}}
  {{- $memoryLimitBytes = $memoryLimit | mulf 1 -}} {{/* Handle scientific notation (e.g., 129e6) */}}
{{- else if regexMatch "^[0-9]+[kK]$" $memoryLimit -}}
  {{- $memoryLimitBytes = (trimSuffix "k" $memoryLimit | mulf 1024) -}} {{/* Kilobytes to bytes */}}
{{- else -}}
  {{- fail "Unsupported memory format" -}}
{{- end -}}
{{- $redisMaxmemory := $memoryLimitBytes | mulf 0.8 | floor -}}  {{/* Calculate 80% and round down */}}
{{- $redisMaxmemory | printf "%.0f" -}}  {{/* Print the value as an integer */}}
{{- end -}}

{{- define "akeyless-gateway.clusterCache.secretName" -}}
  {{- if empty .Values.globalConfig.clusterCache.cachePasswordExistingSecret }}
  {{- printf "%s-cache-secret" $.Release.Name -}}
  {{- else if not (empty .Values.globalConfig.clusterCache.cachePasswordExistingSecret) }}
    {{- printf "%s" .Values.globalConfig.clusterCache.cachePasswordExistingSecret }}
  {{- end }}
{{- end }}

{{- define "akeyless-gateway.clusterCache.enabled" -}}
{{- if or (eq .Values.globalConfig.gatewayAuth.gatewayAccessType "uid") (ne .Values.globalConfig.clusterCache.enabled false) .Values.cacheHA.enabled -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "akeyless-gateway.clusterCache.labels" -}}
name: {{ include "akeyless-gateway.clusterCache.SvcName" . }}
component: cache
{{- end }}

{{- define "akeyless-gateway.clusterCache.enableTls" -}}
  {{- if .Values.cacheHA.enabled -}}
    {{- and .Values.cacheHA.redis.tlsPort .Values.cacheHA.enabled -}}
  {{- else -}}
    {{- and .Values.globalConfig.clusterCache.enableTls (include "akeyless-gateway.clusterCache.enabled" .) -}}
  {{- end -}}
{{- end }}

{{- define "akeyless-gateway.clusterCache.pvcName" -}}
  {{- printf "%s-cache" (include "akeyless-gateway.fullname" .) }}
{{- end -}}

{{- define "akeyless-gateway.cache-ha.fullname" -}}
  {{- if .Values.cacheHA.enabled -}}
    {{- if contains .Values.cacheHA.nameOverride .Release.Name -}}
      {{- printf "%s" (.Release.Name | trunc 63 | trimSuffix "-") -}}
    {{- else -}}
      {{- printf "%s-%s" .Release.Name (.Values.cacheHA.nameOverride | default "cache-ha") -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "akeyless-gateway.clusterCache.generatedCacheTlsSecretName" -}}
{{- if .Values.cacheHA.enabled -}}
{{- printf "%s-crt" (include "akeyless-gateway.cache-ha.fullname" .) }}
{{- else -}}
{{- printf "%s-crt" (include "akeyless-gateway.fullname" .) }}
{{- end -}}
{{- end -}}

{{- define "akeyless-gateway.clusterCache.cacheTlsSecretName" -}}
{{- if .Values.cacheHA.enabled -}}
{{- printf "%s" (tpl .Values.cacheHA.tls.secretName .) }}
{{- else -}}
{{- default (include "akeyless-gateway.clusterCache.generatedCacheTlsSecretName" .) "" }}
{{- end -}}
{{- end -}}


{{- define "akeyless-gateway.clusterCache.SvcName" -}}
{{- printf "%s-cache-svc" (include "akeyless-gateway.fullname" .) -}}
{{- end -}}

{{- define "akeyless-gateway.clusterCache.cacheAddress" -}}
{{- $serviceName := (include "akeyless-gateway.clusterCache.SvcName" .) }}
{{- $port := 6379 }}
{{- if .Values.cacheHA.enabled -}}
{{- $serviceName = (include "redis-ha.fullname" .Subcharts.cacheHA) }}
{{- $port = .Values.cacheHA.redis.port }}
{{- if eq (include "akeyless-gateway.clusterCache.enableTls" .) "true" -}}
{{- $port = .Values.cacheHA.redis.tlsPort }}
{{- end -}}
{{- end -}}
{{- printf "%s.%s.svc:%v" $serviceName .Release.Namespace $port }}
{{- end -}}

{{- define "akeyless-gateway.clusterCache.sentinelAddress" -}}
{{- $port := .Values.cacheHA.sentinel.port }}
{{- $serviceName := (include "akeyless-gateway.clusterCache.SvcName" .) }}
{{- if eq (include "akeyless-gateway.clusterCache.enableTls" .) "true" -}}
{{- $port = .Values.cacheHA.sentinel.tlsPort }}
{{- end -}}
{{- if .Values.cacheHA.enabled -}}
{{- $serviceName = (include "redis-ha.fullname" .Subcharts.cacheHA) }}
{{- end -}}
{{- printf "%s.%s.svc:%v" $serviceName .Release.Namespace $port }}
{{- end -}}

{{- define "akeyless-gateway.clusterCache.tlsVolume" -}}
- name: cache-tls
  secret:
    secretName: {{ include "akeyless-gateway.clusterCache.cacheTlsSecretName" . }}
{{- end -}}

{{- define "akeyless-gateway.clusterCache.tlsVolumeMountPath" -}}
/opt/akeyless/cache/certs
{{- end -}}

{{- define "akeyless-gateway.clusterCache.tlsVolumeMounts" -}}
- name: cache-tls
  mountPath: {{ include "akeyless-gateway.clusterCache.tlsVolumeMountPath" . }}
  readOnly: true
{{- end -}}

{{- define "akeyless-gateway.clusterCache.password" }}
{{- /*### REDIS_PASS instead of REDIS_PASSWORD due to bc*/}}
  - name: REDIS_PASS
    valueFrom:
      secretKeyRef:
{{- if .Values.cacheHA.enabled }}
        name: {{ if .Values.cacheHA.existingSecret }}{{ tpl .Values.cacheHA.existingSecret . }}{{else}}{{ printf "%s" (include "akeyless-gateway.cache-ha.fullname" .) }}{{end}}
        key: {{ .Values.cacheHA.authKey }}
{{- else }}
        name: {{ include "akeyless-gateway.clusterCache.secretName" . }}
        key: cache-pass
{{- end -}}
{{- end -}}

{{- define "akeyless-gateway.enableScaleOutOnDisconnectedMode" -}}
{{- if eq (.Values.globalConfig.clusterCache.enableScaleOutOnDisconnectedMode | default false) true -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{- define "akeyless-gateway.useEncryptionKeyExistingSecret" -}}
{{- if or .Values.globalConfig.clusterCache.encryptionKeyExistingSecret .Values.cacheHA.encryptionKeyExistingSecret -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{- define "akeyless-gateway.clusterCacheEncryptionKeySecret" -}}
    {{- if eq "true" (include "akeyless-gateway.useEncryptionKeyExistingSecret" .) -}}
        {{- if .Values.globalConfig.clusterCache.encryptionKeyExistingSecret -}}
            {{- .Values.globalConfig.clusterCache.encryptionKeyExistingSecret -}}
        {{- else -}}
            {{- .Values.cacheHA.encryptionKeyExistingSecret -}}
        {{- end -}}
    {{- else if (and
      (eq "true" (include "akeyless-gateway.enableScaleOutOnDisconnectedMode" .))
      (eq "true" (include "akeyless-gateway.clusterCache.enabled" .))
    ) -}}
      {{- printf "%s-cache-encryption-key" $.Release.Name -}}
    {{- end -}}
{{- end -}}

{{- define "akeyless-gateway.clusterCacheConfig" }}
  - name: USE_CLUSTER_CACHE
    value: "true"
  - name: REDIS_ADDR
    value: {{ include "akeyless-gateway.clusterCache.cacheAddress" . }}
  - name: ENABLE_CACHE_TLS
    value: {{ include "akeyless-gateway.clusterCache.enableTls" . | quote }}
  {{- if (eq "true" (include "akeyless-gateway.clusterCache.enableTls" . )) }}
  - name: CACHE_REDIS_CA_PATH
    value: "{{ printf "%s/%s" (include "akeyless-gateway.clusterCache.tlsVolumeMountPath" .) .Values.cacheHA.tls.caCertFile }}"
  - name: CACHE_REDIS_KEY_PATH
    value: "{{ printf "%s/%s" (include "akeyless-gateway.clusterCache.tlsVolumeMountPath" .) .Values.cacheHA.tls.keyFile }}"
  - name: CACHE_REDIS_CERT_PATH
    value: "{{ printf "%s/%s" (include "akeyless-gateway.clusterCache.tlsVolumeMountPath" .) .Values.cacheHA.tls.certFile }}"
  {{- end }}
  - name: STORE_CACHE_ENCRYPTION_KEY_TO_K8S_SECRETS
    value: {{ include "akeyless-gateway.enableScaleOutOnDisconnectedMode" . | quote }}
  {{- if eq "true" (include "akeyless-gateway.enableScaleOutOnDisconnectedMode" .) }}
  {{- $secretName := include "akeyless-gateway.clusterCacheEncryptionKeySecret" . }}
  {{- if $secretName }}
  - name: CACHE_ENCRYPTION_KEY_SECRET_NAME
    value: {{ $secretName | quote }}
  {{- end }}
  {{- end }}
  {{- include "akeyless-gateway.clusterCache.password" . }}
{{- end -}}
{{/*
Check customer fragment
*/}}

{{- define "akeyless-gateway.root.config.path" -}}
{{- if not .Values.gatewayRootMode }}
    {{- printf "/home/akeyless" -}}
{{- else }}
    {{- printf "/root" -}}
{{- end -}}
{{- end -}}

{{/*
Check gateway access-id
*/}}
{{- define "akeyless-gateway.gatewayAccessIdExist" -}}
    {{- if .Values.globalConfig.gatewayAuth.gatewayAccessId -}}
        {{ include "akeyless-gateway.secretName" . }}
    {{- else if .Values.globalConfig.gatewayAuth.gatewayCredentialsExistingSecret -}}
        {{- printf "%s" .Values.globalConfig.gatewayAuth.gatewayCredentialsExistingSecret -}}
    {{- end -}}
{{- end -}}

{{- define "akeyless-gateway.allowedAccessPermissionsExist" -}}
    {{- if .Values.globalConfig.allowedAccessPermissions -}}
        {{ include "akeyless-gateway.secretName" . }}
    {{- else if .Values.globalConfig.allowedAccessPermissionsExistingSecret -}}
        {{- printf "%s" .Values.globalConfig.allowedAccessPermissionsExistingSecret -}}
    {{- end -}}
{{- end -}}

{{/*
check gateway auth config
*/}}
{{- define "akeyless-gateway.akeylessGatewayAuthConfig" }}
  - name: GATEWAY_ACCESS_TYPE
    value: {{ .Values.globalConfig.gatewayAuth.gatewayAccessType }}
  {{- if not (eq (include "akeyless-gateway.gatewayAccessIdExist" .) "") }}
  - name: GATEWAY_ACCESS_ID
    valueFrom:
      secretKeyRef:
        name: {{ include "akeyless-gateway.gatewayAccessIdExist" . }}
        key: gateway-access-id
  {{- end }}
  {{- if eq .Values.globalConfig.gatewayAuth.gatewayAccessType "access_key" }}
  - name: GATEWAY_ACCESS_KEY
    valueFrom:
      secretKeyRef:
        name: {{ .Values.globalConfig.gatewayAuth.gatewayCredentialsExistingSecret }}
        key: gateway-access-key
  {{- end }}
{{- end -}}

{{- define "akeyless-gateway.ClusterName" -}}
  {{- if .Values.globalConfig.clusterName }}
  - name: CLUSTER_NAME
    value: {{ .Values.globalConfig.clusterName }}
  {{- end }}
{{- end -}}


{{/*
Get serviceAccountName
*/}}
{{- define "akeyless-gateway.getServiceAccountName" -}}
    {{- if and (not .Values.globalConfig.serviceAccount.serviceAccountName) ( not .Values.globalConfig.serviceAccount.create )  }}
        {{- printf "default" -}}
    {{- else if not .Values.globalConfig.serviceAccount.serviceAccountName }}
        {{- printf "%s-akeyless-gateway" .Release.Name }}
    {{- else -}}
        {{- printf "%s" $.Values.globalConfig.serviceAccount.serviceAccountName }}
    {{- end -}}
{{- end -}}

{{- define "deployment.type" -}}
    {{- if .Values.gateway.deploymentType -}}
        {{- if eq .Values.gateway.deploymentType "DaemonSet" -}}
            {{- printf "DaemonSet" -}}
        {{- else -}}
            {{- printf "Deployment" -}}
        {{- end -}}
    {{- else -}}
        {{- printf "Deployment" -}}
    {{- end -}}
{{- end -}}

{{/*
Akeyless sra imagePullSecrets
*/}}
{{- define "akeyless-sra.imagePullSecrets" -}}
  {{- if not (empty .Values.sra.image.imagePullSecrets) }}
    imagePullSecrets:
      - name: {{ printf "%s" .Values.sra.image.imagePullSecrets }}
  {{- end -}}
{{- end -}}

{{/*
Akeyless sra web Common labels
*/}}

{{- define "akeyless-sra-web.labels" -}}
helm.sh/chart: {{ include "akeyless-gateway.chart" . }}
{{ include "akeyless-sra-web.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: Helm
app.kubernetes.io/part-of: {{ include "akeyless-gateway.name" . }}
{{- end -}}

{{/*
Selector web labels
*/}}

{{- define "akeyless-sra-web.selectorLabels" -}}
app.kubernetes.io/name: {{ (include "akeyless-gateway.name" .) | trunc 54 | trimSuffix "-" }}-sra-web
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Akeyless sra web Common labels
*/}}

{{- define "akeyless-sra-ssh.labels" -}}
helm.sh/chart: {{ include "akeyless-gateway.chart" . }}
{{ include "akeyless-sra-ssh.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: Helm
app.kubernetes.io/part-of: {{ include "akeyless-gateway.name" . }}
{{- end -}}

{{/*
Selector ssh labels
*/}}

{{- define "akeyless-sra-ssh.selectorLabels" -}}
app.kubernetes.io/name: {{ (include "akeyless-gateway.name" .) | trunc 54 | trimSuffix "-" }}-sra-ssh
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{/*
Get the Ingress TLS secret.
*/}}
{{- define "web-access-sra.ingressSecretTLSName" -}}
    {{- if .Values.sra.webConfig.ingress.existingSecret -}}
        {{- printf "%s" .Values.sra.webConfig.ingress.existingSecret -}}
    {{- else -}}
        {{- printf "%s-tls" .Values.sra.webConfig.ingress.hostname -}}
    {{- end -}}
{{- end -}}

{{/*
Generate chart secret name
*/}}
{{- define "web-access-sra.secretName" -}}
{{ default (include "akeyless-gateway.fullname" .) }}
{{- end -}}

{{- define "akeyless-gateway-sra-ssh-service.selectorLabels" -}}
app.kubernetes.io/name: {{ (include "akeyless-gateway.name" .) | trunc 38 | trimSuffix "-" }}-gateway-sra-ssh-services
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "httpProxySettings" -}}
  {{- if .Values.globalConfig.httpProxySettings.http_proxy }}
  - name: HTTP_PROXY
    value: {{ .Values.globalConfig.httpProxySettings.http_proxy }}
  - name: http_proxy
    value: {{ .Values.globalConfig.httpProxySettings.http_proxy }}
  {{- end }}
  {{- if .Values.globalConfig.httpProxySettings.https_proxy }}
  - name: HTTPS_PROXY
    value: {{ .Values.globalConfig.httpProxySettings.https_proxy }}
  - name: https_proxy
    value: {{ .Values.globalConfig.httpProxySettings.https_proxy }}
  {{- end }}
  {{- if .Values.globalConfig.httpProxySettings.no_proxy }}
  - name: NO_PROXY
    value: {{ .Values.globalConfig.httpProxySettings.no_proxy }}
  - name: no_proxy
    value: {{ .Values.globalConfig.httpProxySettings.no_proxy }}
  {{- end }}
{{- end -}}

{{- define "akeyless-gateway.chartMetadata" }}
  - name: chart_name
    value: {{ .Chart.Name }}
  - name: chart_version
    value: {{ .Chart.Version }}
{{- end -}}

{{- define "akeyless-gateway.unifiedGatewayFlag" }}
  - name: UNIFIED_GATEWAY
    value: "true"
{{- end -}}

{{- define "akeyless-gateway.unifiedGatewayConfig" }}
  {{ include "akeyless-gateway.unifiedGatewayFlag" . }}
  - name: GATEWAY_URL
    value: "http://{{ include "akeyless-gateway.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local:8000"
  - name: INTERNAL_GATEWAY_API
    value: "http://{{ include "akeyless-gateway.fullname" . }}-internal.{{ .Release.Namespace }}.svc.cluster.local:8080"
{{- end -}}

{{- define "akeyless-gateway.SraWebServiceConfig" }}
  - name: REMOTE_ACCESS_WEB_SERVICE_INTERNAL_URL
    value: "http://web-{{ include "akeyless-gateway.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local:8888"
{{- end -}}

{{- define "akeyless-gateway.SraSshServiceConfig" }}
  - name: REMOTE_ACCESS_SSH_SERVICE_INTERNAL_URL
    value: "http://ssh-{{ include "akeyless-gateway.fullname" . }}-internal.{{ .Release.Namespace }}.svc.cluster.local:9900"
{{- end -}}

{{- define "akeyless-gateway.unifiedGatewaySraWebConfig" }}
  {{ include "akeyless-gateway.unifiedGatewayConfig" . }}
  {{ include "akeyless-gateway.SraSshServiceConfig" . }}
  - name: REMOTE_ACCESS_SSH_ENDPOINT
    value: "ssh-{{ include "akeyless-gateway.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local:{{ .Values.sra.sshConfig.service.port }}"
{{- end -}}

{{- define "akeyless-gateway.unifiedGatewaySraGatewayConfig" }}
  {{ include "akeyless-gateway.SraWebServiceConfig" . }}
  {{ include "akeyless-gateway.SraSshServiceConfig" . }}
{{- end -}}


{{- define "akeyless-sra-ssh.webNamePrefix" -}}
{{- if .Values.sra.webConfig.namePrefix -}}
{{- .Values.sra.webConfig.namePrefix -}}
{{- else -}}
web
{{- end -}}
{{- end -}}


{{- define "akeyless-sra-ssh.sshNamePrefix" -}}
{{- if .Values.sra.sshConfig.namePrefix -}}
{{- .Values.sra.sshConfig.namePrefix -}}
{{- else -}}
ssh
{{- end -}}
{{- end -}}
