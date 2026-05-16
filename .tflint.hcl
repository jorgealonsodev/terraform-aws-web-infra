config {
  plugin "aws" {
    enabled = true
    version = "latest"
    source  = "github.com/terraform-linters/tflint-ruleset-aws"
  }
}

plugin "aws" {
  region = "eu-west-1"

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
