# Cost Estimates

> **eu-west-1 (Ireland), May 2026.** Always verify with [AWS Pricing Calculator](https://calculator.aws/#/).

**TL;DR:** dev and staging cost **$0 when destroyed**, ~$60-80/month when running.
prod costs ~$150-200/month. The main cost drivers are NAT Gateway and ALB —
neither is in the free tier.

## Summary

| Environment | Running 24/7 | Destroyed after use | Main cost driver |
|-------------|-------------|----------------------|------------------|
| dev | ~$60-80/mo | ~$0 | NAT Gateway + ALB |
| staging | ~$60-80/mo | ~$0 | NAT Gateway + ALB |
| prod | ~$150-200/mo | n/a | Dual NAT + Multi-AZ RDS + more EC2 |

## Cost by Tier

### dev — Development

| Resource | Qty | Free tier? | Est. monthly cost | Notes |
|----------|-----|-----------|-------------------|-------|
| EC2 t3.micro | 1-2 | ✅ 750 hrs (first 12 months) | ~$0 | Within free tier |
| NAT Gateway | 1 | ❌ | ~$33 | $0.045/hr × 730 + data |
| ALB | 1 | ❌ | ~$16-26 | $0.0225/hr × 730 + LCU |
| RDS db.t3.micro | 1 | ✅ 750 hrs (first 12 months) | ~$0 | 20 GB gp3 |
| EBS gp3 | 20 GB | — | ~$1.60 | |
| S3 | 1 | ✅ 5 GB | ~$0 | |
| DynamoDB | 1 | ✅ 25 WCU/RCU | ~$0 | Lock table |
| Secrets Manager | 1 | ❌ | ~$0.40 | |
| **Total** | | | **~$50-65/mo** | |

### staging — Pre-production

| Resource | Qty | Difference from dev | Additional cost |
|----------|-----|---------------------|-----------------|
| EC2 t3.micro | 1-3 | +1 instance possible | ~$0 (free tier) |
| EBS gp3 | +20 GB | Extra storage | ~$1.60 |
| Everything else | — | Same as dev | — |
| **Total** | | | **~$52-67/mo** | |

### prod — Production

| Resource | Qty | Est. monthly cost | Notes |
|----------|-----|-------------------|-------|
| EC2 t3.small | 2-6 | ~$15-45 | Outside free tier |
| NAT Gateway | 2 | ~$65 | One per AZ |
| ALB | 1 | ~$16-26 | |
| RDS db.t3.small (Multi-AZ) | 1 | ~$35 | Automatic failover |
| EBS gp3 | 2 × 20 GB | ~$3.20 | |
| S3 | 1 | ~$0 | |
| Secrets Manager | 1 | ~$0.40 | |
| **Total** | | **~$135-195/mo** | |

## ⚠️ NAT Gateway and ALB — Not Free Tier

These two resources account for **70-80% of your infrastructure cost:**

| Resource | Hourly rate | Monthly (730 hrs) | Notes |
|----------|------------|-------------------|-------|
| NAT Gateway | $0.045/hr | **~$32.85** | + $0.045/GB data processed |
| ALB | $0.0225/hr | **~$16.43** | + LCU charges (varies with traffic) |

> Both are billed **by the hour, regardless of traffic**. Even an idle dev environment
> with no requests costs ~$50/month just from NAT + ALB being provisioned.

## Cost Control Playbook

| Strategy | Impact | How |
|----------|--------|-----|
| **Destroy when idle** | Saves 100% of running cost | `terraform destroy` in dev/staging at end of day |
| **Single NAT outside prod** | Saves ~$33/mo per environment | Already configured (`single_nat_gateway = true`) |
| **Right-size RDS** | db.t3.micro is ~$15/mo vs db.t3.small at ~$35/mo | Already configured for dev/staging |
| **Budget alerts** | Catch surprises early | AWS Budgets → alert at 80% of expected monthly cost |
| **Reserved Instances** | Save 30-40% on EC2/RDS | Consider for prod after 1-2 months of stable usage |

## Useful Links

- [AWS Pricing Calculator](https://calculator.aws/#/)
- [AWS Free Tier](https://aws.amazon.com/free/)
- [AWS Cost Explorer](https://aws.amazon.com/aws-cost-management/aws-cost-explorer/)

## Disclaimer

Figures are **indicative estimates** based on public eu-west-1 pricing as of May 2026.
Actual costs vary with traffic volume (ALB LCU, NAT data processing), AWS price changes,
and account-specific discounts (EDP, Reserved Instances, Savings Plans).
**Verify current pricing before making infrastructure decisions.**
