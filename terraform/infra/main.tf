data "aws_availability_zones" "available" {
  state = "available"
}

# Nodes live in private subnets, load balancers in public ones.
# One shared NAT gateway keeps the cost down (not highly available).
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = var.cluster_name
  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  # Tags the AWS Load Balancer Controller uses to find subnets
  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.api_allowed_cidrs

  # The identity running Terraform becomes cluster admin (EKS access entry)
  enable_cluster_creator_admin_permissions = true

  # Pod Identity is used for pod IAM access, so the IRSA OIDC provider is not needed
  enable_irsa = false

  enabled_log_types                      = ["audit"]
  cloudwatch_log_group_retention_in_days = 7

  addons = {
    coredns                = {}
    kube-proxy             = {}
    eks-pod-identity-agent = { before_compute = true }
    vpc-cni                = { before_compute = true }
  }

  eks_managed_node_groups = {
    spot = {
      capacity_type  = "SPOT"
      instance_types = var.node_instance_types

      min_size     = 2
      desired_size = 2
      max_size     = 3
    }
  }
}
