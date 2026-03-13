data "aws_caller_identity" "current" {}

locals {
  plane_docstore_bucket_name = var.plane_docstore_bucket_name != "" ? var.plane_docstore_bucket_name : "${var.project_name}-${var.environment}-plane-docstore-${data.aws_caller_identity.current.account_id}"
}

module "vpc" {
  source = "../../modules/vpc"

  name                    = "${var.project_name}-${var.environment}-vpc"
  vpc_cidr                = var.vpc_cidr
  az_count                = var.az_count
  public_subnet_cidrs     = var.public_subnet_cidrs
  private_subnet_cidrs    = var.private_subnet_cidrs
  kubernetes_cluster_name = "${var.project_name}-${var.environment}-eks"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "eks" {
  source = "../../modules/eks"

  cluster_name                                      = "${var.project_name}-${var.environment}-eks"
  cluster_version                                   = var.eks_cluster_version
  subnet_ids                                        = module.vpc.private_subnet_ids
  endpoint_public_access                            = var.eks_endpoint_public_access
  endpoint_private_access                           = var.eks_endpoint_private_access
  endpoint_public_access_cidrs                      = var.eks_endpoint_public_access_cidrs
  bootstrap_cluster_creator_admin                   = var.eks_bootstrap_cluster_creator_admin
  cluster_admin_principal_arns                      = var.eks_cluster_admin_principal_arns
  node_group_name                                   = var.eks_node_group_name
  node_subnet_ids                                   = module.vpc.private_subnet_ids
  node_instance_types                               = var.eks_node_instance_types
  node_capacity_type                                = var.eks_node_capacity_type
  node_desired_size                                 = var.eks_node_desired_size
  node_min_size                                     = var.eks_node_min_size
  node_max_size                                     = var.eks_node_max_size
  node_disk_size                                    = var.eks_node_disk_size
  node_update_max_unavailable                       = var.eks_node_update_max_unavailable
  enable_aws_load_balancer_controller               = var.eks_enable_aws_load_balancer_controller
  aws_load_balancer_controller_namespace            = var.eks_aws_load_balancer_controller_namespace
  aws_load_balancer_controller_service_account_name = var.eks_aws_load_balancer_controller_service_account_name
  enable_cluster_autoscaler                         = var.eks_enable_cluster_autoscaler
  cluster_autoscaler_namespace                      = var.eks_cluster_autoscaler_namespace
  cluster_autoscaler_service_account_name           = var.eks_cluster_autoscaler_service_account_name

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "rds_postgres" {
  source = "../../modules/rds-postgres"

  name                    = "${var.project_name}-${var.environment}-postgres"
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnet_ids
  allowed_cidr_blocks     = var.rds_allowed_cidr_blocks
  db_name                 = var.rds_db_name
  master_username         = var.rds_master_username
  master_password         = var.rds_master_password
  instance_class          = var.rds_instance_class
  allocated_storage       = var.rds_allocated_storage
  max_allocated_storage   = var.rds_max_allocated_storage
  engine_version          = var.rds_engine_version
  backup_retention_period = var.rds_backup_retention_period
  multi_az                = var.rds_multi_az
  deletion_protection     = var.rds_deletion_protection
  skip_final_snapshot     = var.rds_skip_final_snapshot

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "rabbitmq_amazonmq" {
  source = "../../modules/amazonmq-rabbitmq"

  name                       = "${var.project_name}-${var.environment}-rabbitmq"
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.private_subnet_ids
  allowed_cidr_blocks        = var.rabbitmq_allowed_cidr_blocks
  engine_version             = var.rabbitmq_engine_version
  host_instance_type         = var.rabbitmq_host_instance_type
  deployment_mode            = var.rabbitmq_deployment_mode
  publicly_accessible        = var.rabbitmq_publicly_accessible
  auto_minor_version_upgrade = var.rabbitmq_auto_minor_version_upgrade
  username                   = var.rabbitmq_username
  password                   = var.rabbitmq_password

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "redis_elasticache" {
  source = "../../modules/elasticache-redis"

  name                = "${var.project_name}-${var.environment}-redis"
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnet_ids
  allowed_cidr_blocks = var.redis_allowed_cidr_blocks
  node_type           = var.redis_node_type
  engine_version      = var.redis_engine_version
  port                = var.redis_port
  num_cache_clusters  = var.redis_num_cache_clusters
  apply_immediately   = var.redis_apply_immediately
  auth_token          = var.redis_auth_token

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket" "plane_docstore" {
  bucket = local.plane_docstore_bucket_name

  tags = {
    Name        = local.plane_docstore_bucket_name
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "plane-docstore"
  }
}

resource "aws_s3_bucket_versioning" "plane_docstore" {
  bucket = aws_s3_bucket.plane_docstore.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "plane_docstore" {
  bucket = aws_s3_bucket.plane_docstore.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "plane_docstore" {
  bucket = aws_s3_bucket.plane_docstore.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "plane_irsa" {
  name = "${var.project_name}-${var.environment}-plane-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${module.eks.oidc_issuer_hostpath}:aud" = "sts.amazonaws.com"
            "${module.eks.oidc_issuer_hostpath}:sub" = "system:serviceaccount:${var.plane_namespace}:${var.plane_service_account_name}"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-plane-irsa-role"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_policy" "plane_docstore_s3" {
  name        = "${var.project_name}-${var.environment}-plane-docstore-s3"
  description = "S3 access policy for Plane doc-store via IRSA"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = aws_s3_bucket.plane_docstore.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.plane_docstore.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "plane_docstore_s3" {
  role       = aws_iam_role.plane_irsa.name
  policy_arn = aws_iam_policy.plane_docstore_s3.arn
}
