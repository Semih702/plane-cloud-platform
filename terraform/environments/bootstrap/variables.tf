variable "aws_region" {
  description = "AWS region where backend resources are created"
  type        = string
  default     = "eu-west-1"
}

variable "state_bucket_name" {
  description = "S3 bucket name for Terraform remote state"
  type        = string
  default     = ""
}

variable "lock_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "plane-cloud-platform-tf-locks"
}

