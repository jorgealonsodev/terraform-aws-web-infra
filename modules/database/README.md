# Database Module

RDS PostgreSQL instance with encrypted storage, environment-provided password, and AWS Secrets Manager integration.

This module creates:
- **RDS Instance**: PostgreSQL with encrypted storage (`storage_encrypted = true`), not publicly accessible
- **Secrets Manager**: Stores the DB password (provided via `var.db_password`) securely; only the secret ARN is exposed as output (never the password value)
- **Environment-aware defaults**: `multi_az`, `deletion_protection`, and `skip_final_snapshot` are controlled via variables per environment

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_db_instance.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_secretsmanager_secret.db_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.db_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allocated_storage"></a> [allocated\_storage](#input\_allocated\_storage) | Allocated storage in GiB | `number` | `20` | no |
| <a name="input_backup_retention_period"></a> [backup\_retention\_period](#input\_backup\_retention\_period) | Number of days to retain automated backups | `number` | `7` | no |
| <a name="input_db_name"></a> [db\_name](#input\_db\_name) | Name of the database to create | `string` | `"appdb"` | no |
| <a name="input_db_password"></a> [db\_password](#input\_db\_password) | Master password for the database (sensitive, no default — set via random\_password) | `string` | n/a | yes |
| <a name="input_db_sg_id"></a> [db\_sg\_id](#input\_db\_sg\_id) | ID of the database security group (from security module) | `string` | n/a | yes |
| <a name="input_db_subnet_group_name"></a> [db\_subnet\_group\_name](#input\_db\_subnet\_group\_name) | Name of the DB subnet group (from networking module) | `string` | n/a | yes |
| <a name="input_db_username"></a> [db\_username](#input\_db\_username) | Master username for the database | `string` | `"appuser"` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Whether to enable deletion protection on the RDS instance | `bool` | `false` | no |
| <a name="input_engine"></a> [engine](#input\_engine) | Database engine to use | `string` | `"postgres"` | no |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | Database engine version | `string` | `"16.3"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (dev, staging, or prod) | `string` | n/a | yes |
| <a name="input_instance_class"></a> [instance\_class](#input\_instance\_class) | RDS instance class | `string` | `"db.t3.micro"` | no |
| <a name="input_multi_az"></a> [multi\_az](#input\_multi\_az) | Whether to enable Multi-AZ deployment | `bool` | `false` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project name prefix for resource naming | `string` | n/a | yes |
| <a name="input_skip_final_snapshot"></a> [skip\_final\_snapshot](#input\_skip\_final\_snapshot) | Whether to skip the final snapshot on deletion | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_db_endpoint"></a> [db\_endpoint](#output\_db\_endpoint) | The connection endpoint for the RDS instance |
| <a name="output_db_identifier"></a> [db\_identifier](#output\_db\_identifier) | The identifier of the RDS instance |
| <a name="output_db_port"></a> [db\_port](#output\_db\_port) | The port the RDS instance is listening on |
| <a name="output_db_secret_arn"></a> [db\_secret\_arn](#output\_db\_secret\_arn) | The ARN of the Secrets Manager secret containing the DB password (never the password value) |
<!-- END_TF_DOCS -->
