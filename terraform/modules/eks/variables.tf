variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for EKS control plane ENIs"
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Enable public endpoint access"
  type        = bool
  default     = true
}

variable "endpoint_private_access" {
  description = "Enable private endpoint access"
  type        = bool
  default     = false
}

variable "endpoint_public_access_cidrs" {
  description = "Allowed CIDR blocks to reach public endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "bootstrap_cluster_creator_admin" {
  description = "Grant cluster creator admin access during bootstrap"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "node_group_name" {
  description = "Managed node group name"
  type        = string
  default     = "default"
}

variable "node_subnet_ids" {
  description = "Private subnet IDs where worker nodes run"
  type        = list(string)
}

variable "node_instance_types" {
  description = "EC2 instance types for worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_capacity_type" {
  description = "Capacity type for node group"
  type        = string
  default     = "ON_DEMAND"
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 3
}

variable "node_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 3
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 6
}

variable "node_disk_size" {
  description = "Disk size in GiB for worker nodes"
  type        = number
  default     = 40
}

variable "node_update_max_unavailable" {
  description = "Maximum number of unavailable nodes during updates"
  type        = number
  default     = 1
}

variable "enable_ebs_csi_addon" {
  description = "Enable managed aws-ebs-csi-driver addon"
  type        = bool
  default     = true
}

variable "cluster_admin_principal_arns" {
  description = "IAM principal ARNs to grant EKS cluster-admin access"
  type        = list(string)
  default     = []
}

variable "enable_aws_load_balancer_controller" {
  description = "Create IRSA role and policy for AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "aws_load_balancer_controller_namespace" {
  description = "Namespace for aws-load-balancer-controller service account"
  type        = string
  default     = "kube-system"
}

variable "aws_load_balancer_controller_service_account_name" {
  description = "Service account name for aws-load-balancer-controller"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "enable_cluster_autoscaler" {
  description = "Create IRSA role and policy for Kubernetes cluster-autoscaler"
  type        = bool
  default     = true
}

variable "cluster_autoscaler_namespace" {
  description = "Namespace for cluster-autoscaler service account"
  type        = string
  default     = "kube-system"
}

variable "cluster_autoscaler_service_account_name" {
  description = "Service account name for cluster-autoscaler"
  type        = string
  default     = "cluster-autoscaler"
}
