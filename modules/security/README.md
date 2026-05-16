# Security Module

Security groups for a 3-tier web architecture with cross-referenced isolation.

This module creates three security groups that enforce tiered network isolation:
- **ALB SG**: Public-facing, allows HTTP/HTTPS from anywhere
- **App SG**: Private tier, allows ingress only from the ALB security group
- **DB SG**: Isolated tier, allows ingress only from the App security group, no internet egress

All cross-tier references use security group IDs (not CIDR blocks) for effective layer isolation.

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
| [aws_security_group.alb_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.app_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.db_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_app_port"></a> [app\_port](#input\_app\_port) | Application port for the app security group ingress rule | `number` | `80` | no |
| <a name="input_db_port"></a> [db\_port](#input\_db\_port) | Database port for the DB security group ingress rule | `number` | `5432` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (dev, staging, or prod) | `string` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project name prefix for resource naming | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | VPC CIDR block for restricting DB egress to VPC-only | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where security groups will be created | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_sg_id"></a> [alb\_sg\_id](#output\_alb\_sg\_id) | The ID of the ALB security group |
| <a name="output_app_sg_id"></a> [app\_sg\_id](#output\_app\_sg\_id) | The ID of the application security group |
| <a name="output_db_sg_id"></a> [db\_sg\_id](#output\_db\_sg\_id) | The ID of the database security group |
<!-- END_TF_DOCS -->
