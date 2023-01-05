terraform {
  backend "s3" {
    bucket         = "mdesta-dev-terraform"
    key            = "state.tfstate"
    region         = "eu-west-1"
    acl            = "private"
    kms_key_id     = "aws/s3"
    dynamodb_table = "dev-terraform"
  }
}

provider "aws" {
  region              = "eu-west-1"
  allowed_account_ids = ["474034724728"]
  default_tags {
    tags = {
      Origin      = "Terraform"
    }
  }
}

locals {
  environment_name = "dev"
  tags = {
    Environment = local.environment_name
    Origin      = "Terraform"
  }
}

module "terraform_s3_backend" {
  source           = "../modules/s3_backend"
  environment_name = local.environment_name
}