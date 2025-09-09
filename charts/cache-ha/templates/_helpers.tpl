{{/*
Expand the name of the chart.
*/}}
{{- define "cache-ha.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cache-ha.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "cache-ha.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cache-ha.labels" -}}
helm.sh/chart: {{ include "cache-ha.chart" . }}
{{ include "cache-ha.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cache-ha.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cache-ha.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "cache-ha.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cache-ha.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Cache image (using Redis as underlying engine)
*/}}
{{- define "cache-ha.redis.image" -}}
{{- $registryName := .Values.image.registry -}}
{{- $repositoryName := .Values.image.repository -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- if $registryName }}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- else -}}
{{- printf "%s:%s" $repositoryName $tag -}}
{{- end -}}
{{- end }}

{{/*
Sentinel image
*/}}
{{- define "cache-ha.sentinel.image" -}}
{{- $registryName := .Values.sentinel.image.registry -}}
{{- $repositoryName := .Values.sentinel.image.repository -}}
{{- $tag := .Values.sentinel.image.tag | default .Chart.AppVersion -}}
{{- if $registryName }}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- else -}}
{{- printf "%s:%s" $repositoryName $tag -}}
{{- end -}}
{{- end }}

{{/*
Metrics image
*/}}
{{- define "cache-ha.metrics.image" -}}
{{- $registryName := .Values.metrics.image.registry -}}
{{- $repositoryName := .Values.metrics.image.repository -}}
{{- $tag := .Values.metrics.image.tag -}}
{{- if $registryName }}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- else -}}
{{- printf "%s:%s" $repositoryName $tag -}}
{{- end -}}
{{- end }}

