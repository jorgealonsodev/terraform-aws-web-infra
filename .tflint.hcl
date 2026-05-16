plugin "aws" {
  enabled    = true
  source     = "github.com/terraform-linters/tflint-ruleset-aws"
  version    = "0.47.0"
  deep_check = true
}

rule "aws_resource_missing_tags" {
  enabled = true
  tags = [
    "Project",
    "Environment",
    "ManagedBy",
    "Owner",
  ]
}
