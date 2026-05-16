# Cost Estimates

> Indicative figures for the **eu-west-1 (Ireland)** region, May 2026.
> Always verify with the [AWS Pricing Calculator](https://calculator.aws/#/).
> Prices may vary.

## Summary per Environment (USD/month, approx.)

| Environment | Running continuously | Destroyed after use |
|-------------|---------------------|----------------------|
| dev         | ~60-80              | ~0                   |
| staging     | ~60-80              | ~0                   |
| prod        | ~150-200            | n/a                  |

> **Note:** The ranges reflect variation in traffic (ALB LCUs) and NAT Gateway data usage.

## Detailed Breakdown (dev environment)

| Resource | Quantity | Free tier | Cost outside free tier |
|----------|----------|-----------|-------------------------|
| EC2 t3.micro | 1 | 750 hrs/month (t2/t3.micro, first 12 months) | ~0 USD/month (within free tier if applicable) |
| ALB | 1 | **No** | ~16 USD/month (hours) + variable LCU (~0-10 USD) |
| NAT Gateway | 1 | **No** | ~32 USD/month (hours) + data processed (~0-5 USD) |
| RDS db.t3.micro | 1 | 750 hrs/month (first 12 months) | ~0 USD/month (within free tier if applicable) |
| EBS gp3 (20 GB) | 1 | — | ~1.60 USD/month |
| S3 Standard | 1 | 5 GB | negligible (< 0.03 USD/month) |
| DynamoDB (lock table) | 1 | 25 WCU + 25 RCU | ~0 USD/month (within free tier) |
| Elastic IP | 1 | 1 attached | ~0 USD/month |
| Secrets Manager | 1 | — | ~0.40 USD/month |
| **Estimated total** | | | **~50-65 USD/month** |

### Important: NAT Gateway and ALB

**NAT Gateway** and **Application Load Balancer** are **NOT included in the AWS free tier**.
They are the largest cost component of this infrastructure:

- **NAT Gateway**: ~0.045 USD/hour × 730 hrs ≈ **32.85 USD/month** + data processing cost.
- **ALB**: ~0.0225 USD/hour × 730 hrs ≈ **16.43 USD/month** + LCU (Load Balancer Capacity Units) cost.

These resources are billed by the hour, regardless of whether there is traffic or not.

## Staging Environment

Similar to dev but with an ASG of 2-3 instances (instead of 1-2):

| Resource | Difference vs dev | Additional cost |
|----------|-------------------|-----------------|
| EC2 t3.micro | +1 additional instance | ~0 USD (free tier) |
| EBS gp3 | +20 GB | ~1.60 USD/month |
| ALB + NAT | Same | Same |
| **Estimated total** | | **~52-67 USD/month** |

## Production Environment

Production configuration with high availability:

| Resource | Quantity | Estimated cost |
|----------|----------|----------------|
| EC2 t3.small | 2-6 | ~15-45 USD/month (outside free tier) |
| ALB | 1 | ~16 USD/month + LCU |
| NAT Gateway × 2 | 2 | ~65 USD/month + data |
| RDS db.t3.small (Multi-AZ) | 1 | ~35 USD/month |
| EBS gp3 (20 GB × 2) | 2 | ~3.20 USD/month |
| S3 Standard | 1 | negligible |
| Secrets Manager | 1 | ~0.40 USD/month |
| **Estimated total** | | **~135-195 USD/month** |

## Recommendations for Cost Control

1. **Destroy non-production environments when not in use.** Running `terraform destroy` in `dev` and `staging` at the end of each development day eliminates cost entirely.
2. **Use `single_nat_gateway = true` outside production.** A single NAT Gateway is enough for dev/staging and cuts the cost in half.
3. **Schedule automatic destruction.** Consider a script or pipeline that destroys development environments after N hours of inactivity.
4. **Monitor with AWS Cost Explorer.** Set up budget alerts to detect deviations early.

## Useful Links

- [AWS Pricing Calculator](https://calculator.aws/#/)
- [AWS Free Tier](https://aws.amazon.com/free/)
- [AWS Cost Explorer](https://aws.amazon.com/aws-cost-management/aws-cost-explorer/)

## Disclaimer

The figures in this document are **indicative estimates** based on public AWS pricing for the eu-west-1 region as of May 2026. Actual prices may vary depending on:

- Real traffic (ALB LCUs, NAT Gateway data)
- AWS price changes
- Taxes and volume discounts (Enterprise Discount Program, Reserved Instances, etc.)

**Always verify current costs before making infrastructure decisions.**
