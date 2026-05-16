# Terraform AWS Web Infrastructure

Infrastructure as Code that provisions a complete 3-tier AWS web architecture
across 3 environments — from zero to running in ~10 minutes.

## Quick Start

```bash
# 1. Configure AWS
aws configure
# or: export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... AWS_DEFAULT_REGION=eu-west-1

# 2. Create remote state backend (once)
./scripts/bootstrap-backend.sh

# 3. Edit environments/dev/backend.tf → replace bucket and dynamodb_table placeholders

# 4. Deploy dev
cd environments/dev
terraform init && terraform plan && terraform apply

# 5. Verify
terraform output alb_dns_name
# Open the DNS in a browser → "Hello from ip-10-0-10-xxx"
```

> **Repeat for staging and prod:** `cd environments/staging && terraform init && terraform plan && terraform apply`

## What This Builds

```
Internet → IGW → VPC
  ├── Public subnets  → ALB + NAT Gateway
  ├── Private subnets → EC2 Auto Scaling Group
  ├── Database subnets → RDS (isolated, no internet)
  └── S3 bucket → object storage (assets / logs)
```

| Layer | Resource | Purpose |
|-------|----------|---------|
| Edge | Application Load Balancer | Entry point, distributes traffic |
| Compute | EC2 + Auto Scaling Group | Runs the application, scales by CPU |
| Data | RDS PostgreSQL | Relational database, encrypted at rest |
| Storage | S3 | Static assets, versioned and encrypted |
| Network | VPC + NAT Gateway + subnets | 3-tier isolation, private internet egress |

## Repository Map

```
├── modules/          ← Reusable infrastructure (5 modules)
│   ├── networking/   ← VPC, subnets, gateways, routing
│   ├── security/     ← Security groups (ALB → App → DB chain)
│   ├── compute/      ← ALB, ASG, Launch Template, IAM
│   ├── database/     ← RDS + Secrets Manager
│   └── storage/      ← Hardened S3 bucket
├── environments/     ← Environment-specific configuration only
│   ├── dev/          ← 10.0.0.0/16, t3.micro, single NAT
│   ├── staging/      ← 10.1.0.0/16, t3.micro, single NAT
│   └── prod/         ← 10.2.0.0/16, t3.small, multi-AZ, dual NAT
├── scripts/
│   ├── bootstrap-backend.sh ← Creates S3 + DynamoDB state backend
│   └── gen-docs.sh          ← Regenerates terraform-docs
├── .github/workflows/ci.yml ← CI: fmt, validate, lint, security scan
├── docs/              ← Architecture decisions and cost estimates
└── Makefile           ← fmt, validate, docs, init-dev, plan-dev, ...
```

## Makefile Quick Reference

| Command | What it does |
|---------|-------------|
| `make fmt` | Format all `.tf` files |
| `make validate` | Validate all modules and environments |
| `make docs` | Regenerate terraform-docs in module READMEs |
| `make init-dev` | `terraform init` for dev |
| `make plan-dev` | `terraform plan` for dev |
| `make clean` | Remove `.terraform/` directories and lock files |

> Uses Docker images internally — no local Terraform installation required.

## Environments at a Glance

| Parameter | dev | staging | prod |
|-----------|-----|---------|------|
| VPC CIDR | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |
| EC2 | t3.micro (1-2) | t3.micro (1-3) | t3.small (2-6) |
| RDS | db.t3.micro, single-AZ | db.t3.micro, single-AZ | db.t3.small, Multi-AZ |
| NAT Gateway | 1 | 1 | 2 (one per AZ) |
| Deletion protection | Off | Off | On |

## Cost Advisory

> **NAT Gateway and ALB are NOT in the AWS free tier** — they cost ~$48-65/month combined even with zero traffic. Destroy non-production environments when not in use.

| Environment | Running 24/7 | Destroyed |
|-------------|-------------|-----------|
| dev | ~$60-80/mo | ~$0 |
| staging | ~$60-80/mo | ~$0 |
| prod | ~$150-200/mo | n/a |

See [docs/COSTS.md](docs/COSTS.md) for the full breakdown.

## Design Decisions

| Decision | Why | Trade-off |
|----------|-----|-----------|
| 3 subnet tiers | Attack surface reduction through layer isolation | More route tables and subnets |
| Single NAT in dev/staging | Saves ~$33/mo per environment | Single point of failure outside prod |
| Multi-AZ RDS only in prod | Automatic failover where uptime matters | Doubled RDS cost in prod |
| SG references by ID | Survives IP changes from auto-scaling | Harder to audit than CIDR rules |
| Auto-generated passwords | No secrets in git, unique per deployment | Requires Secrets Manager access (~$0.40/mo) |
| Remote state in S3 + DynamoDB | Team-safe concurrent terraform runs | Dependency on bootstrap before first `init` |

## Destroying

```bash
cd environments/dev && terraform destroy
```

> **Irreversible.** All resources in the environment are permanently deleted. Verify backups first.

## Documentation

| Doc | Content |
|-----|---------|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Detailed design decisions, traffic flow, trade-offs |
| [COSTS.md](docs/COSTS.md) | Per-resource breakdown, free tier analysis, cost control tips |
| `modules/*/README.md` | Auto-generated: inputs, outputs, providers, resources per module |

## Scope

| Included | Deferred |
|----------|----------|
| 3-tier VPC with isolated subnets | HTTPS + ACM certificate + Route 53 domain |
| Auto Scaling Group with CPU scaling | CD pipeline (auto-plan on PR, manual apply) |
| RDS with encrypted storage + Secrets Manager | ECS Fargate / EKS migration |
| CI pipeline (fmt, validate, lint, security) | OIDC auth in CI |
| Hardened S3 bucket | CloudWatch dashboards and alarms |
| Remote state with DynamoDB locking | Terratest integration |

## License

MIT
