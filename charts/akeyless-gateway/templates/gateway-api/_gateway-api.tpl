{{- define "gatewayApi.backendService" -}}
{{- $b := .Values.gatewayAPI.backend | default dict -}}
{{- if $b.serviceName -}}
{{- $b.serviceName -}}
{{- else -}}
{{- include "akeyless-gateway.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "gatewayApi.gatewayName" -}}
{{- default (include "gatewayApi.backendService" .) .Values.gatewayAPI.gateway.name -}}
{{- end -}}

{{- define "gatewayApi.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: akeyless-gateway-api
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "gatewayApi.allowedRoutesFrom" -}}
{{- $gw := .Values.gatewayAPI.gateway | default dict -}}
{{- $ar := $gw.allowedRoutes | default dict -}}
{{- $ns := $ar.namespaces | default dict -}}
{{- $ns.from | default "Same" -}}
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
{{- range ($root.Values.gatewayAPI.backend | default dict).ports -}}
{{- if eq .name $name -}}{{- $num = .port -}}{{- end -}}
{{- end -}}
{{- if kindIs "string" $num -}}
{{- fail (printf "akeyless-gateway gatewayAPI: route references unknown servicePort %q; valid names: %s" $name (include "gatewayApi.portNames" $root)) -}}
{{- end -}}
{{- $num -}}
{{- end -}}

{{- define "gatewayApi.parentRefs" -}}
{{- if .Values.gatewayAPI.parentRefs -}}
{{- toYaml .Values.gatewayAPI.parentRefs -}}
{{- else -}}
- name: {{ include "gatewayApi.gatewayName" . }}
{{- end -}}
{{- end -}}

{{- define "gatewayApi.validate" -}}
{{- $ga := .Values.gatewayAPI | default dict -}}
{{- if $ga.enabled -}}
{{- if ((.Values.gateway | default dict).ingress | default dict).enabled -}}
{{- fail "akeyless-gateway gatewayAPI: gatewayAPI.enabled and gateway.ingress.enabled are mutually exclusive — enable exactly one north-south path." -}}
{{- end -}}
{{- $gw := $ga.gateway | default dict -}}
{{- if $gw.create -}}
{{- if not $gw.gatewayClassName -}}
{{- fail "akeyless-gateway gatewayAPI: gateway.gatewayClassName is required when gateway.create=true (e.g. cilium, nginx, istio, kong, envoy, aws-alb)." -}}
{{- end -}}
{{- else -}}
{{- if not $ga.parentRefs -}}
{{- fail "akeyless-gateway gatewayAPI: set parentRefs when gateway.create=false — there is no Gateway to attach routes to." -}}
{{- end -}}
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
