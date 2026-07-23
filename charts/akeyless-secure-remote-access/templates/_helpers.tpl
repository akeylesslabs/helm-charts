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

{{- define "akeyless-secure-remote-access.redisStorageImage" -}}
  {{- if .Values.redisStorage.image -}}
    image: "{{ .Values.redisStorage.image.repository }}:{{ .Values.redisStorage.image.tag }}"
    imagePullPolicy: {{ .Values.redisStorage.image.pullPolicy }}
  {{- else }}
    image: "public.ecr.aws/docker/library/redis:8.6.3-alpine"
    imagePullPolicy: "IfNotPresent"
  {{- end -}}
{{- end -}}

{{- define "akeyless-secure-remote-access.storageSecretName" -}}
  {{- if empty .Values.redisStorage.redisPasswordExistingSecret }}
  {{- printf "%s-storage-secret" $.Release.Name -}}
  {{- else if not (empty .Values.redisStorage.redisPasswordExistingSecret) }}
  {{- printf "%s" .Values.redisStorage.redisPasswordExistingSecret }}
  {{- end }}
{{- end -}}

{{- define "akeyless-secure-remote-access.password" }}
  - name: REDIS_PASS
    valueFrom:
      secretKeyRef:
        name: {{ include "akeyless-secure-remote-access.storageSecretName" . }}
        key: storage-pass
{{- end }}

{{/*
SSH bastion capability set required by the zero-trust-bastion image (>= 3.1.0, non-root
default). Keep in sync with the unified akeyless-gateway chart.
*/}}
{{- define "akeyless-sra-ssh.phaseACaps" -}}
capabilities:
  drop:
    - ALL
  add:
    - SYS_CHROOT     # sshd privilege separation: chroot("/run/sshd") [preauth]
    - AUDIT_WRITE    # sshd session: linux_audit_write_entry after pubkey auth
    - SYS_ADMIN      # Required for mount --bind /dev/pts
    - MKNOD          # Required for mknod device nodes in jail
    - DAC_OVERRIDE   # Required for adduser/deluser/jail permissions
    - CHOWN          # Required by adduser + chroot setup
    - SETUID         # Required by adduser + chroot setup
    - SETGID         # Required by adduser + chroot setup
    - FOWNER         # Required by adduser + chroot setup
{{- end -}}

{{/*
The zero-trust-bastion image defaults to a non-root user, but the bastion entrypoint performs
root-only setup (writes /etc/ssh/ca.pub, runs usermod), so the pod is pinned to root.
*/}}
{{- define "akeyless-sra-ssh.podSecurityContext" -}}
securityContext:
  runAsUser: 0
  runAsGroup: 0
{{- end -}}

{{- define "akeyless-sra-ssh.containerSecurityContext" -}}
securityContext:
  allowPrivilegeEscalation: true
  # The bastion bind-mounts /dev/pts per session, and AppArmor's default profile blocks mount
  # even with CAP_SYS_ADMIN, so it runs unconfined. Requires Kubernetes 1.30+. On older
  # clusters use the container.apparmor.security.beta.kubernetes.io annotation instead.
  appArmorProfile:
    type: Unconfined
  {{- include "akeyless-sra-ssh.phaseACaps" . | nindent 2 }}
{{- end -}}

{{/*
Validated SSH proxy port, rejects privileged and reserved ports at render time.
*/}}
{{- define "akeyless-sra-ssh.proxyPort" -}}
{{- $port := int (default 2200 .Values.sshConfig.proxyPort) -}}
{{- if le $port 1024 -}}
{{- fail (printf "sshConfig.proxyPort must be an unprivileged port above 1024, got %d" $port) -}}
{{- end -}}
{{- if or (eq $port 2222) (eq $port 9900) -}}
{{- fail (printf "sshConfig.proxyPort must not be 2222 (in-container sshd) or 9900 (curl-proxy), got %d" $port) -}}
{{- end -}}
{{- $port -}}
{{- end -}}
