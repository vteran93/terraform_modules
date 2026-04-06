terraform {
   required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.52.0"
    }
  }
  backend "s3" {
    bucket = "growthguard-terraform"
    key    = "site/growthguard/master/terraform.tfstate"
    workspace_key_prefix = "environment"
    region = "us-east-2"
  }
}

provider "aws" {
 region = "us-east-1"
}

variable "environment" {
  type = string
  default = "global"
}


resource "aws_s3_bucket" "tf_states" {
  bucket = "growthguard-terraform-states"

  tags = {
    Name        = "growthguard-terraform-states"
    Environment = var.environment
  }
}
