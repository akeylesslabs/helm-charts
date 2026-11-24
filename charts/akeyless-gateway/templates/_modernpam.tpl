{{/*
The V2 chart's fullname, which the gateway needs to find its Services. It repeats the
subchart's rule: the full override if set, else the release name when it already holds the
name modern-pam, else release-modern-pam. The alias would give a mixed case name.
*/}}
{{- define "akeyless-gateway.modernPamFullname" -}}
{{- if .Values.modernPam.fullnameOverride -}}
{{- .Values.modernPam.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "modern-pam" .Values.modernPam.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* V1 and V2 are two releases, never one. Rendered by modernpam-guard.yaml on every render. */}}
{{- define "akeyless-gateway.modernPamGuard" -}}
{{- if and .Values.sra.enabled .Values.modernPam.enabled -}}
{{- fail "sra.enabled and modernPam.enabled are both true. A release runs the V1 bastion or the V2 one, never both. To move a cluster from V1 to V2 set sra.enabled to false and modernPam.enabled to true in the same upgrade. To run both in one estate, use two releases on two clusters." -}}
{{- end -}}
{{- end -}}

{{/* Where the gateway reaches the V2 control API and web gate, the V2 counterparts of the two V1 internal URLs. */}}
{{- define "akeyless-gateway.modernPamGatewayConfig" }}
  - name: REMOTE_ACCESS_SSH_SERVICE_INTERNAL_URL
    value: "http://{{ include "akeyless-gateway.modernPamFullname" . }}.{{ .Release.Namespace }}.{{ include "akeyless-gateway.clusterSvcDomain" . }}:9900"
  - name: REMOTE_ACCESS_WEB_SERVICE_INTERNAL_URL
    value: "http://{{ include "akeyless-gateway.modernPamFullname" . }}-web.{{ .Release.Namespace }}.{{ include "akeyless-gateway.clusterSvcDomain" . }}:8888"
{{- end -}}

{{/*
V1 keys placed under modernPam and what V2 did with each, one line per key found.
The mapped list repeats the V2 chart's own compat helper and a render test keeps the two together.
*/}}
{{- define "akeyless-gateway.modernPamLegacyNotes" -}}
{{- $mp := .Values.modernPam -}}
{{- $mapped := dict "sshConfig.CAPublicKey" "ssh.caPublicKey (and the SSH gate is turned on)" "sshConfig.service.type" "ssh.service.type" "sshConfig.service.externalTrafficPolicy" "ssh.service.externalTrafficPolicy" "sshConfig.service.annotations" "ssh.service.annotations" "env" "extraEnv" -}}
{{- $ssh := $mp.sshConfig | default dict -}}
{{- $svc := $ssh.service | default dict -}}
{{- $found := dict "sshConfig.CAPublicKey" $ssh.CAPublicKey "sshConfig.service.type" $svc.type "sshConfig.service.externalTrafficPolicy" $svc.externalTrafficPolicy "sshConfig.service.annotations" $svc.annotations "env" $mp.env -}}
{{- range $key := keys $mapped | sortAlpha -}}
{{- if index $found $key }}
  mapped    modernPam.{{ $key }} -> modernPam.{{ index $mapped $key }}
{{- end -}}
{{- end -}}
{{- range $top := list "sshConfig" "webConfig" "customCA" -}}
{{- if index $mp $top }}
  {{ $top }}: every key under it that is not listed as mapped above is accepted and not applied by V2
{{- end -}}
{{- end -}}
{{- end -}}
