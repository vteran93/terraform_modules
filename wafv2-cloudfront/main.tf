# CLOUDFRONT-scoped WAFv2 web ACL.
#
# The CLOUDFRONT scope only exists in us-east-1: pass a us-east-1 provider to
# this module (`providers = { aws = aws.us_east_1 }`) when the caller's default
# region is anything else.
#
# With `enabled = false` nothing is created, `web_acl_arn` is null and the
# caller can keep `web_acl_id = module.waf.web_acl_arn` on its distributions:
# CloudFront treats null as "no WAF".

locals {
  metric_prefix = replace(var.name, "/[^A-Za-z0-9]/", "")
}

resource "aws_wafv2_web_acl" "this" {
  count = var.enabled ? 1 : 0

  name        = var.name
  description = var.description
  scope       = "CLOUDFRONT"

  default_action {
    dynamic "allow" {
      for_each = var.default_action == "allow" ? [1] : []
      content {}
    }
    dynamic "block" {
      for_each = var.default_action == "block" ? [1] : []
      content {}
    }
  }

  dynamic "rule" {
    for_each = var.rate_limit_per_5_min == null ? [] : [var.rate_limit_per_5_min]
    content {
      name     = "RateLimitPerIp"
      priority = var.rate_limit_priority

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit              = rule.value
          aggregate_key_type = "IP"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = var.cloudwatch_metrics_enabled
        metric_name                = "${local.metric_prefix}RateLimitPerIp"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  dynamic "rule" {
    for_each = { for g in var.managed_rule_groups : g.name => g }
    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        dynamic "none" {
          for_each = rule.value.override_action == "none" ? [1] : []
          content {}
        }
        dynamic "count" {
          for_each = rule.value.override_action == "count" ? [1] : []
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = rule.value.vendor_name
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = var.cloudwatch_metrics_enabled
        metric_name                = "${local.metric_prefix}${rule.value.name}"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = var.cloudwatch_metrics_enabled
    metric_name                = local.metric_prefix
    sampled_requests_enabled   = var.sampled_requests_enabled
  }

  tags = merge(var.tags, { Name = var.name })
}
