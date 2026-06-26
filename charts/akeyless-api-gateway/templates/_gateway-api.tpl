{{/* vim: set filetype=mustache: */}}
{{/*
Kubernetes Gateway API helpers + fail-loud guards (ASM-16238).

Every route's backend is THIS chart's own Service. Misuse is made
unrepresentable at render time by the `validate` guard (G1..G5), which is
included from templates/gateway-api-validate.yaml so it runs on every render.
*/}}

{{/* Gateway resource name — defaults to the chart fullname. */}}
{{- define "akeyless-api-gw.gatewayAPI.gatewayName" -}}
{{- $gw := (.Values.gatewayAPI).gateway | default dict -}}
{{- default (include "akeyless-api-gw.fullname" .) $gw.name -}}
{{- end -}}

{{/* allowedRoutes.namespaces.from for generated listeners (default: Same). */}}
{{- define "akeyless-api-gw.gatewayAPI.allowedRoutesFrom" -}}
{{- $gw := (.Values.gatewayAPI).gateway | default dict -}}
{{- $ar := $gw.allowedRoutes | default dict -}}
{{- $ns := $ar.namespaces | default dict -}}
{{- $ns.from | default "Same" -}}
{{- end -}}

{{/* Comma-joined list of valid service.ports names (for guard messages). */}}
{{- define "akeyless-api-gw.gatewayAPI.portNames" -}}
{{- $names := list -}}
{{- range .Values.service.ports -}}{{- $names = append $names .name -}}{{- end -}}
{{- $names | join ", " -}}
{{- end -}}

{{/*
Resolve a named servicePort to its numeric Service port. Fails loud (G4) when
the name is not declared in .Values.service.ports.
  args: dict "port" <name> "root" $
*/}}
{{- define "akeyless-api-gw.gatewayAPI.portNumber" -}}
{{- $name := .port -}}
{{- $root := .root -}}
{{- $num := "" -}}
{{- range $root.Values.service.ports -}}
{{- if eq .name $name -}}{{- $num = .port -}}{{- end -}}
{{- end -}}
{{- if kindIs "string" $num -}}
{{- fail (printf "akeyless-api-gateway: gatewayAPI route references unknown servicePort %q; valid names: %s" $name (include "akeyless-api-gw.gatewayAPI.portNames" $root)) -}}
{{- end -}}
{{- $num -}}
{{- end -}}

{{/*
parentRefs block for every route: explicit gatewayAPI.parentRefs when set,
otherwise the Gateway this chart creates.
*/}}
{{- define "akeyless-api-gw.gatewayAPI.parentRefs" -}}
{{- $ga := .Values.gatewayAPI -}}
{{- if $ga.parentRefs -}}
{{- toYaml $ga.parentRefs -}}
{{- else -}}
- name: {{ include "akeyless-api-gw.gatewayAPI.gatewayName" . }}
{{- end -}}
{{- end -}}

{{/*
Fail-loud guards. Emits NOTHING on success (port lookups are swallowed into a
throwaway variable); each illegal combination calls `fail`.
  G1 ingress.enabled AND gatewayAPI.enabled        -> mutually exclusive
  G2 enabled, gateway.create, no gatewayClassName  -> classname required
  G3 enabled, gateway.create=false, no parentRefs  -> nothing to attach to
  G4 any route servicePort not in service.ports    -> (via portNumber)
*/}}
{{- define "akeyless-api-gw.gatewayAPI.validate" -}}
{{- $ga := .Values.gatewayAPI | default dict -}}
{{- if $ga.enabled -}}
{{- if .Values.ingress.enabled -}}
{{- fail "akeyless-api-gateway: ingress.enabled and gatewayAPI.enabled are mutually exclusive — enable exactly one north-south path (Ingress or Gateway API)." -}}
{{- end -}}
{{- $gw := $ga.gateway | default dict -}}
{{- if $gw.create -}}
{{- if not $gw.gatewayClassName -}}
{{- fail "akeyless-api-gateway: gatewayAPI.gateway.gatewayClassName is required when gatewayAPI.gateway.create=true (e.g. nginx, cilium, istio, kong, envoy)." -}}
{{- end -}}
{{- else -}}
{{- if not $ga.parentRefs -}}
{{- fail "akeyless-api-gateway: set gatewayAPI.parentRefs when gatewayAPI.gateway.create=false — there is no Gateway to attach routes to." -}}
{{- end -}}
{{- end -}}
{{- if and $gw.create $ga.tlsRoutes -}}
{{- $tls := $gw.tls | default dict -}}
{{- if not (and $tls.enabled (eq ($tls.mode | default "Terminate") "Passthrough")) -}}
{{- fail "akeyless-api-gateway: gatewayAPI.tlsRoutes require a TLS passthrough listener — set gatewayAPI.gateway.tls.enabled=true and gatewayAPI.gateway.tls.mode=Passthrough (or attach to an external Gateway that provides one)." -}}
{{- end -}}
{{- end -}}
{{- range $ga.httpRoutes -}}{{- $_ := include "akeyless-api-gw.gatewayAPI.portNumber" (dict "port" .servicePort "root" $) -}}{{- end -}}
{{- range $ga.tlsRoutes -}}{{- $_ := include "akeyless-api-gw.gatewayAPI.portNumber" (dict "port" .servicePort "root" $) -}}{{- end -}}
{{- range $ga.tcpRoutes -}}{{- $_ := include "akeyless-api-gw.gatewayAPI.portNumber" (dict "port" .servicePort "root" $) -}}{{- end -}}
{{- end -}}
{{- end -}}
