locals {
  resolved_master_password = coalesce(var.master_password, random_password.master[0].result)
}

resource "random_password" "master" {
  count            = var.master_password == null ? 1 : 0
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name}-subnet-group"
  })
}

resource "aws_security_group" "this" {
  name        = "${var.name}-sg"
  description = "Security group for PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from allowed CIDRs"
    from_port   = 5432
    to_port     = 5432
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

resource "aws_db_instance" "this" {
  identifier                   = var.name
  engine                       = "postgres"
  engine_version               = var.engine_version
  instance_class               = var.instance_class
  allocated_storage            = var.allocated_storage
  max_allocated_storage        = var.max_allocated_storage
  storage_type                 = "gp3"
  db_name                      = var.db_name
  username                     = var.master_username
  password                     = local.resolved_master_password
  db_subnet_group_name         = aws_db_subnet_group.this.name
  vpc_security_group_ids       = [aws_security_group.this.id]
  publicly_accessible          = false
  multi_az                     = var.multi_az
  backup_retention_period      = var.backup_retention_period
  deletion_protection          = var.deletion_protection
  skip_final_snapshot          = var.skip_final_snapshot
  auto_minor_version_upgrade   = true
  performance_insights_enabled = true
  storage_encrypted            = true
  apply_immediately            = false

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.name}/credentials"
  recovery_window_in_days = 7

  tags = merge(var.tags, {
    Name = "${var.name}-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    engine   = "postgres"
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    database = var.db_name
    username = var.master_username
    password = local.resolved_master_password
  })
}
