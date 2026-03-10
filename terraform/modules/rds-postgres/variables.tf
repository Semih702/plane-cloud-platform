variable "name" {
  description = "Name prefix for RDS resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the database runs"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for DB subnet group"
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to PostgreSQL"
  type        = list(string)
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "openproject"
}

variable "master_username" {
  description = "Master username for PostgreSQL"
  type        = string
  default     = "openproject"
}

variable "master_password" {
  description = "Master password for PostgreSQL"
  type        = string
  sensitive   = true
  default     = null
  nullable    = true
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "allocated_storage" {
  description = "Initial allocated storage in GiB"
  type        = number
  default     = 50
}

variable "max_allocated_storage" {
  description = "Maximum autoscaling storage in GiB"
  type        = number
  default     = 200
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15"
}

variable "backup_retention_period" {
  description = "Backup retention in days"
  type        = number
  default     = 7
}

variable "multi_az" {
  description = "Whether to create a Multi-AZ RDS instance"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Protect DB from accidental deletion"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
