variable "name" {
  description = "Replication group identifier prefix"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where Redis security group is created"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs used by Redis subnet group"
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to Redis port"
  type        = list(string)
}

variable "node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

variable "num_cache_clusters" {
  description = "Number of cache clusters in replication group"
  type        = number
  default     = 1
}

variable "apply_immediately" {
  description = "Whether modifications are applied immediately"
  type        = bool
  default     = false
}

variable "auth_token" {
  description = "Optional Redis AUTH token override; generated when null"
  type        = string
  sensitive   = true
  default     = null
  nullable    = true
}

variable "credentials_secret_name" {
  description = "Optional explicit name for the credentials secret. When null, a unique name is generated from name_prefix."
  type        = string
  default     = null
  nullable    = true
}

variable "credentials_secret_name_prefix" {
  description = "Optional prefix for auto-generated credentials secret name. Used only when credentials_secret_name is null."
  type        = string
  default     = null
  nullable    = true
}

variable "credentials_secret_recovery_window_in_days" {
  description = "Recovery window for credentials secret deletion. Ignored when force-delete is enabled."
  type        = number
  default     = 7

  validation {
    condition     = var.credentials_secret_recovery_window_in_days >= 7 && var.credentials_secret_recovery_window_in_days <= 30
    error_message = "credentials_secret_recovery_window_in_days must be between 7 and 30."
  }
}

variable "credentials_secret_force_delete_without_recovery" {
  description = "Force-delete credentials secret immediately to avoid pending-deletion name lock."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
