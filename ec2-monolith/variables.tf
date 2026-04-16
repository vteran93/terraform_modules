# --------------------------------------------------------------------------
# Identity
# --------------------------------------------------------------------------

variable "app_name" {
  description = "Application name — used for resource naming (e.g. 'growth-guard', 'paygate')"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,28}[a-z0-9]$", var.app_name))
    error_message = "app_name must be lowercase alphanumeric with hyphens, 3-30 chars."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be 'staging' or 'production'."
  }
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

# --------------------------------------------------------------------------
# EC2
# --------------------------------------------------------------------------

variable "instance_type" {
  description = "EC2 instance type — must be a Graviton (ARM64) instance"
  type        = string
  default     = "t4g.medium"

  validation {
    condition = can(regex("^(t4g|m7g|m6g|c7g|c6g|r7g|r6g|x2gd|im4gn|is4gen)\\.", var.instance_type))
    error_message = join("", [
      "instance_type must be an ARM64/Graviton family ",
      "(t4g, m7g, m6g, c7g, c6g, r7g, r6g, x2gd, im4gn, is4gen).",
    ])
  }
}

variable "key_pair_name" {
  description = "Name of an existing EC2 key pair for SSH emergency access (optional)"
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
  default     = 30
}

# --------------------------------------------------------------------------
# EBS — persistent data volume
# --------------------------------------------------------------------------

variable "data_volume_size" {
  description = "Persistent EBS data volume size in GiB (for Docker named volumes)"
  type        = number
  default     = 30
}

variable "data_volume_device_name" {
  description = "Device name for the persistent data EBS volume"
  type        = string
  default     = "/dev/xvdf"
}

# --------------------------------------------------------------------------
# Networking
# --------------------------------------------------------------------------

variable "vpc_id" {
  description = "VPC ID where the EC2 instance will be launched"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the EC2 instance (public subnet — EIP handles public access)"
  type        = string
}

variable "allowed_cidrs" {
  description = "CIDR blocks allowed to access application ports"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ingress_ports" {
  description = "Application ports to open in the security group (80 and 443 are always included)"
  type        = list(number)
  default     = [8000, 8501]
}

# --------------------------------------------------------------------------
# DNS
# --------------------------------------------------------------------------

variable "domain_name" {
  description = "Subdomain managed via Route53 (e.g. 'myapp.growthguard.io')"
  type        = string
}

variable "parent_domain_name" {
  description = "Parent domain in Lightsail where NS delegation is created"
  type        = string
  default     = "growthguard.io"
}

variable "create_dns_record" {
  description = "Create a simple A record pointing to the EIP. Set to false when using failover routing externally."
  type        = bool
  default     = true
}

# --------------------------------------------------------------------------
# Docker Compose
# --------------------------------------------------------------------------

variable "docker_compose_content" {
  description = "Full docker-compose.yml content to deploy on the EC2 instance"
  type        = string
}

variable "ecr_image_tag" {
  description = "Docker image tag to deploy (defaults to 'latest')"
  type        = string
  default     = "latest"
}

# --------------------------------------------------------------------------
# Tags
# --------------------------------------------------------------------------

variable "extra_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
