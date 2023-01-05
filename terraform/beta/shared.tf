terraform {
  backend "s3" {
    bucket         = "mdesta-beta-terraform"
    key            = "state.tfstate"
    region         = "eu-west-1"
    acl            = "private"
    kms_key_id     = "aws/s3"
    dynamodb_table = "beta-terraform"
  }
}

provider "aws" {
  region              = "eu-west-1"
  allowed_account_ids = ["474034724728"]
  default_tags {
    tags = {
      Origin      = "Terraform"
      Environment = local.environment_name
    }
  }
}

locals {
  environment_name = "beta"
  tags = {
    Environment = local.environment_name
    Origin      = "Terraform"
  }
}

module "terraform_s3_backend" {
  source           = "../modules/s3_backend"
  environment_name = local.environment_name
}