variable "aws_region" {
  description = "AWS region emulated by LocalStack."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name used to identify project resources."
  type        = string
  default     = "aws-secure-evidence-api"
}