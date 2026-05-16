# Storage Module

Hardened S3 bucket with versioning, encryption, public access blocking, and lifecycle rules.

This module creates a globally unique S3 bucket (via random 4-character suffix) with:
- **Versioning**: Enabled for data protection
- **Encryption**: SSE-S3 (AES256) at rest
- **Public Access Block**: All four options set to `true`
- **Lifecycle**: Transition to STANDARD_IA after 30 days, expire noncurrent versions after 90 days

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
