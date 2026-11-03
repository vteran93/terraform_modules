output "enabled" {
  description = "Whether the web ACL exists"
  value       = var.enabled
}

output "web_acl_arn" {
  description = "ARN of the web ACL, or null when disabled. CloudFront's `web_acl_id` takes this ARN."
  value       = try(aws_wafv2_web_acl.this[0].arn, null)
}

output "web_acl_id" {
  description = "ID of the web ACL, or null when disabled"
  value       = try(aws_wafv2_web_acl.this[0].id, null)
}

output "web_acl_name" {
  description = "Name of the web ACL, or null when disabled"
  value       = try(aws_wafv2_web_acl.this[0].name, null)
}
