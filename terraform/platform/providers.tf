provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "eks-task"
      ManagedBy = "terraform"
    }
  }
}

# fetch info
data "terraform_remote_state" "infra" {
  backend = "s3"

  config = {
    bucket = "ar-eks-task-tfstate"
    key    = "infra/terraform.tfstate"
    region = var.region
  }
}

provider "helm" {
  kubernetes = {
    host                   = data.terraform_remote_state.infra.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_certificate_authority_data)

# short lived token for auth
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.infra.outputs.cluster_name, "--region", var.region]
    }
  }
}
