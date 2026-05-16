environment  = "prod"
project_name = "webinfra"
owner        = "platform-team"
aws_region   = "eu-west-1"

vpc_cidr              = "10.2.0.0/16"
public_subnet_cidrs   = ["10.2.1.0/24", "10.2.2.0/24"]
private_subnet_cidrs  = ["10.2.10.0/24", "10.2.11.0/24"]
database_subnet_cidrs = ["10.2.20.0/24", "10.2.21.0/24"]

single_nat_gateway = false

instance_type    = "t3.small"
min_size         = 2
desired_capacity = 2
max_size         = 6

db_instance_class          = "db.t3.small"
db_allocated_storage       = 20
db_multi_az                = true
db_deletion_protection     = true
db_skip_final_snapshot     = false
db_backup_retention_period = 14

force_destroy = false

tags = {}
