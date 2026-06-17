variable "aws_region" {
  description = "AWS region for the production environment"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name used in resource tags"
  type        = string
  default     = "plane"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "create_eks_cluster" {
  description = "Create a dedicated EKS cluster and VPC for Plane. Set false to deploy into an existing EKS cluster."
  type        = bool
  default     = true
}

variable "existing_eks_cluster_name" {
  description = "Existing EKS cluster name used when create_eks_cluster is false."
  type        = string
  default     = ""
}

variable "existing_vpc_id" {
  description = "Existing VPC ID used for AWS-managed data services when create_eks_cluster is false."
  type        = string
  default     = ""
}

variable "existing_private_subnet_ids" {
  description = "Existing private subnet IDs used for AWS-managed data services when create_eks_cluster is false."
  type        = list(string)
  default     = []
}

variable "existing_vpc_cidr" {
  description = "Existing VPC CIDR used as the default allowed CIDR for AWS-managed data services when create_eks_cluster is false."
  type        = string
  default     = ""
}

variable "existing_eks_oidc_provider_arn" {
  description = "Optional IAM OIDC provider ARN for the existing EKS cluster. When empty, Terraform derives it from the cluster OIDC issuer and account ID."
  type        = string
  default     = ""
}

variable "postgres_mode" {
  description = "PostgreSQL deployment mode: aws-managed creates RDS, in-cluster uses the Plane chart PostgreSQL, external expects PLANE_PGDB_REMOTE_URL."
  type        = string
  default     = "aws-managed"

  validation {
    condition     = contains(["aws-managed", "in-cluster", "external"], var.postgres_mode)
    error_message = "postgres_mode must be aws-managed, in-cluster, or external."
  }
}

variable "redis_mode" {
  description = "Redis deployment mode: aws-managed creates ElastiCache, in-cluster uses the Plane chart Redis, external expects PLANE_REDIS_URL."
  type        = string
  default     = "aws-managed"

  validation {
    condition     = contains(["aws-managed", "in-cluster", "external"], var.redis_mode)
    error_message = "redis_mode must be aws-managed, in-cluster, or external."
  }
}

variable "rabbitmq_mode" {
  description = "RabbitMQ deployment mode: aws-managed creates Amazon MQ, in-cluster uses the Plane chart RabbitMQ, external expects PLANE_RABBITMQ_URL."
  type        = string
  default     = "aws-managed"

  validation {
    condition     = contains(["aws-managed", "in-cluster", "external"], var.rabbitmq_mode)
    error_message = "rabbitmq_mode must be aws-managed, in-cluster, or external."
  }
}

variable "object_store_mode" {
  description = "Object store mode: s3-managed creates an S3 bucket with IRSA, minio-in-cluster uses the Plane chart MinIO, external-s3 expects an existing S3-compatible bucket and credentials."
  type        = string
  default     = "s3-managed"

  validation {
    condition     = contains(["s3-managed", "minio-in-cluster", "external-s3"], var.object_store_mode)
    error_message = "object_store_mode must be s3-managed, minio-in-cluster, or external-s3."
  }
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

variable "eks_cluster_admin_principal_arns" {
  description = "IAM principal ARNs that should have cluster-admin access. CI sets this to the GitHub OIDC role ARN."
  type        = list(string)
  # The cluster creator already receives admin access through
  # eks_bootstrap_cluster_creator_admin. Add only extra admin principals here.
  default = []
}

variable "eks_node_group_name" {
  description = "Managed node group name"
  type        = string
  default     = "main"
}

variable "eks_node_instance_types" {
  description = "Instance types for EKS managed node group"
  type        = list(string)
  # Budget-compatible option when t3.medium is not available.
  # Preferred after free-tier: ["t3.medium"]
  default = ["t3.small"]
}

variable "eks_node_capacity_type" {
  description = "Capacity type for EKS managed node group"
  type        = string
  default     = "ON_DEMAND"
}

variable "eks_node_desired_size" {
  description = "Desired node count for EKS managed node group"
  type        = number
  default     = 3
}

variable "eks_node_min_size" {
  description = "Minimum node count for EKS managed node group"
  type        = number
  default     = 3
}

variable "eks_node_max_size" {
  description = "Maximum node count for EKS managed node group"
  type        = number
  default     = 4
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

variable "eks_enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller IRSA role provisioning"
  type        = bool
  default     = true
}

variable "eks_aws_load_balancer_controller_namespace" {
  description = "Namespace for aws-load-balancer-controller service account"
  type        = string
  default     = "kube-system"
}

variable "eks_aws_load_balancer_controller_service_account_name" {
  description = "Service account name used by aws-load-balancer-controller"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "eks_enable_cluster_autoscaler" {
  description = "Enable cluster-autoscaler IRSA role provisioning"
  type        = bool
  default     = true
}

variable "eks_cluster_autoscaler_namespace" {
  description = "Namespace for cluster-autoscaler service account"
  type        = string
  default     = "kube-system"
}

variable "eks_cluster_autoscaler_service_account_name" {
  description = "Service account name used by cluster-autoscaler"
  type        = string
  default     = "cluster-autoscaler"
}

variable "rds_db_name" {
  description = "Plane PostgreSQL database name"
  type        = string
  default     = "plane"
}

variable "rds_master_username" {
  description = "Master username for Plane PostgreSQL"
  type        = string
  default     = "plane"
}

variable "rds_master_password" {
  description = "Master password for Plane PostgreSQL"
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
  # Use major version so AWS selects a currently available minor release.
  default = "15"
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

variable "rds_performance_insights_enabled" {
  description = "Whether RDS Performance Insights is enabled"
  type        = bool
  default     = false
}

variable "rds_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach PostgreSQL on port 5432. Empty means the VPC CIDR."
  type        = list(string)
  default     = []
}

variable "rabbitmq_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach Amazon MQ RabbitMQ on port 5671. Empty means the VPC CIDR."
  type        = list(string)
  default     = []
}

variable "rabbitmq_engine_version" {
  description = "Amazon MQ RabbitMQ engine version"
  type        = string
  default     = "3.13"
}

variable "rabbitmq_host_instance_type" {
  description = "Amazon MQ broker instance type"
  type        = string
  default     = "mq.t3.micro"
}

variable "rabbitmq_deployment_mode" {
  description = "Amazon MQ deployment mode"
  type        = string
  default     = "SINGLE_INSTANCE"
}

variable "rabbitmq_publicly_accessible" {
  description = "Whether Amazon MQ broker is publicly accessible"
  type        = bool
  default     = false
}

variable "rabbitmq_auto_minor_version_upgrade" {
  description = "Automatically upgrade RabbitMQ minor versions in maintenance windows"
  type        = bool
  default     = true
}

variable "rabbitmq_username" {
  description = "RabbitMQ username"
  type        = string
  default     = "plane"
}

variable "rabbitmq_password" {
  description = "Optional RabbitMQ password override"
  type        = string
  sensitive   = true
  default     = null
  nullable    = true
}

variable "redis_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach Redis on port 6379. Empty means the VPC CIDR."
  type        = list(string)
  default     = []
}

variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_engine_version" {
  description = "ElastiCache Redis engine version"
  type        = string
  default     = "7.1"
}

variable "redis_port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

variable "redis_num_cache_clusters" {
  description = "Number of cache clusters in Redis replication group"
  type        = number
  default     = 1
}

variable "redis_apply_immediately" {
  description = "Whether Redis changes are applied immediately"
  type        = bool
  default     = false
}

variable "redis_auth_token" {
  description = "Optional Redis AUTH token override"
  type        = string
  sensitive   = true
  default     = null
  nullable    = true
}

variable "plane_namespace" {
  description = "Kubernetes namespace where Plane is deployed"
  type        = string
  default     = "plane"
}

variable "plane_service_account_name" {
  description = "Plane Kubernetes service account name used by workloads"
  type        = string
  default     = "plane-srv-account"
}

variable "plane_docstore_bucket_name" {
  description = "Optional override for Plane doc-store S3 bucket name"
  type        = string
  default     = ""
}

variable "plane_docstore_cors_allowed_origins" {
  description = "Allowed browser origins for Plane direct S3 uploads. Replace the bootstrap wildcard with explicit app domains once DNS is stable."
  type        = list(string)
  default     = ["*"]
}
