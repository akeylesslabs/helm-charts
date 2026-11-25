{{/*
Whether Modern PAM is on. A release upgraded with --reuse-values from an earlier chart has no modernPam key at
all, so every read of it goes through this helper or through a dict default, never straight from .Values.
*/}}
{{- define "akeyless-gateway.modernPamEnabled" -}}
{{- if (.Values.modernPam | default dict).enabled -}}true{{- end -}}
{{- end -}}

{{/*
The V2 chart's fullname, which the gateway needs to find its Services. It repeats the
subchart's rule: the full override if set, else the release name when it already holds the
name modern-pam, else release-modern-pam. The alias would give a mixed case name.
*/}}
{{- define "akeyless-gateway.modernPamFullname" -}}
{{- $mp := .Values.modernPam | default dict -}}
{{- if $mp.fullnameOverride -}}
{{- $mp.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "modern-pam" $mp.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* V1 and V2 are two releases, never one. Rendered by modernpam-guard.yaml on every render. */}}
{{- define "akeyless-gateway.modernPamGuard" -}}
{{- if and .Values.sra.enabled (include "akeyless-gateway.modernPamEnabled" .) -}}
{{- fail "sra.enabled and modernPam.enabled are both true. A release runs the V1 bastion or the V2 one, never both. To move a cluster from V1 to V2 set sra.enabled to false and modernPam.enabled to true in the same upgrade. To run both in one estate, use two releases on two clusters." -}}
{{- end -}}
{{- end -}}

{{/*
Where the gateway reaches the V2 control API and web gate, the V2 counterparts of the two V1 internal URLs.
The web console has one path. By default it is the gateway's proxy, which needs the second URL. Turning on
the V2 ingress makes the ingress the path and leaves the gateway without the web URL, so the two never serve
the same console at once.
*/}}
{{- define "akeyless-gateway.modernPamGatewayConfig" }}
{{- $mp := .Values.modernPam | default dict }}
{{- $control := $mp.control | default dict }}
{{- $web := $mp.web | default dict }}
{{- $ingress := $mp.ingress | default dict }}
  - name: REMOTE_ACCESS_SSH_SERVICE_INTERNAL_URL
    value: "http://{{ include "akeyless-gateway.modernPamFullname" . }}.{{ .Release.Namespace }}.{{ include "akeyless-gateway.clusterSvcDomain" . }}:{{ $control.port | default 9900 }}"
{{- if and (ne (toString $web.enabled) "false") (not $ingress.enabled) }}
  - name: REMOTE_ACCESS_WEB_SERVICE_INTERNAL_URL
    value: "http://{{ include "akeyless-gateway.modernPamFullname" . }}-web.{{ .Release.Namespace }}.{{ include "akeyless-gateway.clusterSvcDomain" . }}:{{ $web.port | default 8888 }}"
{{- end }}
{{- end -}}

{{/*
V1 keys placed under modernPam and what V2 did with each, one line per key found.
The mapped list repeats the bundled chart's own compat helper, so re-check it against that chart on every re-pin.
*/}}
{{- define "akeyless-gateway.modernPamLegacyNotes" -}}
{{- $mp := .Values.modernPam | default dict -}}
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
