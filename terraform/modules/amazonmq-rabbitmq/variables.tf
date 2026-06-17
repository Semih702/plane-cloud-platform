variable "name" {
  description = "Broker name prefix"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where broker security group is created"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs used by Amazon MQ broker"
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to broker AMQPS port"
  type        = list(string)
}

variable "engine_version" {
  description = "RabbitMQ engine version for Amazon MQ"
  type        = string
  default     = "3.13"
}

variable "host_instance_type" {
  description = "Amazon MQ broker instance type"
  type        = string
  default     = "mq.t3.micro"
}

variable "deployment_mode" {
  description = "Broker deployment mode (SINGLE_INSTANCE or CLUSTER_MULTI_AZ)"
  type        = string
  default     = "SINGLE_INSTANCE"

  validation {
    condition     = contains(["SINGLE_INSTANCE", "CLUSTER_MULTI_AZ"], var.deployment_mode)
    error_message = "deployment_mode must be SINGLE_INSTANCE or CLUSTER_MULTI_AZ."
  }
}

variable "publicly_accessible" {
  description = "Whether broker should be publicly accessible"
  type        = bool
  default     = false
}

variable "auto_minor_version_upgrade" {
  description = "Automatically upgrade to latest minor version during maintenance window"
  type        = bool
  default     = true
}

variable "username" {
  description = "RabbitMQ username"
  type        = string
  default     = "plane"
}

variable "password" {
  description = "Optional RabbitMQ password override; generated when null"
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
  description = "Recovery window (7-30 days) for credentials secret deletion."
  type        = number
  default     = 7

  validation {
    condition     = var.credentials_secret_recovery_window_in_days >= 7 && var.credentials_secret_recovery_window_in_days <= 30
    error_message = "credentials_secret_recovery_window_in_days must be between 7 and 30."
  }
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

