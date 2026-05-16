# Compute Module

Application Load Balancer (ALB), Launch Template, Auto Scaling Group (ASG), IAM role with SSM access, and CPU-based target tracking scaling policy.

This module creates:
- **ALB**: Internet-facing load balancer in public subnets
- **Target Group**: HTTP health check on `/`, port configurable via `app_port`
- **HTTP Listener**: Forwards traffic from port 80 to the target group
- **Launch Template**: Uses latest Amazon Linux 2023 AMI (via `data.aws_ami`) with nginx user data
- **Auto Scaling Group**: Deployed in private subnets, attached to the target group, ELB health checks
- **IAM Role + Instance Profile**: `AmazonSSMManagedInstanceCore` for SSM access
- **CPU Scaling Policy**: Target tracking at 60% average CPU utilization

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
