{{- define "rustfs.url" -}}
rustfs-svc.{{ .Release.Namespace }}.svc.cluster.local:9000
{{- end }}
