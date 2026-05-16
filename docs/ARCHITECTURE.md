# Architecture

**Decision:** 3-tier isolation with security groups chained by ID — ALB in public subnets,
EC2 in private subnets, RDS in isolated database subnets. No direct internet path to data.

## Traffic Flow — Happy Path

1. Request → **ALB** (public subnet, port 80) → Target Group health check `/`
2. ALB → **EC2** instance (private subnet, auto-scaled) → serves `nginx`
3. EC2 → **RDS** (database subnet, no internet route, SG-restricted to `app_sg` only)
4. EC2 → **NAT Gateway** → Internet (OS updates, external API calls)
5. Static assets → **S3** (public access blocked, direct from app or CloudFront in future)

```
Internet → IGW → VPC 10.x.0.0/16
  ├── Public subnets     → ALB (Internet-facing) + NAT Gateway
  ├── Private subnets    → EC2 ASG (target group member)
  ├── Database subnets   → RDS (isolated, no route to IGW or NAT)
  └── [S3]               → Object storage (outside VPC)
```

## Security Group Chain

```
0.0.0.0/0 :80,443  →  [ alb_sg ]  →  [ app_sg ]  →  [ db_sg ]  →  No egress
                         ▲                ▲               ▲
                     public tier      private tier    database tier
```

| SG | Ingress from | Egress to | Purpose |
|----|-------------|-----------|---------|
| `alb_sg` | 0.0.0.0/0 :80,443 | All | Public entry point |
| `app_sg` | `alb_sg` ID, port `app_port` | All | Application tier |
| `db_sg` | `app_sg` ID, port `db_port` (5432) | VPC CIDR only | Database isolation |

> **Key design choice:** cross-tier references use security group IDs, never CIDR blocks.
> When an ASG replaces an EC2 instance with a new IP, the SG rules remain valid.

## Design Decisions

### 3-tier subnet architecture

| | |
|---|---|
| **Decision** | Separate public, private, and database subnets |
| **Why** | An attacker compromising the ALB has no direct network path to EC2 or RDS |
| **Trade-off** | 3 route tables, 6+ subnets, 6 route table associations — more resources to manage |

### NAT Gateway: single vs multi-AZ

| | |
|---|---|
| **Decision** | 1 NAT Gateway in dev/staging; 1 per AZ in prod |
| **Why** | Each NAT costs ~$33/month. Non-prod can tolerate occasional internet loss. Prod cannot. |
| **Trade-off** | If the single NAT fails in dev/staging, private instances lose internet until AWS recovers the AZ |

### RDS: single-AZ vs Multi-AZ

| | |
|---|---|
| **Decision** | Single-AZ in dev/staging; Multi-AZ with automatic failover in prod |
| **Why** | Multi-AZ doubles instance cost. Dev/staging don't need 99.95% uptime. |
| **Trade-off** | AZ outage in dev/staging = database down until AWS recovers |

### Auto-generated passwords

| | |
|---|---|
| **Decision** | `random_password` (32 chars) → `var.db_password` → RDS + Secrets Manager |
| **Why** | No secrets in git. No default passwords. Unique per deployment. |
| **Trade-off** | Secrets Manager costs ~$0.40/month/secret. Operators need IAM access to retrieve it. |

### Remote state with locking

| | |
|---|---|
| **Decision** | S3 backend + DynamoDB lock table, one state key per environment |
| **Why** | Prevents two people (or CI runs) from applying conflicting changes simultaneously |
| **Trade-off** | Bootstrap script must run before first `terraform init` |

## Module Contracts

| Module | Creates | Key Outputs |
|--------|---------|-------------|
| **networking** | VPC, 3x2 subnets, IGW, NAT GW(s), EIPs, route tables, DB subnet group | `vpc_id`, `public_subnet_ids`, `private_subnet_ids`, `database_subnet_ids`, `db_subnet_group_name` |
| **security** | 3 security groups with cross-references | `alb_sg_id`, `app_sg_id`, `db_sg_id` |
| **storage** | S3 bucket + random suffix, versioning, SSE-S3, public block, lifecycle | `bucket_id`, `bucket_arn`, `bucket_domain_name` |
| **database** | RDS PostgreSQL, Secrets Manager secret | `db_endpoint` (sensitive), `db_port`, `db_secret_arn` |
| **compute** | ALB, Target Group, Listener, Launch Template (AL2023), ASG, IAM, CPU scaling policy | `alb_dns_name`, `alb_arn`, `asg_name`, `target_group_arn` |

## Data Flow Between Modules

```
networking ──vpc_id──────────────→ security, compute
networking ──public_subnet_ids───→ compute (ALB)
networking ──private_subnet_ids──→ compute (ASG)
networking ──database_subnet_ids─→ (routing only)
networking ──db_subnet_group────→ database
security   ──alb_sg_id──────────→ compute
security   ──app_sg_id──────────→ compute
security   ──db_sg_id───────────→ database
```

## Environment Isolation

Each environment has its own VPC CIDR block — no overlap, no cross-environment routing possible:

| Environment | VPC CIDR | Public subnets | Private subnets | Database subnets |
|-------------|----------|----------------|-----------------|------------------|
| dev | 10.0.0.0/16 | 10.0.1.0/24, 10.0.2.0/24 | 10.0.10.0/24, 10.0.11.0/24 | 10.0.20.0/24, 10.0.21.0/24 |
| staging | 10.1.0.0/16 | 10.1.1.0/24, 10.1.2.0/24 | 10.1.10.0/24, 10.1.11.0/24 | 10.1.20.0/24, 10.1.21.0/24 |
| prod | 10.2.0.0/16 | 10.2.1.0/24, 10.2.2.0/24 | 10.2.10.0/24, 10.2.11.0/24 | 10.2.20.0/24, 10.2.21.0/24 |

## Verification Checklist

- [ ] `make validate` passes on all 5 modules and 3 environments
- [ ] `make fmt` produces no changes
- [ ] `terraform plan` on `environments/dev` shows expected resources (no surprises)
- [ ] `alb_dns_name` output resolves and shows nginx welcome page
- [ ] `db_endpoint` is not visible in plain text (marked sensitive)
- [ ] `db_secret_arn` points to a valid Secrets Manager secret
- [ ] S3 bucket has `BlockPublicAccess` fully enabled
- [ ] CI pipeline runs `fmt`, `validate`, `tflint`, and `checkov` on every push
