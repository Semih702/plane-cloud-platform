variable "aws_region" {
  description = "AWS region for the production environment"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name used in resource tags"
  type        = string
  default     = "openproject"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "172.26.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to use"
  type        = number
  default     = 3
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks in AZ order"
  type        = list(string)
  default = [
    "172.26.0.0/22",
    "172.26.4.0/22",
    "172.26.8.0/22"
  ]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks in AZ order"
  type        = list(string)
  default = [
    "172.26.12.0/22",
    "172.26.16.0/22",
    "172.26.20.0/22"
  ]
}

variable "eks_cluster_version" {
  description = "EKS Kubernetes version for the control plane"
  type        = string
  default     = "1.30"
}

variable "eks_endpoint_public_access" {
  description = "Whether the EKS API endpoint is publicly accessible"
  type        = bool
  default     = true
}

variable "eks_endpoint_private_access" {
  description = "Whether the EKS API endpoint is privately accessible from within the VPC"
  type        = bool
  default     = true
}

variable "eks_endpoint_public_access_cidrs" {
  description = "Allowed CIDR blocks for public EKS API endpoint access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "eks_bootstrap_cluster_creator_admin" {
  description = "Automatically grants cluster creator admin permissions"
  type        = bool
  default     = true
}

variable "eks_node_group_name" {
  description = "Managed node group name"
  type        = string
  default     = "main"
}

variable "eks_node_instance_types" {
  description = "Instance types for EKS managed node group"
  type        = list(string)
  # Free-tier compatible for now.
  # Preferred after free-tier: ["t3.medium"]
  default = ["t3.micro"]
}

variable "eks_node_capacity_type" {
  description = "Capacity type for EKS managed node group"
  type        = string
  default     = "ON_DEMAND"
}

variable "eks_node_desired_size" {
  description = "Desired node count for EKS managed node group"
  type        = number
  default     = 2
}

variable "eks_node_min_size" {
  description = "Minimum node count for EKS managed node group"
  type        = number
  default     = 2
}

variable "eks_node_max_size" {
  description = "Maximum node count for EKS managed node group"
  type        = number
  default     = 3
}

variable "eks_node_disk_size" {
  description = "Disk size in GiB for EKS managed node group"
  type        = number
  default     = 40
}

variable "eks_node_update_max_unavailable" {
  description = "Maximum unavailable nodes during node group updates"
  type        = number
  default     = 1
}

variable "rds_db_name" {
  description = "OpenProject PostgreSQL database name"
  type        = string
  default     = "openproject"
}

variable "rds_master_username" {
  description = "Master username for OpenProject PostgreSQL"
  type        = string
  default     = "openproject"
}

variable "rds_master_password" {
  description = "Master password for OpenProject PostgreSQL"
  type        = string
  sensitive   = true
  default     = null
  nullable    = true
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  # Free-tier compatible for now.
  # Preferred after free-tier: "db.t3.medium"
  default = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GiB"
  type        = number
  default     = 50
}

variable "rds_max_allocated_storage" {
  description = "RDS maximum autoscaling storage in GiB"
  type        = number
  default     = 200
}

variable "rds_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.7"
}

variable "rds_backup_retention_period" {
  description = "RDS backup retention period in days"
  type        = number
  # Free-tier compatible for now.
  # Preferred after free-tier: 7
  default = 1
}

variable "rds_multi_az" {
  description = "Whether RDS should be Multi-AZ"
  type        = bool
  default     = false
}

variable "rds_deletion_protection" {
  description = "Whether deletion protection is enabled for RDS"
  type        = bool
  default     = false
}

variable "rds_skip_final_snapshot" {
  description = "Whether to skip final snapshot on RDS destroy"
  type        = bool
  default     = true
}

variable "rds_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach PostgreSQL on port 5432"
  type        = list(string)
  default     = ["172.26.0.0/16"]
}
