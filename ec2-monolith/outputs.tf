output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app.id
}

output "elastic_ip" {
  description = "Elastic IP assigned to the EC2 instance"
  value       = aws_eip.app.public_ip
}

output "instance_private_ip" {
  description = "EC2 private IP"
  value       = aws_instance.app.private_ip
}

output "ecr_repository_url" {
  description = "ECR repository URL for docker push"
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_name" {
  description = "ECR repository name (for GitHub Actions)"
  value       = aws_ecr_repository.app.name
}

output "security_group_id" {
  description = "Application security group ID"
  value       = aws_security_group.app.id
}

output "ssm_connect_command" {
  description = "AWS CLI command to connect via SSM"
  value       = "aws ssm start-session --target ${aws_instance.app.id} --region ${var.aws_region}"
}

output "route53_zone_id" {
  description = "Route53 hosted zone ID for the subdomain"
  value       = aws_route53_zone.app.zone_id
}

output "route53_name_servers" {
  description = "NS records delegated in Lightsail"
  value       = aws_route53_zone.app.name_servers
}

output "domain_name" {
  description = "Fully qualified domain name"
  value       = var.domain_name
}

output "data_volume_id" {
  description = "EBS volume ID for persistent data"
  value       = aws_ebs_volume.data.id
}

output "app_name" {
  description = "Application name (for downstream workflows)"
  value       = var.app_name
}

output "name_prefix" {
  description = "Resource naming prefix (app_name-environment)"
  value       = local.name_prefix
}
