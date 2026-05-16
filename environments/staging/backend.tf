terraform {
  backend "s3" {
    bucket         = "webinfra-terraform-state"
    key            = "env/staging/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "webinfra-terraform-locks"
    encrypt        = true
  }
}
