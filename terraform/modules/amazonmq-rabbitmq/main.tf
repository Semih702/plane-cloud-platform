locals {
  resolved_password = coalesce(var.password, random_password.user[0].result)
  is_multi_az_mode  = var.deployment_mode == "CLUSTER_MULTI_AZ"
  credentials_secret_name_prefix = coalesce(
    var.credentials_secret_name_prefix,
    "${var.name}/credentials-"
  )

  effective_subnet_ids = (
    local.is_multi_az_mode
    ? slice(var.subnet_ids, 0, 2)
    : [var.subnet_ids[0]]
  )
}

check "required_subnet_count" {
  assert {
    condition = (
      local.is_multi_az_mode
      ? length(var.subnet_ids) >= 2
      : length(var.subnet_ids) >= 1
    )
    error_message = "SINGLE_INSTANCE requires >=1 subnet; CLUSTER_MULTI_AZ requires >=2 subnets."
  }
}

resource "random_password" "user" {
  count   = var.password == null ? 1 : 0
  length  = 24
  special = false
}

resource "aws_security_group" "broker" {
  name        = "${var.name}-sg"
  description = "Security group for Amazon MQ RabbitMQ broker"
  vpc_id      = var.vpc_id

  ingress {
    description = "AMQPS from allowed CIDRs"
    from_port   = 5671
    to_port     = 5671
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

resource "aws_mq_broker" "this" {
  broker_name                = var.name
  engine_type                = "RabbitMQ"
  engine_version             = var.engine_version
  host_instance_type         = var.host_instance_type
  deployment_mode            = var.deployment_mode
  publicly_accessible        = var.publicly_accessible
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  subnet_ids                 = local.effective_subnet_ids
  security_groups            = [aws_security_group.broker.id]

  user {
    username = var.username
    password = local.resolved_password
  }

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
    endpoint = aws_mq_broker.this.instances[0].endpoints[0]
    username = var.username
    password = local.resolved_password
  })
}
