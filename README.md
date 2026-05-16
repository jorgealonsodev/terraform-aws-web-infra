# Terraform AWS Web Infrastructure

Infrastructure as Code (IaC) for a 3-tier web architecture on AWS using Terraform.

## Architecture

```
                    Internet
                       |
               [ Internet Gateway ]
                       |
      +----------------+----------------+
      |          VPC                     |
      |                                  |
      |  AZ-a            AZ-b            |
      | +------+        +------+         |
      | |Public|        |Public|         |  <- ALB + NAT Gateway
      | | [ALB]|        | [ALB]|         |
      | +--+---+        +--+---+         |
      |    |               |             |
      | +--v---+        +--v---+         |
      | |Private|       |Private|        |  <- EC2 Auto Scaling Group
      | | [EC2] |       | [EC2] |        |
      | +--+----+       +--+----+        |
      |    |               |             |
      | +--v----+       +--v----+        |
      | |Database|      |Database|       |  <- RDS (isolated)
      | +--------+      +--------+       |
      +----------------------------------+

      [ S3 Bucket ]  <- static assets / logs
```

## Stack

- **Terraform** >= 1.7
- **AWS Provider** ~> 5.x
- **Region**: eu-west-1 (default)

## Repository Structure

```
├── modules/          # Shared infrastructure modules
│   ├── networking/   # VPC, subnets, gateways, routing
│   ├── security/     # Security Groups (ALB, App, DB)
│   ├── compute/      # ALB, ASG, Launch Template, IAM
│   ├── database/     # RDS + Secrets Manager
│   └── storage/      # S3 bucket (hardened)
├── environments/     # Environment-specific configurations
│   ├── dev/
│   ├── staging/
│   └── prod/
├── scripts/          # Automation scripts
└── docs/             # Architecture and cost documentation
```

## Prerequisites

- AWS CLI configured with appropriate credentials
- Docker (for Terraform execution via `hashicorp/terraform` image)
- AWS account with permissions for VPC, EC2, RDS, S3, IAM

## Quick Start

```bash
# 1. Bootstrap the remote state backend
./scripts/bootstrap-backend.sh

# 2. Initialize and plan (dev environment)
cd environments/dev
terraform init
terraform plan

# 3. Apply
terraform apply
```

> **Note:** This project uses Docker for Terraform execution. See the Makefile for Docker-based targets.

## Environments

| Parameter | dev | staging | prod |
|-----------|-----|---------|------|
| VPC CIDR | `10.0.0.0/16` | `10.1.0.0/16` | `10.2.0.0/16` |
| NAT Gateway | Single | Single | Multi-AZ |
| EC2 Instance | t3.micro | t3.micro | t3.small |
| RDS Instance | db.t3.micro | db.t3.micro | db.t3.small |
| RDS Multi-AZ | No | No | Yes |

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Cost Estimates](docs/COSTS.md)
