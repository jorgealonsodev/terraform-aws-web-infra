plugin "aws" {
  enabled = true
  source  = "github.com/terraform-linters/tflint-ruleset-aws"

  deep_check = true

  # Enforce tags on all resources
  rule "aws_resource_missing_tags" {
    enabled = true
    tags = [
      "Project",
      "Environment",
      "ManagedBy",
      "Owner",
    ]
  }
}
