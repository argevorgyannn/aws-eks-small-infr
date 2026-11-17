# Monitoring and logging  

# Secrets: External Secrets Operator copies secrets from AWS Secrets Manager into the cluster
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true

  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = "2.15.0"
}

# Store definition and the Grafana secret. Creates the monitoring namespace,
# because Grafana needs the secret before it starts.
resource "helm_release" "secrets_config" {
  name             = "secrets-config"
  namespace        = "monitoring"
  create_namespace = true

  chart = "${path.module}/../../charts/secrets-config"

  values = [yamlencode({
    region = var.region
  })]

  depends_on = [helm_release.external_secrets]
}

# Prometheus, Grafana, kube-state-metrics and node-exporter
resource "helm_release" "kube_prometheus_stack" {
  name      = "kube-prometheus-stack"
  namespace = "monitoring"

  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "93.3.0"
  timeout    = 900

  values = [file("${path.module}/values/kube-prometheus-stack.yaml")]

  depends_on = [helm_release.secrets_config]
}

# Log storage
resource "helm_release" "loki" {
  name      = "loki"
  namespace = "monitoring"

  repository = "https://grafana-community.github.io/helm-charts"
  chart      = "loki"
  version    = "6.55.0"
  timeout    = 600

  values = [file("${path.module}/values/loki-values.yaml")]

  depends_on = [helm_release.kube_prometheus_stack]
}

# Log collector: ships pod logs to Loki
resource "helm_release" "alloy" {
  name      = "alloy"
  namespace = "monitoring"

  repository = "https://grafana.github.io/helm-charts"
  chart      = "alloy"
  version    = "1.16.0"

  values = [file("${path.module}/values/alloy.yaml")]

  depends_on = [helm_release.loki]
}

# Grafana dashboard for the app, loaded by the Grafana sidecar
resource "helm_release" "app_dashboard" {
  name      = "app-dashboard"
  namespace = "monitoring"

  chart = "${path.module}/../../charts/app-dashboard"

  depends_on = [helm_release.kube_prometheus_stack]
}

locals {
  alb_name = "eks-task"
}

resource "helm_release" "app" {
  name             = "demo-app"
  namespace        = "demo"
  create_namespace = true

  chart = "${path.module}/../../charts/demo-app"

  values = [yamlencode({
    image = {
      repository = data.terraform_remote_state.infra.outputs.ecr_repository_url
      tag        = var.app_image_tag
    }
    # The ServiceMonitor CRD comes from kube-prometheus-stack
    serviceMonitor = {
      enabled = true
    }
    # Public access through an ALB, created by the load balancer controller
    ingress = {
      enabled = true
      albName = local.alb_name
    }
  })]

  # The controller must be running first, otherwise the Ingress is not picked up
  depends_on = [helm_release.kube_prometheus_stack, helm_release.lb_controller]
}
