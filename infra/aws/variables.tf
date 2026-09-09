variable "aws_region" {
  description = "AWS region for source archives."
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Deployment environment written to AWS resource tags."
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be staging or production."
  }
}

variable "source_archive_bucket_name" {
  description = "Globally unique private S3 bucket name for retained source artifacts."
  type        = string
}

variable "candidate_retention_days" {
  description = "Days to keep an artifact that never completed database publication."
  type        = number
  default     = 2
}

variable "rollback_retention_days" {
  description = "Days to keep the previously validated artifact after promotion."
  type        = number
  default     = 14
}
