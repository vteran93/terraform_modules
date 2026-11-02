# --------------------------------------------------------------------------
# Switch
# --------------------------------------------------------------------------

variable "enabled" {
  description = "Create the web ACL. false destroys it (and stops its billing) while keeping the module wired in the caller."
  type        = bool
  default     = true
}

# --------------------------------------------------------------------------
# Identity
# --------------------------------------------------------------------------

variable "name" {
  description = "Web ACL name (e.g. 'houseland-co-stage-cloudfront')"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{1,128}$", var.name))
    error_message = "name must be 1-128 chars of letters, digits, hyphen or underscore."
  }
}

variable "description" {
  description = "Web ACL description"
  type        = string
  default     = "Managed by terraform_modules/wafv2-cloudfront"
}

# --------------------------------------------------------------------------
# Rules
# --------------------------------------------------------------------------

variable "default_action" {
  description = "Action for requests no rule matches: 'allow' or 'block'"
  type        = string
  default     = "allow"

  validation {
    condition     = contains(["allow", "block"], var.default_action)
    error_message = "default_action must be 'allow' or 'block'."
  }
}

# Free AWS managed rule groups. Each one costs USD 1/month per web ACL plus
# the per-request fee; the ACL itself costs USD 5/month. The AntiDDoS managed
# rule group is deliberately NOT part of the default: it bills ~USD 20/month on
# its own and its ManagedRuleGroupConfigs block needs aws provider >= 6.x.
variable "managed_rule_groups" {
  description = "AWS managed rule groups to attach, evaluated by ascending priority. override_action 'count' only observes."
  type = list(object({
    name            = string
    priority        = number
    vendor_name     = optional(string, "AWS")
    override_action = optional(string, "none")
  }))
  default = [
    { name = "AWSManagedRulesAmazonIpReputationList", priority = 10 },
    { name = "AWSManagedRulesCommonRuleSet", priority = 20 },
    { name = "AWSManagedRulesKnownBadInputsRuleSet", priority = 30 },
  ]

  validation {
    condition     = alltrue([for g in var.managed_rule_groups : contains(["none", "count"], g.override_action)])
    error_message = "override_action must be 'none' or 'count'."
  }

  validation {
    condition     = length(distinct([for g in var.managed_rule_groups : g.priority])) == length(var.managed_rule_groups)
    error_message = "managed_rule_groups priorities must be unique."
  }
}

variable "rate_limit_per_5_min" {
  description = "Requests per source IP per 5 minutes before blocking. null disables the rate-based rule."
  type        = number
  default     = null

  validation {
    condition     = var.rate_limit_per_5_min == null || try(var.rate_limit_per_5_min >= 100, false)
    error_message = "rate_limit_per_5_min must be null or >= 100 (AWS minimum)."
  }
}

variable "rate_limit_priority" {
  description = "Priority of the rate-based rule; must not collide with managed_rule_groups priorities"
  type        = number
  default     = 1
}

# --------------------------------------------------------------------------
# Observability
# --------------------------------------------------------------------------

variable "cloudwatch_metrics_enabled" {
  description = "Publish CloudWatch metrics for the ACL and each rule"
  type        = bool
  default     = true
}

variable "sampled_requests_enabled" {
  description = "Store a sample of matched requests for the console"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to the web ACL"
  type        = map(string)
  default     = {}
}
