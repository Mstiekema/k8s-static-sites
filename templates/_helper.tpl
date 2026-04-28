{{- define "rustfs.url" -}}
static-sites-rustfs-svc.{{ .Release.Namespace }}.svc.cluster.local:9000
{{- end }}
