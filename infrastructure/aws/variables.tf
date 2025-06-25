variable "app_name" {
  description = "Application name prefix"
  type        = string
  default     = "ci-nodejs-example"
}

variable "ecr_image_url" {
  description = "Full ECR image URI w/ tag"
  type        = string
  default     = "673026752288.dkr.ecr.us-west-2.amazonaws.com/ci-nodejs-example:latest"
}
