locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# ──────────────────────────────────────────────
# Random suffix for globally unique bucket name
# ──────────────────────────────────────────────
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# ──────────────────────────────────────────────
# S3 Bucket
# ──────────────────────────────────────────────
resource "aws_s3_bucket" "main" {
  bucket        = "${local.name_prefix}-storage-${random_string.suffix.result}"
  force_destroy = var.force_destroy

  # checkov:skip=CKV_AWS_18:Access logging requires a dedicated log bucket outside this module scope
  # checkov:skip=CKV_AWS_145:AES256 SSE is already configured; KMS CMK is over-engineering for this project scope
  # checkov:skip=CKV_AWS_144:Cross-region replication not required for this project scope

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-storage"
  })
}

# ──────────────────────────────────────────────
# Bucket Versioning
# ──────────────────────────────────────────────
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ──────────────────────────────────────────────
# Server-Side Encryption (SSE-S3 / AES256)
# ──────────────────────────────────────────────
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ──────────────────────────────────────────────
# Public Access Block (all options = true)
# ──────────────────────────────────────────────
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ──────────────────────────────────────────────
# Lifecycle Configuration
# ──────────────────────────────────────────────
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  # Transition current versions to STANDARD_IA after 30 days
  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    # Expire noncurrent versions after 90 days
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}