{{/*
Cache secret name
*/}}
{{- define "cache-ha.secretName" -}}
{{- if .Values.auth.existingSecret }}
{{- printf "%s" .Values.auth.existingSecret -}}
{{- else -}}
{{- printf "%s" (include "cache-ha.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Cache secret key for password
*/}}
{{- define "cache-ha.secretPasswordKey" -}}
{{- if .Values.auth.existingSecretPasswordKey }}
{{- printf "%s" .Values.auth.existingSecretPasswordKey -}}
{{- else -}}
{{- printf "redis-password" -}}
{{- end -}}
{{- end -}}

{{/*
Create TLS secret name
*/}}
{{- define "cache-ha.tlsSecretName" -}}
{{- if .Values.tls.existingSecret }}
{{- printf "%s" .Values.tls.existingSecret -}}
{{- else -}}
{{- printf "%s-crt" (include "cache-ha.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Check if TLS secret should be created
*/}}
{{- define "cache-ha.createTlsSecret" -}}
{{- if and .Values.tls.enabled (not .Values.tls.existingSecret) -}}
true
{{- end -}}
{{- end -}}

{{/*
Cache configmap name
*/}}
{{- define "cache-ha.configmapName" -}}
{{- printf "%s" (include "cache-ha.fullname" .) -}}
{{- end -}}

{{/*
Cache headless service name
*/}}
{{- define "cache-ha.headlessServiceName" -}}
{{- printf "%s-headless" (include "cache-ha.fullname" .) -}}
{{- end -}}

{{/*
Cache master service name
*/}}
{{- define "cache-ha.masterServiceName" -}}
{{- printf "%s-master" (include "cache-ha.fullname" .) -}}
{{- end -}}

{{/*
Cache sentinel service name
*/}}
{{- define "cache-ha.sentinelServiceName" -}}
{{- printf "%s-sentinel" (include "cache-ha.fullname" .) -}}
{{- end -}}

{{/*
Cache statefulset name for nodes
*/}}
{{- define "cache-ha.nodeStatefulSetName" -}}
{{- printf "%s-node" (include "cache-ha.fullname" .) -}}
{{- end -}}

{{/*
Cache statefulset name for sentinel
*/}}
{{- define "cache-ha.sentinelStatefulSetName" -}}
{{- printf "%s-sentinel" (include "cache-ha.fullname" .) -}}
{{- end -}}

{{/*
Cache scripts configmap name
*/}}
{{- define "cache-ha.scriptsConfigMapName" -}}
{{- printf "%s-scripts" (include "cache-ha.fullname" .) -}}
{{- end -}}

{{/*
Cache health configmap name
*/}}
{{- define "cache-ha.healthConfigMapName" -}}
{{- printf "%s-health" (include "cache-ha.fullname" .) -}}
{{- end -}}

{{/*
Cache sentinel configmap name
*/}}
{{- define "cache-ha.sentinelConfigMapName" -}}
{{- printf "%s-sentinel-config" (include "cache-ha.fullname" .) -}}
{{- end -}}


{{/*
Redis TLS cert file path
*/}}
{{- define "cache-ha.tlsCert" -}}
{{- printf "/opt/bitnami/redis/certs/tls.crt" -}}
{{- end -}}

{{/*
Redis TLS cert key file path
*/}}
{{- define "cache-ha.tlsCertKey" -}}
{{- printf "/opt/bitnami/redis/certs/tls.key" -}}
{{- end -}}

{{/*
Redis TLS CA cert file path
*/}}
{{- define "cache-ha.tlsCACert" -}}
{{- if .Values.tls.certCAFilename }}
{{- printf "/opt/bitnami/redis/certs/%s" .Values.tls.certCAFilename -}}
{{- else -}}
{{- printf "/opt/bitnami/redis/certs/ca.crt" -}}
{{- end -}}
{{- end -}}

{{/*
Redis TLS DH params file path
*/}}
{{- define "cache-ha.tlsDHParams" -}}
{{- printf "/opt/bitnami/redis/certs/%s" .Values.tls.dhParamsFilename -}}
{{- end -}}

{{/*
Create the name of the service account to use for master
*/}}
{{- define "cache-ha.masterServiceAccountName" -}}
{{- if .Values.master.serviceAccount.create }}
{{- default (printf "%s-master" (include "cache-ha.fullname" .)) .Values.master.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.master.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use for replica
*/}}
{{- define "cache-ha.replicaServiceAccountName" -}}
{{- if .Values.replica.serviceAccount.create }}
{{- default (printf "%s-replica" (include "cache-ha.fullname" .)) .Values.replica.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.replica.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use for sentinel
*/}}
{{- define "cache-ha.sentinelServiceAccountName" -}}
{{- if .Values.sentinel.serviceAccount.create }}
{{- default (printf "%s-sentinel" (include "cache-ha.fullname" .)) .Values.sentinel.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.sentinel.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Image pull secrets
*/}}
{{- define "cache-ha.imagePullSecrets" -}}
{{- if .Values.global.imagePullSecrets }}
imagePullSecrets:
{{- range .Values.global.imagePullSecrets }}
  - name: {{ . }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Storage class
*/}}
{{- define "cache-ha.storageClass" -}}
{{- if .Values.global.defaultStorageClass }}
{{- printf "storageClassName: %s" .Values.global.defaultStorageClass -}}
{{- else if .Values.global.storageClass }}
{{- printf "storageClassName: %s" .Values.global.storageClass -}}
{{- end -}}
{{- end -}}

{{/*
Namespace
*/}}
{{- define "cache-ha.namespace" -}}
{{- if .Values.namespaceOverride }}
{{- .Values.namespaceOverride }}
{{- else -}}
{{- .Release.Namespace }}
{{- end -}}
{{- end -}}

{{/*
Common labels for all resources
*/}}
{{- define "cache-ha.commonLabels" -}}
{{- $commonLabels := .Values.commonLabels -}}
{{- if $commonLabels }}
{{- toYaml $commonLabels }}
{{- end }}
{{- end -}}

{{/*
Common annotations for all resources
*/}}
{{- define "cache-ha.commonAnnotations" -}}
{{- $commonAnnotations := .Values.commonAnnotations -}}
{{- if $commonAnnotations }}
{{- toYaml $commonAnnotations }}
{{- end }}
{{- end -}}
