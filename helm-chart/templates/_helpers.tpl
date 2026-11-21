{{/* Etiquetas estándar. Uso: include "brewtrack.labels" (list . "api") */}}
{{- define "brewtrack.labels" -}}
{{ include "brewtrack.selector" . }}
app.kubernetes.io/version: {{ (index . 0).Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ (index . 0).Release.Service }}
helm.sh/chart: {{ (index . 0).Chart.Name }}-{{ (index . 0).Chart.Version }}
{{- end }}

{{- define "brewtrack.selector" -}}
app.kubernetes.io/name: {{ (index . 0).Chart.Name }}
app.kubernetes.io/instance: {{ (index . 0).Release.Name }}
app.kubernetes.io/component: {{ index . 1 }}
{{- end }}
