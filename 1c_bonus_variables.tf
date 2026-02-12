
variable "domain_name" {
  description = "Base domain students registered (e.g., chewbacca-growl.com)."
  type        = string
  default     = "lewsdomain.com"
}

variable "app_subdomain" {
  description = "App hostname prefix (e.g., app.chewbacca-growl.com)."
  type        = string
  default     = "app"
}

variable "certificate_validation_method" {
  description = "ACM validation method. Students can do DNS (Route53) or EMAIL."
  type        = string
  default     = "DNS"
}

variable "enable_waf" {
  description = "Toggle WAF creation."
  type        = bool
  default     = true
}

variable "alb_5xx_threshold" {
  description = "Alarm threshold for ALB 5xx count."
  type        = number
  default     = 10
}

variable "alb_5xx_period_seconds" {
  description = "CloudWatch alarm period."
  type        = number
  default     = 300
}

variable "alb_5xx_evaluation_periods" {
  description = "Evaluation periods for alarm."
  type        = number
  default     = 1
}

variable "manage_route53_in_terraform" {
  default = true
}

variable "route53_hosted_zone_id" {
  description = "The ID of an existing Route 53 Hosted Zone (leave blank if creating a new one)"
  type        = string
  default     = "" # Providing a default prevents Terraform from asking you for it every time
}

variable "waf_log_destination" {
  type        = string
  description = "The ARN of the destination (CloudWatch Log Group, S3, or Firehose)"
  default     = "cloudwatch"
}

variable "waf_log_retention_days" {
  type        = number
  description = "Number of days to retain WAF logs in CloudWatch Logs"
  default     = 7
}

variable "enable_alb_access_logs" {
  description = "Enable ALB access logging to S3"
  type        = bool
  default     = true
}

variable "alb_access_logs_prefix" {
  description = "S3 prefix for ALB access logs"
  type        = string
  default     = "alb-access-logs"
}

variable "alb_access_logs_bucket_name" {
  description = "Name of S3 bucket for ALB access logs"
  type        = string
  default     = ""
}


variable "enable_waf_sampled_requests_only" {
  description = "If true, students can optionally filter/redact fields later. (Placeholder toggle.)"
  type        = bool
  default     = false
}