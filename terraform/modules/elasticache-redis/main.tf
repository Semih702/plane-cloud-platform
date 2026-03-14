locals {
  resolved_auth_token = coalesce(var.auth_token, random_password.auth_token[0].result)
  credentials_secret_name_prefix = coalesce(
    var.credentials_secret_name_prefix,
    "${var.name}/credentials-"
  )
}

resource "random_password" "auth_token" {
  count   = var.auth_token == null ? 1 : 0
  length  = 32
  special = false
}

resource "aws_security_group" "redis" {
  name        = "${var.name}-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = var.vpc_id

  ingress {
    description = "Redis from allowed CIDRs"
    from_port   = var.port
    to_port     = var.port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-sg"
  })
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name}-subnet-group"
  })
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id       = var.name
  description                = "Redis replication group for ${var.name}"
  engine                     = "redis"
  engine_version             = var.engine_version
  node_type                  = var.node_type
  num_cache_clusters         = var.num_cache_clusters
  port                       = var.port
  subnet_group_name          = aws_elasticache_subnet_group.this.name
  security_group_ids         = [aws_security_group.redis.id]
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = local.resolved_auth_token
  automatic_failover_enabled = var.num_cache_clusters > 1
  multi_az_enabled           = var.num_cache_clusters > 1
  auto_minor_version_upgrade = true
  apply_immediately          = var.apply_immediately

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_secretsmanager_secret" "credentials" {
  name                          = var.credentials_secret_name
  name_prefix                   = var.credentials_secret_name == null ? local.credentials_secret_name_prefix : null
  recovery_window_in_days       = var.credentials_secret_force_delete_without_recovery ? null : var.credentials_secret_recovery_window_in_days
  force_delete_without_recovery = var.credentials_secret_force_delete_without_recovery

  tags = merge(var.tags, {
    Name = "${var.name}-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "credentials" {
  secret_id = aws_secretsmanager_secret.credentials.id
  secret_string = jsonencode({
    endpoint   = aws_elasticache_replication_group.this.primary_endpoint_address
    port       = var.port
    auth_token = local.resolved_auth_token
  })
}
