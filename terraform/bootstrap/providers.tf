provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "eks-task"
      ManagedBy = "terraform"
    }
  }
}
