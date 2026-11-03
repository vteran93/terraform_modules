# wafv2-cloudfront

CLOUDFRONT-scoped AWS WAFv2 web ACL with an on/off switch. Disabled by the
caller it costs nothing; enabled it bills USD 5/month for the ACL plus
USD 1/month per managed rule group plus USD 0.60 per million requests.

The default rule set is the three free AWS managed groups (IP reputation,
Common, Known bad inputs). The **AntiDDoS** managed group is intentionally
left out: it adds ~USD 20/month and its tuning block needs aws provider 6.x.

## Usage

```hcl
module "waf" {
  source = "git::https://github.com/vteran93/terraform_modules.git//wafv2-cloudfront?ref=main"

  providers = { aws = aws.us_east_1 } # CLOUDFRONT scope lives in us-east-1

  enabled = var.waf_enabled # false => no ACL, no cost
  name    = "myapp-stage-cloudfront"

  rate_limit_per_5_min = 2000 # optional, null disables
  tags                 = { Project = "myapp" }
}

resource "aws_cloudfront_distribution" "media" {
  # null when the module is disabled => distribution without WAF
  web_acl_id = module.waf.web_acl_arn
  # ...
}
```

Flipping `enabled` from `true` to `false` first detaches the ACL from every
distribution that references `web_acl_arn` (CloudFront redeploys, a few
minutes) and then deletes the ACL.

## Inputs

| Name | Default | Description |
| --- | --- | --- |
| `enabled` | `true` | Create the ACL |
| `name` | – | Web ACL name |
| `description` | module string | Web ACL description |
| `default_action` | `allow` | `allow` or `block` for unmatched requests |
| `managed_rule_groups` | 3 free AWS groups | `{ name, priority, vendor_name?, override_action? }` |
| `rate_limit_per_5_min` | `null` | Per-IP rate limit; `null` disables |
| `rate_limit_priority` | `1` | Priority of the rate rule |
| `cloudwatch_metrics_enabled` | `true` | CloudWatch metrics |
| `sampled_requests_enabled` | `true` | Sampled requests |
| `tags` | `{}` | Tags |

## Outputs

`enabled`, `web_acl_arn` (null when disabled), `web_acl_id`, `web_acl_name`.

## Permissions

The identity that applies needs `wafv2:CreateWebACL`, `GetWebACL`,
`UpdateWebACL`, `DeleteWebACL`, `ListWebACLs`, `TagResource`,
`ListTagsForResource` and `cloudfront:UpdateDistribution`. The shared
`github-deployment-role` (security-bootstrap) does not have the `wafv2:*`
actions today, so enable the module from a principal that does, or add them
to `policies.tf` there first.
