environment  = "dev"
project_name = "webinfra"
owner        = "platform-team"
aws_region   = "eu-west-1"

vpc_cidr              = "10.0.0.0/16"
public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs  = ["10.0.10.0/24", "10.0.11.0/24"]
database_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24"]

single_nat_gateway = true

instance_type    = "t3.micro"
min_size         = 1
desired_capacity = 1
max_size         = 2

db_instance_class          = "db.t3.micro"
db_allocated_storage       = 20
db_multi_az                = false
db_deletion_protection     = false
db_skip_final_snapshot     = true
db_backup_retention_period = 7

force_destroy = true

tags = {}
