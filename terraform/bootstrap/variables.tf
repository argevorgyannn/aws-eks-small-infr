variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-north-1"
}

variable "state_bucket_name" {
  description = "S3 bucket for Terraform state (globally unique)."
  type        = string
  default     = "ar-eks-task-tfstate"
}
