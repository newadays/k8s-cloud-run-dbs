{{/* Chart-wide names and labels. */}}
{{- define "api.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{- define "api.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "api.labels" -}}
app.kubernetes.io/name: {{ include "api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{- define "api.selectorLabels" -}}
app: api
app.kubernetes.io/name: {{ include "api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* The GCP project is never written into the chart; it arrives with --set gcp.project=... */}}
{{- define "api.project" -}}
{{- required "gcp.project is required: helm ... --set gcp.project=$PROJECT" .Values.gcp.project -}}
{{- end -}}

{{/* Image repository: explicit value, else <region>-docker.pkg.dev/<project>/apps/api */}}
{{- define "api.imageRepository" -}}
{{- default (printf "%s-docker.pkg.dev/%s/apps/api" .Values.gcp.region (include "api.project" .)) .Values.image.repository -}}
{{- end -}}

{{/* Image reference: digest wins over tag; tag falls back to appVersion. */}}
{{- define "api.image" -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" (include "api.imageRepository" .) .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" (include "api.imageRepository" .) (default .Chart.AppVersion .Values.image.tag) -}}
{{- end -}}
{{- end -}}

{{/* Cloud SQL connection name: <project>:<region>:<instance> */}}
{{- define "api.sqlInstanceConnectionName" -}}
{{- printf "%s:%s:%s" (include "api.project" .) .Values.gcp.region (required "cloudSqlProxy.instance is required when the proxy is enabled" .Values.cloudSqlProxy.instance) -}}
{{- end -}}

{{/* Guardrail: production releases must pin by digest. */}}
{{- define "api.requireDigest" -}}
{{- if and (eq .Release.Namespace "two-tier-prod") (not .Values.image.digest) -}}
{{- fail "image.digest is required for releases into two-tier-prod" -}}
{{- end -}}
{{- end -}}
