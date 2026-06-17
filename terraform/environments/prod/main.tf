data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_eks_cluster" "existing" {
  count = var.create_eks_cluster ? 0 : 1

  name = var.existing_eks_cluster_name
}

locals {
  cluster_name              = var.create_eks_cluster ? "${var.project_name}-${var.environment}-eks" : var.existing_eks_cluster_name
  active_vpc_id             = var.create_eks_cluster ? module.vpc[0].vpc_id : var.existing_vpc_id
  active_private_subnet_ids = var.create_eks_cluster ? module.vpc[0].private_subnet_ids : var.existing_private_subnet_ids
  managed_service_vpc_cidr  = var.create_eks_cluster ? var.vpc_cidr : var.existing_vpc_cidr
  default_allowed_cidr_blocks = (
    local.managed_service_vpc_cidr != "" ? [local.managed_service_vpc_cidr] : []
  )
  existing_eks_oidc_issuer_url      = var.create_eks_cluster ? "" : data.aws_eks_cluster.existing[0].identity[0].oidc[0].issuer
  existing_eks_oidc_issuer_hostpath = replace(local.existing_eks_oidc_issuer_url, "https://", "")
  existing_eks_oidc_provider_arn = (
    var.existing_eks_oidc_provider_arn != "" ?
    var.existing_eks_oidc_provider_arn :
    "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.existing_eks_oidc_issuer_hostpath}"
  )
  plane_oidc_provider_arn = (
    local.use_managed_s3 ?
    (var.create_eks_cluster ? module.eks[0].oidc_provider_arn : data.aws_iam_openid_connect_provider.existing[0].arn) :
    null
  )
  plane_oidc_issuer_hostpath = var.create_eks_cluster ? module.eks[0].oidc_issuer_hostpath : local.existing_eks_oidc_issuer_hostpath
  needs_existing_vpc = (
    !var.create_eks_cluster &&
    (local.use_aws_postgres || local.use_aws_redis || local.use_aws_rabbitmq)
  )
  needs_existing_vpc_cidr = (
    !var.create_eks_cluster &&
    (
      (local.use_aws_postgres && length(var.rds_allowed_cidr_blocks) == 0) ||
      (local.use_aws_redis && length(var.redis_allowed_cidr_blocks) == 0) ||
      (local.use_aws_rabbitmq && length(var.rabbitmq_allowed_cidr_blocks) == 0)
    )
  )
  plane_docstore_bucket_name = var.plane_docstore_bucket_name != "" ? var.plane_docstore_bucket_name : "${var.project_name}-${var.environment}-plane-docstore-${data.aws_caller_identity.current.account_id}"
  use_aws_postgres           = var.postgres_mode == "aws-managed"
  use_aws_redis              = var.redis_mode == "aws-managed"
  use_aws_rabbitmq           = var.rabbitmq_mode == "aws-managed"
  use_managed_s3             = var.object_store_mode == "s3-managed"
  rds_allowed_cidr_blocks    = length(var.rds_allowed_cidr_blocks) > 0 ? var.rds_allowed_cidr_blocks : local.default_allowed_cidr_blocks
  rabbitmq_allowed_cidr_blocks = (
    length(var.rabbitmq_allowed_cidr_blocks) > 0 ? var.rabbitmq_allowed_cidr_blocks : local.default_allowed_cidr_blocks
  )
  redis_allowed_cidr_blocks = length(var.redis_allowed_cidr_blocks) > 0 ? var.redis_allowed_cidr_blocks : local.default_allowed_cidr_blocks
}

data "aws_iam_openid_connect_provider" "existing" {
  count = var.create_eks_cluster || !local.use_managed_s3 ? 0 : 1

  arn = local.existing_eks_oidc_provider_arn
}

module "vpc" {
  count = var.create_eks_cluster ? 1 : 0

  source = "../../modules/vpc"

