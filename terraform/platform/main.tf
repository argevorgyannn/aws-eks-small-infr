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
  })]
}
