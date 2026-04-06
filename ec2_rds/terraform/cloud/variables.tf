data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "django_secret_key"{
    name="/${var.project}/${var.environment}/django_secret_key"
}

data "aws_ssm_parameter" "ssh_private_key"{
    name="/${var.project}/${var.environment}/github/ssh_private_key"
}

data "aws_ssm_parameter" "db_name"{
    name = "/${var.project}/${var.environment}/rds/db_name"
}

data "aws_ssm_parameter" "db_username"{
    name = "/${var.project}/${var.environment}/rds/db_username"
}

data "aws_ssm_parameter" "db_password"{
    name = "/${var.project}/${var.environment}/rds/db_password"
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
  default = "us-east-1"
}

variable "project" {
  type = string
  default = "growthguard.io"
}

variable "ec2_instance_type" {
  type = string
  default = "t3a.small"
}

variable "rds_instance_type" {
  type = string
  default = "db.t3.small"
}
