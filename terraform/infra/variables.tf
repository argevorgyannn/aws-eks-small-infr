variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "cluster_name" {
  description = "cluster name"
  type        = string
  default     = "eks-task"
}

variable "kubernetes_version" {
  description = "EKS stable version"
  type        = string
  default     = "1.35"
}

variable "node_instance_types" {
  description = " m7i-flex.large is the most suitable among free tier plan instances"
  type        = list(string)
  default     = ["m7i-flex.large"]
}

variable "api_allowed_cidrs" {
  description = "CIDR to allow public access, access is still restricted by IAM"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
