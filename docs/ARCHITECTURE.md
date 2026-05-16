# Architecture

## Overview

This project implements a **3-tier web architecture** on AWS using Terraform.
The design separates the presentation, application, and data layers into isolated subnets
to maximize security and availability.

## Architecture Diagram

```
                           Internet
                              |
                      [ Internet Gateway ]
                              |
         +--------------------+--------------------+
         |          VPC  10.0.0.0/16               |
         |                                         |
         |   AZ-a                  AZ-b            |
         |  +-----------+        +-----------+     |
         |  | Subnet    |        | Subnet    |     |  <- PUBLIC Subnets
         |  | public    |        | public    |     |     (ALB + NAT Gateway)
         |  |  [ ALB ]  |        |  [ ALB ]  |     |
         |  +-----+-----+        +-----+-----+     |
         |        |                    |          |
         |  +-----v-----+        +-----v-----+     |
         |  | Subnet    |        | Subnet    |     |  <- PRIVATE Subnets
         |  | private   |        | private   |     |     (EC2 in Auto Scaling Group)
         |  | [ EC2 ]   |        | [ EC2 ]   |     |
         |  +-----+-----+        +-----+-----+     |
         |        |                    |          |
         |  +-----v-----+        +-----v-----+     |
         |  | Subnet    |        | Subnet    |     |  <- DATABASE Subnets (isolated)
         |  | database  |        | database  |     |     (RDS Multi-AZ in prod)
         |  +-----------+        +-----------+     |
         +-----------------------------------------+

         [ S3 Bucket ]  <- object storage (assets / logs)
```

## Traffic Flow

1. Inbound traffic reaches the **Application Load Balancer (ALB)** in the public subnets.
2. The ALB distributes load across the **EC2** instances in the **Auto Scaling Group**, located in the private subnets.
3. Instances access **RDS** in the database subnets, which are isolated with no direct internet access.
4. Instances reach the internet (system updates, etc.) through the **NAT Gateway**.
5. **S3** provides object storage for static assets and logs.

## Design Decisions and Trade-offs

### 3-tier subnet architecture

**Decision:** Separate into public, private, and database subnets.

**Why:** Layer isolation reduces the attack surface. An attacker compromising the ALB has no direct access to EC2 instances or the database.

**Trade-off:** Higher network complexity and more resources (route tables, subnets) compared to a flat architecture.

### NAT Gateway: single vs multi-AZ

**Decision:** A single NAT Gateway in dev/staging, one per AZ in prod.

**Why:** NAT Gateway costs ~33 USD/month. In non-production environments, the savings justify the risk of a single point of failure. In production, availability takes priority.

**Trade-off:** If the single NAT Gateway fails in dev/staging, private instances lose internet access until it recovers.

### RDS: single-AZ vs Multi-AZ

**Decision:** RDS single-AZ in dev/staging, Multi-AZ in prod.

**Why:** Multi-AZ doubles the RDS instance cost. In production, automatic failover justifies the additional cost.

**Trade-off:** In dev/staging, an AZ outage means the database is unavailable until AWS recovers it.

### Security Groups by reference (not by CIDR)

**Decision:** Security groups reference each other by ID, not by IP range.

**Why:** EC2 instance IPs can change (auto-scaling). Referencing by security group ID keeps rules correct regardless of IPs.

**Trade-off:** Rules are harder to audit than flat CIDR-based rules.

### Passwords managed automatically

**Decision:** The RDS password is generated with `random_password` and stored in AWS Secrets Manager.

**Why:** Avoids versioning secrets in the repository and ensures strong, unique passwords per deployment.

**Trade-off:** Secrets Manager costs ~0.40 USD/month per secret and requires IAM access.

### Remote state with locking

**Decision:** S3 backend + DynamoDB for Terraform state.

**Why:** Enables team collaboration without state conflicts and protects against concurrent writes via DynamoDB locking.

**Trade-off:** Adds a dependency on S3 and DynamoDB before any `terraform init` can succeed.

## Module Descriptions

| Module | Description |
|--------|-------------|
| **networking** | VPC, subnets (public/private/database), Internet Gateway, NAT Gateway(s), route tables, DB subnet group |
| **security** | Security Groups for ALB, App, and DB with inter-tier isolation |
| **storage** | Hardened S3 bucket with versioning, encryption, public access blocking, and lifecycle rules |
| **database** | RDS PostgreSQL instance with encryption, auto-generated password, and Secrets Manager storage |
| **compute** | ALB, Launch Template (Amazon Linux 2023), Auto Scaling Group, IAM role, CPU-based scaling policy |

## Environments

| Parameter | dev | staging | prod |
|-----------|-----|---------|------|
| VPC CIDR | `10.0.0.0/16` | `10.1.0.0/16` | `10.2.0.0/16` |
| NAT Gateway | Single | Single | Multi-AZ |
| EC2 Instance | t3.micro | t3.micro | t3.small |
| ASG min/desired/max | 1/1/2 | 1/2/3 | 2/2/6 |
| RDS Instance | db.t3.micro | db.t3.micro | db.t3.small |
| RDS Multi-AZ | No | No | Yes |

Each environment invokes the same modules with different `terraform.tfvars` values.
There is no infrastructure logic in the environment directories — configuration only.
