# Database Module

RDS PostgreSQL instance with encrypted storage, auto-generated password via `random_password`, and AWS Secrets Manager integration.

This module creates:
- **RDS Instance**: PostgreSQL with encrypted storage (`storage_encrypted = true`), not publicly accessible
- **Random Password**: 16-character secure password generated at plan time
- **Secrets Manager**: Stores the DB password securely; only the secret ARN is exposed as output (never the password value)
- **Environment-aware defaults**: `multi_az`, `deletion_protection`, and `skip_final_snapshot` are controlled via variables per environment

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
