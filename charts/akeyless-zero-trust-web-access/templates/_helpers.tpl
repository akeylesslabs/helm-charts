{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "akeyless-zero-web-access.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "akeyless-zero-web-access.fullname" -}}
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
{{- define "akeyless-zero-web-access.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "akeyless-zero-web-access.labels" -}}
helm.sh/chart: {{ include "akeyless-zero-web-access.chart" . }}
{{ include "akeyless-zero-web-access.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "akeyless-zero-web-access.selectorLabels" -}}
app.kubernetes.io/name: {{ include "akeyless-zero-web-access.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "akeyless-zero-web-access.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "akeyless-zero-web-access.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Get the Ingress TLS secret.
*/}}
{{- define "akeyless-zero-web-access.ingressSecretTLSName" -}}
    {{- if .Values.dispatcher.ingress.existingSecret -}}
        {{- printf "%s" .Values.dispatcher.ingress.existingSecret -}}
    {{- else -}}
        {{- printf "%s-tls" .Values.dispatcher.ingress.hostname -}}
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

{{/*
Fails the render on keys that moved in chart 4.0.0, so an old values file cannot install
with its settings silently ignored. Also checks the values the dispatcher cannot start
without.
*/}}
{{- define "akeyless-zero-web-access.validateValues" -}}
{{- $v := .Values -}}
{{- $moved := list -}}
{{- if and $v.dispatcher (hasKey $v.dispatcher "config") -}}
  {{- $moved = append $moved "dispatcher.config moved to config. Its recording block moved to recording.s3, cloudIdentity.type to config.privilegedAccess.accessType, privilegedAccess.allowedAccessIDs and existingSecretNames.allowedIDs to authorizedAccessIDs, and privilegedAccess.accessKey, listOnlyCredentials, logForward and existingLogForwardSecretName were removed" -}}
{{- end -}}
{{- if hasKey $v "sessionRecording" -}}
  {{- $moved = append $moved "sessionRecording moved to recording, and sessionRecording.upload to recording.s3 with new field names. sessionRecording.quality and sessionRecording.watchdog were removed" -}}
{{- end -}}
{{- if and $v.HPA (hasKey $v.HPA "dispatcher") -}}
  {{- $moved = append $moved "HPA.dispatcher was removed, the chart runs one dispatcher per worker pool" -}}
{{- end -}}
{{- if and $v.recording (hasKey $v.recording "upload") -}}
  {{- $moved = append $moved "recording.upload moved to recording.s3 with new field names" -}}
{{- end -}}
{{- if hasKey $v "dlp" -}}
  {{- $moved = append $moved "dlp was removed" -}}
{{- end -}}
{{- if and $v.webWorker $v.webWorker.config (hasKey $v.webWorker.config "dispatcherDNS") -}}
  {{- $moved = append $moved "webWorker.config.dispatcherDNS moved to dispatcher.dispatcherDNS" -}}
{{- end -}}
{{- if and $v.HPA $v.HPA.webWorker (hasKey $v.HPA.webWorker "sessionTerminationGracePeriodSeconds") -}}
  {{- $moved = append $moved "HPA.webWorker.sessionTerminationGracePeriodSeconds moved to webWorker.terminationGracePeriodSeconds" -}}
{{- end -}}
{{- $c := $v.config | default dict -}}
{{- if hasKey $c "cloudIdentity" -}}
  {{- $moved = append $moved "config.cloudIdentity.type moved to config.privilegedAccess.accessType" -}}
{{- end -}}
{{- if hasKey $c "recording" -}}
  {{- $moved = append $moved "config.recording moved to recording.s3 with new field names" -}}
{{- end -}}
{{- if hasKey $c "listOnlyCredentials" -}}
  {{- $moved = append $moved "config.listOnlyCredentials was removed" -}}
{{- end -}}
{{- if or (hasKey $c "logForward") (hasKey $c "existingLogForwardSecretName") -}}
  {{- $moved = append $moved "config.logForward and config.existingLogForwardSecretName were removed, set the recording upload in recording.s3" -}}
{{- end -}}
{{- $pa := $c.privilegedAccess | default dict -}}
{{- if hasKey $pa "accessKey" -}}
  {{- $moved = append $moved "config.privilegedAccess.accessKey was removed, put the key in the Secret named in config.privilegedAccess.existingSecretNames.access" -}}
{{- end -}}
{{- if hasKey $pa "allowedAccessIDs" -}}
  {{- $moved = append $moved "config.privilegedAccess.allowedAccessIDs moved to config.privilegedAccess.authorizedAccessIDs" -}}
{{- end -}}
{{- if and $pa.existingSecretNames (hasKey $pa.existingSecretNames "allowedIDs") -}}
  {{- $moved = append $moved "config.privilegedAccess.existingSecretNames.allowedIDs moved to config.privilegedAccess.existingSecretNames.authorizedAccessIDs" -}}
{{- end -}}
{{- if $moved -}}
  {{- fail (printf "values from an older chart layout found. Update them and run again, the README section \"Upgrading to the 4.0.0 values layout\" has the full map:\n- %s" (join "\n- " $moved)) -}}
{{- end -}}
{{- $hasAccessSecret := eq (include "secret-exist" (dict "Root" $pa.existingSecretNames "Name" "access")) "true" -}}
{{- $hasIDsSecret := eq (include "secret-exist" (dict "Root" $pa.existingSecretNames "Name" "authorizedAccessIDs")) "true" -}}
{{- if and (eq (toString $pa.accessType) "access_key") (not $hasAccessSecret) -}}
  {{- fail "config.privilegedAccess.accessType access_key needs config.privilegedAccess.existingSecretNames.access, a Secret with the keys accessID and accessKey" -}}
{{- end -}}
{{- if and (not $hasIDsSecret) (not $pa.authorizedAccessIDs) -}}
  {{- fail "config.privilegedAccess.authorizedAccessIDs is empty, and the dispatcher and the web proxy accept no user without it. Set it, or config.privilegedAccess.existingSecretNames.authorizedAccessIDs" -}}
{{- end -}}
{{- $s3 := ($v.recording | default dict).s3 | default dict -}}
{{- if and $s3.enabled (not $s3.bucket) -}}
  {{- fail "recording.s3.bucket is required when recording.s3.enabled is true" -}}
{{- end -}}
{{- end -}}

{{/*
Merge and deduplicate image pull secret names. Order: global (image.imagePullSecrets),
then initPullSecrets, then imagePullSecrets (per-pod), then akeyless-docker-hub-web-access
when image.dockerRepositoryCreds is set.
Input dict: Root, initPullSecrets, imagePullSecrets
Renders an unindented "imagePullSecrets: ..." block, or nothing when empty. Callers pipe to nindent.
*/}}
{{- define "akeyless-zero-web-access.imagePullSecrets" -}}
{{- $root := .Root -}}
{{- $g := $root.Values.image.imagePullSecrets | default list -}}
{{- $i := .initPullSecrets | default list -}}
{{- $m := .imagePullSecrets | default list -}}
{{- $names := list -}}
{{- $seen := dict -}}
{{- range $g -}}
  {{- if .name -}}
  {{- if not (index $seen .name) -}}
    {{- $names = append $names .name -}}
    {{- $seen = set $seen .name true -}}
  {{- end -}}
  {{- end -}}
{{- end -}}
{{- range $i -}}
  {{- if .name -}}
  {{- if not (index $seen .name) -}}
    {{- $names = append $names .name -}}
    {{- $seen = set $seen .name true -}}
  {{- end -}}
  {{- end -}}
{{- end -}}
{{- range $m -}}
  {{- if .name -}}
  {{- if not (index $seen .name) -}}
    {{- $names = append $names .name -}}
    {{- $seen = set $seen .name true -}}
  {{- end -}}
  {{- end -}}
{{- end -}}
{{- if $root.Values.image.dockerRepositoryCreds -}}
  {{- if not (index $seen "akeyless-docker-hub-web-access") -}}
    {{- $names = append $names "akeyless-docker-hub-web-access" -}}
  {{- end -}}
{{- end -}}
{{- if $names -}}
imagePullSecrets:
{{- range $names }}
  - name: {{ . | quote }}
{{- end -}}
{{- end -}}
{{- end -}}
