# Public access: lb and health check

# Watches Ingress objects and creates the ALB. Its AWS permissions come from the
# Pod Identity association in terraform/infra/lb-controller.tf
resource "helm_release" "lb_controller" {
  name      = "aws-load-balancer-controller"
  namespace = "kube-system"

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "3.6.3"

  values = [yamlencode({
    clusterName  = data.terraform_remote_state.infra.outputs.cluster_name
    region       = var.region
    vpcId        = data.terraform_remote_state.infra.outputs.vpc_id
    replicaCount = 1
    serviceAccount = {
      name = "aws-load-balancer-controller"
    }
  })]
}

resource "time_sleep" "wait_for_alb" {
  create_duration = "120s"

  depends_on = [helm_release.app]
}

data "aws_lb" "app" {
  name = local.alb_name

  depends_on = [time_sleep.wait_for_alb]
}

resource "aws_route53_health_check" "app" {
  fqdn              = data.aws_lb.app.dns_name
  type              = "HTTP"
  port              = 80
  resource_path     = "/healthz"
  request_interval  = 30
  failure_threshold = 3

  tags = {
    Name = "demo-app"
  }
}

output "app_url" {
  value = "http://${data.aws_lb.app.dns_name}"
}
