# Terraform AWS Web Infrastructure

Infrastructure as Code (IaC) for a 3-tier web architecture on AWS using Terraform.

## Architecture

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

**Traffic flow:**

1. Inbound traffic reaches the **Application Load Balancer** in the public subnets.
2. The ALB distributes load across the **EC2** instances in the **Auto Scaling Group**, located in the private subnets.
3. Instances access **RDS** in the database subnets, which are isolated with no internet access.
4. Instances reach the internet (system updates, etc.) through the **NAT Gateway**.
5. **S3** provides object storage for static assets and logs.

## Stack and Prerequisites

- **Terraform** >= 1.7
- **AWS Provider** ~> 5.x
- **Region**: eu-west-1 (default)
- **terraform-docs** — module documentation
- **tflint** — Terraform linting
- **Docker** (optional, for running Terraform via the `hashicorp/terraform` image)

### Prerequisites

- AWS CLI configured with appropriate credentials
- AWS account with permissions to create VPC, EC2, RDS, S3, IAM, DynamoDB
- Docker (if using containers)

## Repository Structure

```
terraform-aws-web-infra/
├── README.md
├── PRD-terraform-aws-infra.md
├── .gitignore
├── .terraform-docs.yml
├── .tflint.hcl
├── Makefile
├── versions.tf
├── .github/
│   └── workflows/
│       └── ci.yml                  # CI pipeline (fmt, validate, lint, security)
├── docs/
│   ├── ARCHITECTURE.md             # Detailed architecture description
│   └── COSTS.md                    # Cost estimates per environment
├── scripts/
│   ├── bootstrap-backend.sh        # Creates S3 bucket + DynamoDB state table
│   └── gen-docs.sh                 # Runs terraform-docs on all modules
├── modules/
│   ├── networking/                 # VPC, subnets, gateways, routing
│   ├── security/                   # Security Groups (ALB, App, DB)
│   ├── compute/                    # ALB, ASG, Launch Template, IAM
│   ├── database/                   # RDS + Secrets Manager
│   └── storage/                    # S3 bucket (hardened)
└── environments/
    ├── dev/                        # Development environment
    ├── staging/                    # Staging environment
    └── prod/                       # Production environment
```

## Deployment Guide

### Step 1: Configure AWS credentials

```bash
# Option A: AWS CLI configured
aws configure

# Option B: Environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="eu-west-1"
```

### Step 2: Create the remote backend

Run the bootstrap script **once** before the first `terraform init`:

```bash
./scripts/bootstrap-backend.sh
```

This script creates:
- A versioned and encrypted S3 bucket for state storage
- A DynamoDB table for state locking (prevents concurrent writes)

> The script is idempotent: if the bucket and table already exist, it does not error.

### Step 3: Configure the backend

Edit `environments/dev/backend.tf` and replace the placeholders:
- `bucket` — name of the S3 bucket created in step 2
- `dynamodb_table` — name of the DynamoDB table created in step 2

Repeat for `staging` and `prod`.

### Step 4: Deploy the environment

```bash
# Initialize Terraform
cd environments/dev
terraform init

# Review the plan
terraform plan

# Apply the changes
terraform apply
```

### Step 5: Verify the deployment

After `apply`, the outputs show key information:

```bash
# The ALB DNS name (application entry point)
terraform output alb_dns_name

# The database secret ARN
terraform output db_secret_arn
```

Open the ALB DNS in a browser to verify nginx is responding correctly.

### Deploy staging and prod

```bash
cd environments/staging && terraform init && terraform plan && terraform apply
cd environments/prod    && terraform init && terraform plan && terraform apply
```

## Destroying Environments

> **Warning:** `terraform destroy` removes **all** resources in the environment.
> This action is **irreversible**. Make sure you have backups before destroying.

```bash
cd environments/dev
terraform destroy
```

### Cost Notice

**NAT Gateway** and **Application Load Balancer** are billed by the hour,
even with no traffic (~16-35 USD/month each). If an environment will not be used
for an extended period, run `terraform destroy` to avoid unnecessary costs.

See [docs/COSTS.md](docs/COSTS.md) for detailed estimates per environment.

## Additional Documentation

- [Architecture](docs/ARCHITECTURE.md) — Detailed description, design decisions, and trade-offs
- [Cost Estimates](docs/COSTS.md) — Monthly estimate per resource and per environment
- [Module Documentation](modules/) — Each module has its own README with inputs, outputs, and resources

## Design Decisions and Trade-offs

| Decision | Reason | Trade-off |
|----------|--------|-----------|
| 3 subnet tiers | Security isolation between layers | Higher network complexity |
| Single NAT in dev/staging | Reduces cost (~33 USD/month per NAT) | Single point of failure outside prod |
| Multi-AZ RDS only in prod | High availability where it matters | Doubled RDS cost |
| Security groups by ID | Works with dynamic ASG IPs | Rules harder to audit |
| Auto-generated password | No secrets in the repository | Requires Secrets Manager access |
| Remote state with locking | Team collaboration without conflicts | Dependency on S3 + DynamoDB |

## Scope

### Included in this phase

- 3-tier web architecture (ALB → EC2 → RDS) with reusable modules
- 3 environments (dev, staging, prod) with environment-specific configuration
- Remote state in S3 with DynamoDB locking
- Security groups with inter-tier isolation
- Hardened S3 bucket with versioning and encryption
- RDS with auto-generated password stored in Secrets Manager
- Auto Scaling Group with CPU-based scaling policy
- CI pipeline with format, syntax, linting, and security validation
- Cost and architecture documentation

### Out of scope (future phases)

- HTTPS termination on the ALB with ACM certificate and Route 53 domain
- Delivery pipeline: automatic `terraform plan` on each PR with manual `apply`
- Migrating EC2 + ASG to containers (ECS Fargate or EKS)
- OIDC authentication in CI instead of static access keys
- Observability module: CloudWatch dashboards and alarms
- Automated infrastructure tests with Terratest

## License

MIT
