output "vpc_id" {
  description = "VPC ID used by this deployment"
  value       = local.active_vpc_id
}

output "availability_zones" {
  description = "Availability zones selected for the created VPC, or empty when using an existing cluster"
  value       = var.create_eks_cluster ? module.vpc[0].availability_zones : []
}

output "public_subnet_ids" {
  description = "Public subnet IDs in AZ order, or empty when using an existing cluster"
  value       = var.create_eks_cluster ? module.vpc[0].public_subnet_ids : []
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by this deployment"
  value       = local.active_private_subnet_ids
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs in AZ order, or empty when using an existing cluster"
  value       = var.create_eks_cluster ? module.vpc[0].nat_gateway_ids : []
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = local.cluster_name
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = var.create_eks_cluster ? module.eks[0].cluster_arn : data.aws_eks_cluster.existing[0].arn
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = var.create_eks_cluster ? module.eks[0].cluster_endpoint : data.aws_eks_cluster.existing[0].endpoint
}

output "eks_cluster_security_group_id" {
  description = "EKS cluster managed security group ID"
  value       = var.create_eks_cluster ? module.eks[0].cluster_security_group_id : data.aws_eks_cluster.existing[0].vpc_config[0].cluster_security_group_id
}

output "eks_node_group_name" {
  description = "EKS managed node group name created by this kit, or empty when using an existing cluster"
  value       = var.create_eks_cluster ? module.eks[0].node_group_name : ""
}

output "eks_aws_load_balancer_controller_irsa_role_arn" {
  description = "IRSA role ARN for aws-load-balancer-controller created by this kit, or null when using an existing cluster"
  value       = var.create_eks_cluster ? module.eks[0].aws_load_balancer_controller_irsa_role_arn : null
}

output "eks_cluster_autoscaler_irsa_role_arn" {
  description = "IRSA role ARN for cluster-autoscaler created by this kit, or null when using an existing cluster"
  value       = var.create_eks_cluster ? module.eks[0].cluster_autoscaler_irsa_role_arn : null
}

output "rds_instance_identifier" {
  description = "RDS PostgreSQL instance identifier"
  value       = local.use_aws_postgres ? module.rds_postgres[0].db_instance_identifier : null
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint address"
  value       = local.use_aws_postgres ? module.rds_postgres[0].db_instance_endpoint : null
}

output "rds_port" {
  description = "RDS PostgreSQL port"
  value       = local.use_aws_postgres ? module.rds_postgres[0].db_instance_port : null
}

output "rds_db_name" {
  description = "RDS PostgreSQL database name"
  value       = local.use_aws_postgres ? module.rds_postgres[0].db_name : null
}

output "rds_credentials_secret_arn" {
  description = "Secrets Manager ARN containing PostgreSQL credentials"
  value       = local.use_aws_postgres ? module.rds_postgres[0].credentials_secret_arn : null
}

output "rabbitmq_broker_id" {
  description = "Amazon MQ broker ID"
  value       = local.use_aws_rabbitmq ? module.rabbitmq_amazonmq[0].broker_id : null
}

output "rabbitmq_broker_endpoint" {
  description = "Amazon MQ RabbitMQ endpoint"
  value       = local.use_aws_rabbitmq ? module.rabbitmq_amazonmq[0].broker_endpoint : null
}

output "rabbitmq_credentials_secret_arn" {
  description = "Secrets Manager ARN containing RabbitMQ credentials"
  value       = local.use_aws_rabbitmq ? module.rabbitmq_amazonmq[0].credentials_secret_arn : null
}

output "redis_replication_group_id" {
  description = "ElastiCache Redis replication group ID"
  value       = local.use_aws_redis ? module.redis_elasticache[0].replication_group_id : null
}

output "redis_primary_endpoint_address" {
  description = "ElastiCache Redis primary endpoint address"
  value       = local.use_aws_redis ? module.redis_elasticache[0].primary_endpoint_address : null
}

output "redis_port" {
  description = "ElastiCache Redis port"
  value       = local.use_aws_redis ? module.redis_elasticache[0].port : null
}

output "redis_credentials_secret_arn" {
  description = "Secrets Manager ARN containing Redis endpoint and auth token"
  value       = local.use_aws_redis ? module.redis_elasticache[0].credentials_secret_arn : null
}

output "plane_docstore_bucket_name" {
  description = "Plane doc-store S3 bucket name"
  value       = local.use_managed_s3 ? aws_s3_bucket.plane_docstore[0].bucket : null
}

output "plane_irsa_role_arn" {
  description = "IAM role ARN used by Plane service account via IRSA"
  value       = local.use_managed_s3 ? aws_iam_role.plane_irsa[0].arn : null
}

output "plane_app_secret_arn" {
  description = "Secrets Manager ARN containing Plane application secrets"
  value       = aws_secretsmanager_secret.plane_app.arn
}
