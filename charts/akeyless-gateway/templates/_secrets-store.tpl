{{/*
Secrets Store CSI configuration
*/}}
{{ define "akeyless-gateway.secretsStore.volume" -}}
- name: secrets-store
  csi:
    driver: secrets-store.csi.k8s.io
    readOnly: true
    volumeAttributes:
      secretProviderClass: {{ required "secretProviderClassName is required" .Values.gateway.secretsStore.provider.secretProviderClassName | quote }}
{{- end }}

{{ define "akeyless-gateway.secretsStore.mountPath" -}}
{{- if .Values.gateway.secretsStore.mountPath }}
{{ .Values.gateway.secretsStore.mountPath }}
{{- else }}
{{ print (ternary "/root/secrets-store" "/home/akeyless/secrets-store" .Values.gatewayRootMode) }}
{{- end }}
{{- end }}