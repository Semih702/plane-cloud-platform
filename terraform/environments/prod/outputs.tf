output "vpc_id" {
  description = "Created VPC ID"
  value       = module.vpc.vpc_id
}

output "availability_zones" {
  description = "Availability zones selected for this VPC"
  value       = module.vpc.availability_zones
}

output "public_subnet_ids" {
  description = "Public subnet IDs in AZ order"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs in AZ order"
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs in AZ order"
  value       = module.vpc.nat_gateway_ids
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
  description = "EKS cluster managed security group ID"
  value       = module.eks.cluster_security_group_id
}

output "eks_node_group_name" {
  description = "EKS managed node group name"
  value       = module.eks.node_group_name
}

output "eks_aws_load_balancer_controller_irsa_role_arn" {
  description = "IRSA role ARN for aws-load-balancer-controller"
  value       = module.eks.aws_load_balancer_controller_irsa_role_arn
}

output "rds_instance_identifier" {
  description = "RDS PostgreSQL instance identifier"
  value       = module.rds_postgres.db_instance_identifier
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint address"
  value       = module.rds_postgres.db_instance_endpoint
}

output "rds_port" {
  description = "RDS PostgreSQL port"
  value       = module.rds_postgres.db_instance_port
}

output "rds_db_name" {
  description = "RDS PostgreSQL database name"
  value       = module.rds_postgres.db_name
}

output "rds_credentials_secret_arn" {
  description = "Secrets Manager ARN containing PostgreSQL credentials"
  value       = module.rds_postgres.credentials_secret_arn
}

output "plane_docstore_bucket_name" {
  description = "Plane doc-store S3 bucket name"
  value       = aws_s3_bucket.plane_docstore.bucket
}

output "plane_irsa_role_arn" {
  description = "IAM role ARN used by Plane service account via IRSA"
  value       = aws_iam_role.plane_irsa.arn
}