  name                    = "${var.project_name}-${var.environment}-vpc"
  vpc_cidr                = var.vpc_cidr
  az_count                = var.az_count
  public_subnet_cidrs     = var.public_subnet_cidrs
  private_subnet_cidrs    = var.private_subnet_cidrs
  kubernetes_cluster_name = local.cluster_name

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "eks" {
  count = var.create_eks_cluster ? 1 : 0

  source = "../../modules/eks"

  cluster_name                                      = local.cluster_name
  cluster_version                                   = var.eks_cluster_version
  subnet_ids                                        = module.vpc[0].private_subnet_ids
  endpoint_public_access                            = var.eks_endpoint_public_access
  endpoint_private_access                           = var.eks_endpoint_private_access
  endpoint_public_access_cidrs                      = var.eks_endpoint_public_access_cidrs
  bootstrap_cluster_creator_admin                   = var.eks_bootstrap_cluster_creator_admin
  cluster_admin_principal_arns                      = var.eks_cluster_admin_principal_arns
  node_group_name                                   = var.eks_node_group_name
  node_subnet_ids                                   = module.vpc[0].private_subnet_ids
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
  count = local.use_aws_postgres ? 1 : 0

  source = "../../modules/rds-postgres"

  name                         = "${var.project_name}-${var.environment}-postgres"
  vpc_id                       = local.active_vpc_id
  subnet_ids                   = local.active_private_subnet_ids
  allowed_cidr_blocks          = local.rds_allowed_cidr_blocks
  db_name                      = var.rds_db_name
  master_username              = var.rds_master_username
  master_password              = var.rds_master_password
  instance_class               = var.rds_instance_class
  allocated_storage            = var.rds_allocated_storage
  max_allocated_storage        = var.rds_max_allocated_storage
  engine_version               = var.rds_engine_version
  backup_retention_period      = var.rds_backup_retention_period
  multi_az                     = var.rds_multi_az
  deletion_protection          = var.rds_deletion_protection
  skip_final_snapshot          = var.rds_skip_final_snapshot
  performance_insights_enabled = var.rds_performance_insights_enabled

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "rabbitmq_amazonmq" {
  count = local.use_aws_rabbitmq ? 1 : 0

  source = "../../modules/amazonmq-rabbitmq"

  name                       = "${var.project_name}-${var.environment}-rabbitmq"
  vpc_id                     = local.active_vpc_id
  subnet_ids                 = local.active_private_subnet_ids
  allowed_cidr_blocks        = local.rabbitmq_allowed_cidr_blocks
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
  count = local.use_aws_redis ? 1 : 0

  source = "../../modules/elasticache-redis"

  name                = "${var.project_name}-${var.environment}-redis"
  vpc_id              = local.active_vpc_id
  subnet_ids          = local.active_private_subnet_ids
  allowed_cidr_blocks = local.redis_allowed_cidr_blocks
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
  count = local.use_managed_s3 ? 1 : 0

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
  count = local.use_managed_s3 ? 1 : 0

  bucket = aws_s3_bucket.plane_docstore[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "plane_docstore" {
  count = local.use_managed_s3 ? 1 : 0

  bucket = aws_s3_bucket.plane_docstore[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "plane_docstore" {
  count = local.use_managed_s3 ? 1 : 0

  bucket = aws_s3_bucket.plane_docstore[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "plane_docstore" {
  count = local.use_managed_s3 ? 1 : 0

  bucket = aws_s3_bucket.plane_docstore[0].id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD", "POST", "PUT"]
    allowed_origins = var.plane_docstore_cors_allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_iam_role" "plane_irsa" {
  count = local.use_managed_s3 ? 1 : 0

  name = "${var.project_name}-${var.environment}-plane-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.plane_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.plane_oidc_issuer_hostpath}:aud" = "sts.amazonaws.com"
            "${local.plane_oidc_issuer_hostpath}:sub" = "system:serviceaccount:${var.plane_namespace}:${var.plane_service_account_name}"
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
  count = local.use_managed_s3 ? 1 : 0

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
        Resource = aws_s3_bucket.plane_docstore[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.plane_docstore[0].arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "plane_docstore_s3" {
  count = local.use_managed_s3 ? 1 : 0

  role       = aws_iam_role.plane_irsa[0].name
  policy_arn = aws_iam_policy.plane_docstore_s3[0].arn
}

resource "random_password" "plane_secret_key" {
  length  = 64
  special = false
}

resource "random_password" "plane_live_server_secret_key" {
  length  = 48
  special = false
}

resource "random_password" "plane_local_postgres_password" {
  length  = 24
  special = false
}

resource "random_password" "plane_local_rabbitmq_password" {
  length  = 24
  special = false
}

resource "random_password" "plane_local_minio_password" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "plane_app" {
  name_prefix             = "${var.project_name}-${var.environment}-plane-app-"
  recovery_window_in_days = 7

  lifecycle {
    precondition {
      condition     = var.create_eks_cluster || var.existing_eks_cluster_name != ""
      error_message = "existing_eks_cluster_name is required when create_eks_cluster is false."
    }

    precondition {
      condition = (
        !local.needs_existing_vpc ||
        (var.existing_vpc_id != "" && length(var.existing_private_subnet_ids) > 0)
      )
      error_message = "existing_vpc_id and existing_private_subnet_ids are required when create_eks_cluster is false and any data service mode is aws-managed."
    }

    precondition {
      condition     = !local.needs_existing_vpc_cidr || var.existing_vpc_cidr != ""
      error_message = "existing_vpc_cidr is required when create_eks_cluster is false and aws-managed data services use default allowed CIDR blocks."
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-plane-app"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "plane_app" {
  secret_id = aws_secretsmanager_secret.plane_app.id
  secret_string = jsonencode({
    secret_key             = random_password.plane_secret_key.result
    live_server_secret_key = random_password.plane_live_server_secret_key.result
    postgres_password      = random_password.plane_local_postgres_password.result
    rabbitmq_password      = random_password.plane_local_rabbitmq_password.result
    minio_root_password    = random_password.plane_local_minio_password.result
  })
}
