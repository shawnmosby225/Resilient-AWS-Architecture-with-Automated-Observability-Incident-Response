############################################
# Option 1: CloudWatch Logs destination
############################################

# Explanation: WAF logs in CloudWatch are your “blaster-cam footage”—fast search, fast triage, fast truth.
resource "aws_cloudwatch_log_group" "chewbacca_waf_log_group01" {
  count = var.waf_log_destination == "cloudwatch" ? 1 : 0

  # NOTE: AWS requires WAF log destination names start with aws-waf-logs- (students must not rename this).
  name              = "aws-waf-logs-${var.project_name}-webacl01"
  retention_in_days = var.waf_log_retention_days

  tags = {
    Name = "${var.project_name}-waf-log-group01"
  }
}

# Explanation: This wire connects the shield generator to the black box—WAF -> CloudWatch Logs.
resource "aws_wafv2_web_acl_logging_configuration" "chewbacca_waf_logging01" {
  count = var.enable_waf && var.waf_log_destination == "cloudwatch" ? 1 : 0

  resource_arn = aws_wafv2_web_acl.chewbacca_waf01[0].arn
  log_destination_configs = [
    aws_cloudwatch_log_group.chewbacca_waf_log_group01[0].arn
  ]

  # TODO: Students can add redacted_fields (authorization headers, cookies, etc.) as a stretch goal.
  # redacted_fields { ... }

  depends_on = [
    aws_wafv2_web_acl.chewbacca_waf01,
    aws_cloudwatch_log_resource_policy.chewbacca_waf_cw_policy01 # Add this!
  ]
}

# Explanation: WAF is a separate droid—CloudWatch needs to see its ID card before letting it write logs.
resource "aws_cloudwatch_log_resource_policy" "chewbacca_waf_cw_policy01" {
  count = var.waf_log_destination == "cloudwatch" ? 1 : 0
  
  policy_name = "${var.project_name}-waf-cw-policy01"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowWAFToLog"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.chewbacca_waf_log_group01[0].arn}:*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.chewbacca_self01.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.chewbacca_self01.account_id}:*"
          }
        }
      }
    ]
  })
}