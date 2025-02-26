{{- /*
  Customization:
  Added additional OAuth related env vars:
    GF_AUTH_GENERIC_OAUTH_AUTH_URL
    GF_SERVER_ROOT_URL
  Added a value check in the env range loop:
  {{- range $key, $value := .Values.env }}
  {{- if $value }}
      - name: "{{ tpl $key $ }}"
        value: "{{ tpl (print $value) $ }}"
  {{- end }}
  {{- end }}
  Moved grafana-sc-datasources container from initContainers to containers section
*/ -}}
{{- define "grafana.pod" -}}
{{- if .Values.schedulerName }}
schedulerName: "{{ .Values.schedulerName }}"
{{- end }}
serviceAccountName: {{ template "grafana.serviceAccountName" . }}
{{- if .Values.podSecurityContext }}
securityContext:
{{ toYaml .Values.podSecurityContext | indent 2 }}
{{- end }}
{{- if .Values.hostAliases }}
hostAliases:
{{ toYaml .Values.hostAliases | indent 2 }}
{{- end }}
{{- if or .Values.priorityClassName .Values.global.priorityClassName }}
priorityClassName: {{ coalesce .Values.priorityClassName .Values.global.priorityClassName }}
{{- end }}
{{- if ( or .Values.persistence.enabled .Values.dashboards .Values.sidecar.notifiers.enabled .Values.extraInitContainers) }}
initContainers:
{{- end }}
{{- if ( and .Values.persistence.enabled .Values.initChownData.enabled ) }}
  - name: init-chown-data
    image: "{{ .Values.initChownData.image.repository }}:{{ .Values.initChownData.image.tag }}"
    imagePullPolicy: {{ .Values.initChownData.image.pullPolicy }}
    {{- if .Values.initChownData.securityContext }}
    securityContext:
{{ toYaml .Values.initChownData.securityContext | indent 6 }}
    {{- end }}
    command: ["chown", "-R", "{{ .Values.podSecurityContext.runAsUser }}:{{ .Values.podSecurityContext.runAsGroup }}", "/var/lib/grafana"]
    resources:
{{ toYaml .Values.initChownData.resources | indent 6 }}
    volumeMounts:
      - name: storage
        mountPath: "/var/lib/grafana"
{{- if .Values.persistence.subPath }}
        subPath: {{ .Values.persistence.subPath }}
{{- end }}
{{- end }}
{{- if .Values.dashboards }}
  - name: download-dashboards
    {{- if .Values.downloadDashboardsImage.sha }}
    image: "{{ .Values.downloadDashboardsImage.repository }}:{{ .Values.downloadDashboardsImage.tag }}@sha256:{{ .Values.downloadDashboardsImage.sha }}"
    {{- else }}
    image: "{{ .Values.downloadDashboardsImage.repository }}:{{ .Values.downloadDashboardsImage.tag }}"
    {{- end }}
    imagePullPolicy: {{ .Values.downloadDashboardsImage.pullPolicy }}
    command: ["/bin/sh"]
    args: [ "-c", "mkdir -p /var/lib/grafana/dashboards/default && /bin/sh /etc/grafana/download_dashboards.sh" ]
    resources:
{{ toYaml .Values.downloadDashboards.resources | indent 6 }}
{{- if .Values.downloadDashboards.securityContext }}
    securityContext:
{{ toYaml .Values.downloadDashboards.securityContext | indent 6 }}
{{- end }}
    env:
{{- range $key, $value := .Values.downloadDashboards.env }}
      - name: "{{ $key }}"
        value: "{{ $value }}"
{{- end }}
{{- if .Values.downloadDashboards.envFromSecret }}
    envFrom:
      - secretRef:
          name: {{ tpl .Values.downloadDashboards.envFromSecret . }}
{{- end }}
    volumeMounts:
      - name: config
        mountPath: "/etc/grafana/download_dashboards.sh"
        subPath: download_dashboards.sh
      - name: storage
        mountPath: "/var/lib/grafana"
{{- if .Values.persistence.subPath }}
        subPath: {{ .Values.persistence.subPath }}
{{- end }}
    {{- range .Values.extraSecretMounts }}
      - name: {{ .name }}
        mountPath: {{ .mountPath }}
        readOnly: {{ .readOnly }}
    {{- end }}
{{- end }}
{{- if .Values.sidecar.notifiers.enabled }}
  - name: {{ template "grafana.name" . }}-sc-notifiers
    image: "{{ include "imageurl" (dict "reg" .Values.global.containerRegistry "img" .Values.global.images.k8s_sidecar) }}"
    imagePullPolicy: {{ .Values.sidecar.imagePullPolicy }}
    env:
      - name: IGNORE_ALREADY_PROCESSED
        value: "true"
      - name: METHOD
        value: LIST
      - name: LABEL
        value: "{{ .Values.sidecar.notifiers.label }}"
      - name: FOLDER
        value: "/etc/grafana/provisioning/notifiers"
      - name: RESOURCE
        value: {{ quote .Values.sidecar.notifiers.resource }}
      {{- if .Values.sidecar.enableUniqueFilenames }}
      - name: UNIQUE_FILENAMES
        value: "{{ .Values.sidecar.enableUniqueFilenames }}"
      {{- end }}
      {{- if .Values.sidecar.notifiers.searchNamespace }}
      - name: NAMESPACE
        value: "{{ .Values.sidecar.notifiers.searchNamespace }}"
      {{- end }}
      {{- if .Values.sidecar.skipTlsVerify }}
      - name: SKIP_TLS_VERIFY
        value: "{{ .Values.sidecar.skipTlsVerify }}"
      {{- end }}
    resources:
{{ toYaml .Values.sidecar.resources | indent 6 }}
{{- if .Values.sidecar.securityContext }}
    securityContext:
{{ toYaml .Values.sidecar.securityContext | indent 6 }}
{{- end }}
    volumeMounts:
      - name: sc-notifiers-volume
        mountPath: "/etc/grafana/provisioning/notifiers"
{{- end}}
{{- if .Values.extraInitContainers }}
{{ toYaml .Values.extraInitContainers | indent 2 }}
{{- end }}
{{- if .Values.image.pullSecrets }}
imagePullSecrets:
{{- range .Values.image.pullSecrets }}
  - name: {{ . }}
{{- end}}
{{- end }}
containers:
{{- if .Values.sidecar.datasources.enabled }}
  - name: {{ template "grafana.name" . }}-sc-datasources-watcher
    image: "{{ include "imageurl" (dict "reg" .Values.global.containerRegistry "img" .Values.global.images.k8s_sidecar) }}"
    imagePullPolicy: {{ .Values.sidecar.imagePullPolicy }}
    env:
      - name: IGNORE_ALREADY_PROCESSED
        value: "true"
      - name: METHOD
        value: {{ .Values.sidecar.datasources.watchMethod }}
      - name: LABEL
        value: "{{ .Values.sidecar.datasources.label }}"
      {{- if .Values.sidecar.datasources.labelValue }}
      - name: LABEL_VALUE
        value: {{ quote .Values.sidecar.datasources.labelValue }}
      {{- end }}
      - name: FOLDER
        value: "/etc/grafana/provisioning/datasources"
      - name: RESOURCE
        value: {{ quote .Values.sidecar.datasources.resource }}
      {{- if .Values.sidecar.enableUniqueFilenames }}
      - name: UNIQUE_FILENAMES
        value: "{{ .Values.sidecar.enableUniqueFilenames }}"
      {{- end }}
      {{- if .Values.sidecar.datasources.searchNamespace }}
      - name: NAMESPACE
        value: "{{ .Values.sidecar.datasources.searchNamespace }}"
      {{- end }}
      {{- if .Values.sidecar.skipTlsVerify }}
      - name: SKIP_TLS_VERIFY
        value: "{{ .Values.sidecar.skipTlsVerify }}"
      {{- end }}
    resources:
{{ toYaml .Values.sidecar.resources | indent 6 }}
{{- if .Values.sidecar.securityContext }}
    securityContext:
{{ toYaml .Values.sidecar.securityContext | indent 6 }}
{{- end }}
    volumeMounts:
      - name: sc-datasources-volume
        mountPath: "/etc/grafana/provisioning/datasources"
{{- end}}
{{- if .Values.sidecar.dashboards.enabled }}
  - name: {{ template "grafana.name" . }}-sc-dashboard-watcher
    image: "{{ include "imageurl" (dict "reg" .Values.global.containerRegistry "img" .Values.global.images.k8s_sidecar) }}"
    imagePullPolicy: {{ .Values.sidecar.imagePullPolicy }}
    env:
      - name: IGNORE_ALREADY_PROCESSED
        value: "true"
      - name: METHOD
        value: {{ .Values.sidecar.dashboards.watchMethod }}
      - name: LABEL
        value: "{{ .Values.sidecar.dashboards.label }}"
      {{- if .Values.sidecar.dashboards.labelValue }}
      - name: LABEL_VALUE
        value: {{ quote .Values.sidecar.dashboards.labelValue }}
      {{- end }}
      - name: FOLDER
        value: "{{ .Values.sidecar.dashboards.folder }}{{- with .Values.sidecar.dashboards.defaultFolderName }}/{{ . }}{{- end }}"
      - name: RESOURCE
        value: {{ quote .Values.sidecar.dashboards.resource }}
      {{- if .Values.sidecar.enableUniqueFilenames }}
      - name: UNIQUE_FILENAMES
        value: "{{ .Values.sidecar.enableUniqueFilenames }}"
      {{- end }}
      {{- if .Values.sidecar.dashboards.searchNamespace }}
      - name: NAMESPACE
        value: "{{ .Values.sidecar.dashboards.searchNamespace }}"
      {{- end }}
      {{- if .Values.sidecar.skipTlsVerify }}
      - name: SKIP_TLS_VERIFY
        value: "{{ .Values.sidecar.skipTlsVerify }}"
      {{- end }}
      {{- if .Values.sidecar.dashboards.folderAnnotation }}
      - name: FOLDER_ANNOTATION
        value: "{{ .Values.sidecar.dashboards.folderAnnotation }}"
      {{- end }}
    resources:
{{ toYaml .Values.sidecar.resources | indent 6 }}
{{- if .Values.sidecar.securityContext }}
    securityContext:
{{ toYaml .Values.sidecar.securityContext | indent 6 }}
{{- end }}
    volumeMounts:
      - name: sc-dashboard-volume
        mountPath: {{ .Values.sidecar.dashboards.folder | quote }}
{{- end}}
  - name: {{ .Chart.Name }}
    image: "{{ include "imageurl" (dict "reg" .Values.global.containerRegistry "img" .Values.global.images.grafana) }}"
    imagePullPolicy: {{ .Values.image.pullPolicy }}
  {{- if .Values.command }}
    command:
    {{- range .Values.command }}
      - {{ . }}
    {{- end }}
  {{- end}}
  {{- if .Values.containerSecurityContext }}
    securityContext:
{{- toYaml .Values.containerSecurityContext | nindent 6 }}
{{- end }}
    volumeMounts:
      - name: config
        mountPath: "/etc/grafana/grafana.ini"
        subPath: grafana.ini
      {{- if .Values.ldap.enabled }}
      - name: ldap
        mountPath: "/etc/grafana/ldap.toml"
        subPath: ldap.toml
      {{- end }}
      {{- range .Values.extraConfigmapMounts }}
      - name: {{ .name }}
        mountPath: {{ .mountPath }}
        subPath: {{ .subPath | default "" }}
        readOnly: {{ .readOnly }}
      {{- end }}
      - name: storage
        mountPath: "/var/lib/grafana"
{{- if .Values.persistence.subPath }}
        subPath: {{ .Values.persistence.subPath }}
{{- end }}
{{- if .Values.dashboards }}
{{- range $provider, $dashboards := .Values.dashboards }}
{{- range $key, $value := $dashboards }}
{{- if (or (hasKey $value "json") (hasKey $value "file")) }}
      - name: dashboards-{{ $provider }}
        mountPath: "/var/lib/grafana/dashboards/{{ $provider }}/{{ $key }}.json"
        subPath: "{{ $key }}.json"
{{- end }}
{{- end }}
{{- end }}
{{- end -}}
{{- if .Values.dashboardsConfigMaps }}
{{- range (keys .Values.dashboardsConfigMaps | sortAlpha) }}
      - name: dashboards-{{ . }}
        mountPath: "/var/lib/grafana/dashboards/{{ . }}"
{{- end }}
{{- end }}
{{- if .Values.datasources }}
      - name: config
        mountPath: "/etc/grafana/provisioning/datasources/datasources.yaml"
        subPath: datasources.yaml
{{- end }}
{{- if .Values.notifiers }}
      - name: config
        mountPath: "/etc/grafana/provisioning/notifiers/notifiers.yaml"
        subPath: notifiers.yaml
{{- end }}
{{- if .Values.dashboardProviders }}
      - name: config
        mountPath: "/etc/grafana/provisioning/dashboards/dashboardproviders.yaml"
        subPath: dashboardproviders.yaml
{{- end }}
{{- if .Values.sidecar.dashboards.enabled }}
      - name: sc-dashboard-volume
        mountPath: {{ .Values.sidecar.dashboards.folder | quote }}
{{ if .Values.sidecar.dashboards.SCProvider }}
      - name: sc-dashboard-provider
        mountPath: "/etc/grafana/provisioning/dashboards/sc-dashboardproviders.yaml"
        subPath: provider.yaml
{{- end}}
{{- end}}
{{- if .Values.sidecar.datasources.enabled }}
      - name: sc-datasources-volume
        mountPath: "/etc/grafana/provisioning/datasources"
{{- end}}
{{- if .Values.sidecar.notifiers.enabled }}
      - name: sc-notifiers-volume
        mountPath: "/etc/grafana/provisioning/notifiers"
{{- end}}
    {{- range .Values.extraSecretMounts }}
      - name: {{ .name }}
        mountPath: {{ .mountPath }}
        readOnly: {{ .readOnly }}
        subPath: {{ .subPath | default "" }}
    {{- end }}
    {{- range .Values.extraVolumeMounts }}
      - name: {{ .name }}
        mountPath: {{ .mountPath }}
        subPath: {{ .subPath | default "" }}
        readOnly: {{ .readOnly }}
    {{- end }}
    {{- range .Values.extraEmptyDirMounts }}
      - name: {{ .name }}
        mountPath: {{ .mountPath }}
    {{- end }}
    ports:
      - name: {{ .Values.service.portName }}
        containerPort: {{ .Values.service.port }}
        protocol: TCP
      - name: {{ .Values.podPortName }}
        containerPort: 3000
        protocol: TCP
    env:
      {{- if and (not .Values.env.GF_SECURITY_ADMIN_USER) (not .Values.env.GF_SECURITY_DISABLE_INITIAL_ADMIN_CREATION) }}
      - name: GF_SECURITY_ADMIN_USER
        valueFrom:
          secretKeyRef:
            name: {{ .Values.admin.existingSecret | default (include "grafana.fullname" .) }}
            key: {{ .Values.admin.userKey | default "admin-user" }}
      {{- end }}
      {{- if and (not .Values.env.GF_SECURITY_ADMIN_PASSWORD) (not .Values.env.GF_SECURITY_ADMIN_PASSWORD__FILE) (not .Values.env.GF_SECURITY_DISABLE_INITIAL_ADMIN_CREATION) }}
      - name: GF_SECURITY_ADMIN_PASSWORD
        valueFrom:
          secretKeyRef:
            name: {{ .Values.admin.existingSecret | default (include "grafana.fullname" .) }}
            key: {{ .Values.admin.passwordKey | default "admin-password" }}
      {{- end }}
      {{- if .Values.plugins }}
      - name: GF_INSTALL_PLUGINS
        valueFrom:
          configMapKeyRef:
            name: {{ template "grafana.fullname" . }}
            key: plugins
      {{- end }}
      {{- if .Values.smtp.existingSecret }}
      - name: GF_SMTP_USER
        valueFrom:
          secretKeyRef:
            name: {{ .Values.smtp.existingSecret }}
            key: {{ .Values.smtp.userKey | default "user" }}
      - name: GF_SMTP_PASSWORD
        valueFrom:
          secretKeyRef:
            name: {{ .Values.smtp.existingSecret }}
            key: {{ .Values.smtp.passwordKey | default "password" }}
      {{- end }}
      {{ if .Values.imageRenderer.enabled }}
      - name: GF_RENDERING_SERVER_URL
        value: http://{{ template "grafana.fullname" . }}-image-renderer.{{ template "grafana.namespace" . }}:{{ .Values.imageRenderer.service.port }}/render
      - name: GF_RENDERING_CALLBACK_URL
        value: http://{{ template "grafana.fullname" . }}.{{ template "grafana.namespace" . }}:{{ .Values.service.port }}/
      {{ end }}
      {{- if not .Values.env.GF_SERVER_ROOT_URL }}
      - name: GF_SERVER_ROOT_URL
        value: "https://grafana.{{ .Values.global.domainName }}/"
      {{- end }}
      - name: GF_PATHS_DATA
        value: {{ (get .Values "grafana.ini").paths.data }}
      - name: GF_PATHS_LOGS
        value: {{ (get .Values "grafana.ini").paths.logs }}
      - name: GF_PATHS_PLUGINS
        value: {{ (get .Values "grafana.ini").paths.plugins }}
      - name: GF_PATHS_PROVISIONING
        value: {{ (get .Values "grafana.ini").paths.provisioning }}
    {{- range $key, $value := .Values.envValueFrom }}
      - name: {{ $key | quote }}
        valueFrom:
{{ toYaml $value | indent 10 }}
    {{- end }}
    {{- range $key, $value := .Values.env }}
    {{- if $value }}
      - name: "{{ tpl $key $ }}"
        value: "{{ tpl (print $value) $ }}"
    {{- end }}
{{- end }}
    {{- if .Values.envFromSecret }}
    envFrom:
      - secretRef:
          name: {{ tpl .Values.envFromSecret . }}
    {{- end }}
    {{- if .Values.envRenderSecret }}
    envFrom:
      - secretRef:
          name: {{ template "grafana.fullname" . }}-env
    {{- end }}
    livenessProbe:
{{ toYaml .Values.livenessProbe | indent 6 }}
    readinessProbe:
{{ toYaml .Values.readinessProbe | indent 6 }}
    resources:
{{ toYaml .Values.resources | indent 6 }}
{{- with .Values.extraContainers }}
{{ tpl . $ | indent 2 }}
{{- end }}
{{- with .Values.nodeSelector }}
nodeSelector:
{{ toYaml . | indent 2 }}
{{- end }}
{{- with .Values.affinity }}
affinity:
{{ toYaml . | indent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
{{ toYaml . | indent 2 }}
{{- end }}
volumes:
  - name: config
    configMap:
      name: {{ template "grafana.fullname" . }}
{{- range .Values.extraConfigmapMounts }}
  - name: {{ .name }}
    configMap:
      name: {{ .configMap }}
{{- end }}
  {{- if .Values.dashboards }}
    {{- range (keys .Values.dashboards | sortAlpha) }}
  - name: dashboards-{{ . }}
    configMap:
      name: {{ template "grafana.fullname" $ }}-dashboards-{{ . }}
    {{- end }}
  {{- end }}
  {{- if .Values.dashboardsConfigMaps }}
    {{ $root := . }}
    {{- range $provider, $name := .Values.dashboardsConfigMaps }}
  - name: dashboards-{{ $provider }}
    configMap:
      name: {{ tpl $name $root }}
    {{- end }}
  {{- end }}
  {{- if .Values.ldap.enabled }}
  - name: ldap
    secret:
      {{- if .Values.ldap.existingSecret }}
      secretName: {{ .Values.ldap.existingSecret }}
      {{- else }}
      secretName: {{ template "grafana.fullname" . }}
      {{- end }}
      items:
        - key: ldap-toml
          path: ldap.toml
  {{- end }}
{{- if and .Values.persistence.enabled (eq .Values.persistence.type "pvc") }}
  - name: storage
    persistentVolumeClaim:
      claimName: {{ .Values.persistence.existingClaim | default (include "grafana.fullname" .) }}
{{- else if and .Values.persistence.enabled (eq .Values.persistence.type "statefulset") }}
# nothing
{{- else }}
  - name: storage
{{- if .Values.persistence.inMemory.enabled }}
    emptyDir:
      medium: Memory
{{- if .Values.persistence.inMemory.sizeLimit }}
      sizeLimit: {{ .Values.persistence.inMemory.sizeLimit }}
{{- end -}}
{{- else }}
    emptyDir: {}
{{- end -}}
{{- end -}}
{{- if .Values.sidecar.dashboards.enabled }}
  - name: sc-dashboard-volume
    emptyDir: {}
{{- if .Values.sidecar.dashboards.SCProvider }}
  - name: sc-dashboard-provider
    configMap:
      name: {{ template "grafana.fullname" . }}-config-dashboards
{{- end }}
{{- end }}
{{- if .Values.sidecar.datasources.enabled }}
  - name: sc-datasources-volume
    emptyDir: {}
{{- end -}}
{{- if .Values.sidecar.notifiers.enabled }}
  - name: sc-notifiers-volume
    emptyDir: {}
{{- end -}}
{{- range .Values.extraSecretMounts }}
{{- if .secretName }}
  - name: {{ .name }}
    secret:
      secretName: {{ .secretName }}
      defaultMode: {{ .defaultMode }}
{{- else if .projected }}
  - name: {{ .name }}
    projected: {{- toYaml .projected | nindent 6 }}
{{- else if .csi }}
  - name: {{ .name }}
    csi: {{- toYaml .csi | nindent 6 }}
{{- end }}
{{- end }}
{{- range .Values.extraVolumeMounts }}
  - name: {{ .name }}
      {{- if .existingClaim }}
    persistentVolumeClaim:
      claimName: {{ .existingClaim }}
    {{- else if .hostPath }}
    hostPath:
      path: {{ .hostPath }}
    {{- else }}
    emptyDir: {}
    {{- end }}
{{- end }}
{{- range .Values.extraEmptyDirMounts }}
  - name: {{ .name }}
    emptyDir: {}
{{- end -}}
{{- if .Values.extraContainerVolumes }}
{{ toYaml .Values.extraContainerVolumes | indent 2 }}
{{- end }}
{{- end }}
