{{/*
Secrets Store CSI configuration
*/}}
{{- define "akeyless-gateway.secretsStore.volume" -}}
- name: secrets-store
  csi:
    driver: secrets-store.csi.k8s.io
    readOnly: true
    volumeAttributes:
      secretProviderClass: {{ .Values.gateway.secretsStore.secretProviderClassName }}
{{- end }}

{{- define "akeyless-gateway.secretsStore.volumeMount" -}}
- name: secrets-store
  mountPath: {{ .Values.gateway.secretsStore.mountPath | default "/mnt/secrets-store" }}
  readOnly: true
{{- end }}

{{- define "akeyless-gateway.secretsStore.env" -}}
- name: SECRETS_STORE_PATH
  value: {{ .Values.gateway.secretsStore.mountPath | default "/mnt/secrets-store" }}
{{- end }} 