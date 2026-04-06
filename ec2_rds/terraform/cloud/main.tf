terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.52.0"
    }
  }
  backend "s3" {
    bucket = "growthguard-terraform-states"
    key    = "site/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
 region = "us-east-1"
}
