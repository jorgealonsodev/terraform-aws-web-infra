# ──────────────────────────────────────────────
# Networking — VPC, subnets, gateways, routing
# ──────────────────────────────────────────────
module "networking" {
  source = "../../modules/networking"

  project_name          = var.project_name
  environment           = var.environment
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs
  single_nat_gateway    = var.single_nat_gateway
  tags                  = var.tags
}

# ──────────────────────────────────────────────
# Security — ALB, App, DB security groups
# ──────────────────────────────────────────────
module "security" {
  source = "../../modules/security"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.networking.vpc_id
  vpc_cidr     = module.networking.vpc_cidr
  tags         = var.tags
}

# ──────────────────────────────────────────────
# Storage — hardened S3 bucket
# ──────────────────────────────────────────────
module "storage" {
  source = "../../modules/storage"

  project_name  = var.project_name
  environment   = var.environment
  force_destroy = var.force_destroy
  tags          = var.tags
}

# ──────────────────────────────────────────────
# Database — RDS PostgreSQL with Secrets Manager
# ──────────────────────────────────────────────
module "database" {
  source = "../../modules/database"

  project_name            = var.project_name
  environment             = var.environment
  db_subnet_group_name    = module.networking.db_subnet_group_name
  db_sg_id                = module.security.db_sg_id
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  multi_az                = var.db_multi_az
  deletion_protection     = var.db_deletion_protection
  skip_final_snapshot     = var.db_skip_final_snapshot
  backup_retention_period = var.db_backup_retention_period
  db_password             = random_password.db_password.result
  tags                    = var.tags
}

# ──────────────────────────────────────────────
# Compute — ALB, ASG, Launch Template, scaling
# ──────────────────────────────────────────────
module "compute" {
  source = "../../modules/compute"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
  alb_sg_id          = module.security.alb_sg_id
  app_sg_id          = module.security.app_sg_id
  instance_type      = var.instance_type
  min_size           = var.min_size
  max_size           = var.max_size
  desired_capacity   = var.desired_capacity
  tags               = var.tags
}

# ──────────────────────────────────────────────
# Local password generation for database module
# ──────────────────────────────────────────────
resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}
