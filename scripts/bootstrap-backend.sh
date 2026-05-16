#!/usr/bin/env bash
# bootstrap-backend.sh — Create S3 bucket and DynamoDB table for Terraform remote state.
#
# Usage:
#   ./scripts/bootstrap-backend.sh [--region eu-west-1] [--bucket my-state-bucket] [--table my-locks]
#
# This script is idempotent: it checks if resources exist before creating them.
# Re-running will not error or duplicate resources.

set -euo pipefail

# Defaults
REGION="${AWS_DEFAULT_REGION:-eu-west-1}"
STATE_BUCKET="webinfra-terraform-state"
LOCK_TABLE="webinfra-terraform-locks"

# Parse optional arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --region)
      REGION="$2"
      shift 2
      ;;
    --bucket)
      STATE_BUCKET="$2"
      shift 2
      ;;
    --table)
      LOCK_TABLE="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: $0 [--region REGION] [--bucket BUCKET] [--table TABLE]"
      exit 1
      ;;
  esac
done

echo "=== Terraform Backend Bootstrap ==="
echo "Region:      ${REGION}"
echo "S3 Bucket:   ${STATE_BUCKET}"
echo "DynamoDB:    ${LOCK_TABLE}"
echo ""

# Verify AWS CLI is available
if ! command -v aws &>/dev/null; then
  echo "ERROR: aws CLI is not installed or not in PATH."
  exit 1
fi

# Verify AWS credentials are configured
if ! aws sts get-caller-identity &>/dev/null 2>&1; then
  echo "ERROR: AWS credentials are not configured or invalid."
  echo "Run 'aws configure' or set AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY."
  exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account: ${ACCOUNT_ID}"
echo ""

# --- S3 Bucket ---
echo "--- S3 Bucket: ${STATE_BUCKET} ---"

if aws s3api head-bucket --bucket "${STATE_BUCKET}" --region "${REGION}" 2>/dev/null; then
  echo "Bucket already exists. Skipping creation."
else
  echo "Creating S3 bucket..."

  # For us-east-1, the LocationConstraint must be omitted
  if [[ "${REGION}" == "us-east-1" ]]; then
    aws s3api create-bucket \
      --bucket "${STATE_BUCKET}" \
      --region "${REGION}"
  else
    aws s3api create-bucket \
      --bucket "${STATE_BUCKET}" \
      --region "${REGION}" \
      --create-bucket-configuration "LocationConstraint=${REGION}"
  fi

  echo "S3 bucket created."
fi

# Enable versioning
echo "Enabling versioning..."
aws s3api put-bucket-versioning \
  --bucket "${STATE_BUCKET}" \
  --versioning-configuration Status=Enabled \
  --region "${REGION}"

# Enable server-side encryption (SSE-S3)
echo "Enabling server-side encryption..."
aws s3api put-bucket-encryption \
  --bucket "${STATE_BUCKET}" \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }' \
  --region "${REGION}"

# Block all public access
echo "Blocking public access..."
aws s3api put-public-access-block \
  --bucket "${STATE_BUCKET}" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
  --region "${REGION}"

echo "S3 bucket configured."
echo ""

# --- DynamoDB Table ---
echo "--- DynamoDB Table: ${LOCK_TABLE} ---"

if aws dynamodb describe-table --table-name "${LOCK_TABLE}" --region "${REGION}" &>/dev/null; then
  echo "DynamoDB table already exists. Skipping creation."
else
  echo "Creating DynamoDB table..."
  aws dynamodb create-table \
    --table-name "${LOCK_TABLE}" \
    --attribute-definitions AttributeName=LockId,AttributeType=S \
    --key-schema AttributeName=LockId,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}"

  # Wait for table to become active
  echo "Waiting for table to become active..."
  aws dynamodb wait table-exists \
    --table-name "${LOCK_TABLE}" \
    --region "${REGION}"

  echo "DynamoDB table created and active."
fi

echo ""
echo "=== Backend Bootstrap Complete ==="
echo ""
echo "Use these values in your backend.tf:"
echo ""
echo "  terraform {"
echo "    backend \"s3\" {"
echo "      bucket         = \"${STATE_BUCKET}\""
echo "      key            = \"env/<environment>/terraform.tfstate\""
echo "      region         = \"${REGION}\""
echo "      dynamodb_table = \"${LOCK_TABLE}\""
echo "      encrypt        = true"
echo "    }"
echo "  }"
