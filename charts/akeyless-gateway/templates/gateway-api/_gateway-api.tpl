{{- define "gatewayApi.backendService" -}}
{{- $b := .Values.gatewayAPI.backend | default dict -}}
{{- if $b.serviceName -}}
{{- $b.serviceName -}}
{{- else -}}
{{- include "akeyless-gateway.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "gatewayApi.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: akeyless-gateway-api
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "gatewayApi.portNames" -}}
{{- $names := list -}}
{{- range (.Values.gatewayAPI.backend | default dict).ports -}}{{- $names = append $names .name -}}{{- end -}}
{{- $names | join ", " -}}
{{- end -}}

{{- define "gatewayApi.portNumber" -}}
{{- $name := .port -}}
{{- $root := .root -}}
{{- $num := "" -}}
{{- $found := false -}}
{{- range ($root.Values.gatewayAPI.backend | default dict).ports -}}
{{- if eq .name $name -}}{{- $num = .port -}}{{- $found = true -}}{{- end -}}
{{- end -}}
{{- if not $found -}}
{{- fail (printf "akeyless-gateway gatewayAPI: route references unknown servicePort %q; valid names: %s" $name (include "gatewayApi.portNames" $root)) -}}
{{- end -}}
{{- $num -}}
{{- end -}}

{{- define "gatewayApi.parentRefs" -}}
{{- if .Values.gatewayAPI.parentRefs -}}
{{- toYaml .Values.gatewayAPI.parentRefs -}}
{{- else -}}
{{- fail "akeyless-gateway gatewayAPI: gatewayAPI.parentRefs is required — this slice attaches HTTPRoutes to an existing Gateway; it does not create one (Gateway creation is a separate, follow-on slice)." -}}
{{- end -}}
{{- end -}}

{{- define "gatewayApi.validate" -}}
{{- $ga := .Values.gatewayAPI | default dict -}}
{{- if $ga.enabled -}}
{{- if ((.Values.gateway | default dict).ingress | default dict).enabled -}}
{{- fail "akeyless-gateway gatewayAPI: gatewayAPI.enabled and gateway.ingress.enabled are mutually exclusive — enable exactly one north-south path." -}}
{{- end -}}
{{- if not $ga.parentRefs -}}
{{- fail "akeyless-gateway gatewayAPI: gatewayAPI.parentRefs is required — point at the existing Gateway to attach routes to (Gateway creation is a separate, follow-on slice)." -}}
{{- end -}}
{{- range $r := $ga.httpRoutes -}}
{{- if $r.backendRefs -}}
{{- range $b := $r.backendRefs -}}{{- $_ := include "gatewayApi.portNumber" (dict "port" $b.servicePort "root" $) -}}{{- end -}}
{{- else -}}
{{- $_ := include "gatewayApi.portNumber" (dict "port" $r.servicePort "root" $) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
