locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# ──────────────────────────────────────────────
# Generate secure database password
# ──────────────────────────────────────────────
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ──────────────────────────────────────────────
# Secrets Manager secret for DB password
# ──────────────────────────────────────────────
resource "aws_secretsmanager_secret" "db_password" {
  name        = "${local.name_prefix}-db-password"
  description = "Master password for ${local.name_prefix} RDS instance"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-password"
  })
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

# ──────────────────────────────────────────────
# RDS PostgreSQL instance
# ──────────────────────────────────────────────
resource "aws_db_instance" "main" {
  identifier = "${local.name_prefix}-db"

  # Engine
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  # Storage
  allocated_storage     = var.allocated_storage
  storage_encrypted     = true
  storage_type          = "gp3"
  max_allocated_storage = 100

  # Database
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Network
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [var.db_sg_id]

  # Availability
  multi_az = var.multi_az

  # Backup
  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Lifecycle
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.name_prefix}-db-final-snapshot"

  # Monitoring
  publicly_accessible = false

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db"
  })
}
