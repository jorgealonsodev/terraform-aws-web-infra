# Security Module

Security groups for a 3-tier web architecture with cross-referenced isolation.

This module creates three security groups that enforce tiered network isolation:
- **ALB SG**: Public-facing, allows HTTP/HTTPS from anywhere
- **App SG**: Private tier, allows ingress only from the ALB security group
- **DB SG**: Isolated tier, allows ingress only from the App security group, no internet egress

All cross-tier references use security group IDs (not CIDR blocks) for effective layer isolation.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
