variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-north-1"
}

variable "app_image_tag" {
  description = "Tag of the application image in ECR."
  type        = string
  default     = "0.1.0"
}
