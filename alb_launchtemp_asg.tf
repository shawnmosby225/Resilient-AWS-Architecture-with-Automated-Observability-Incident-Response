locals {
  chewbacca_fqdn = "${var.app_subdomain}.${var.domain_name}"
}

resource "aws_security_group" "chewbacca_alb_sg01" {
  name        = "${var.project_name}-alb-sg01"
  description = "ALB security group"
  vpc_id      = aws_vpc.chewbacca_vpc01.id

  tags = {
    Name = "${var.project_name}-alb-sg01"
  }
}

resource "aws_security_group_rule" "alb_ingress_http" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  cidr_blocks              = ["0.0.0.0/0"]
  security_group_id = aws_security_group.chewbacca_alb_sg01.id
}
resource "aws_security_group_rule" "alb_ingress_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  cidr_blocks              = ["0.0.0.0/0"]
  security_group_id = aws_security_group.chewbacca_alb_sg01.id
}
resource "aws_security_group_rule" "alb_egress_to_tg" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  cidr_blocks              = [aws_vpc.chewbacca_vpc01.cidr_block]
  security_group_id = aws_security_group.chewbacca_alb_sg01.id
} 

resource "aws_security_group_rule" "chewbacca_ec2_ingress_from_alb01" {
  type                     = "ingress"
  security_group_id        = aws_security_group.chewbacca_ec2_sg01.id
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.chewbacca_alb_sg01.id
}

resource "aws_lb" "chewbacca_alb01" {
  name               = "${var.project_name}-alb01"
  load_balancer_type = "application"
  internal           = false
  security_groups = [aws_security_group.chewbacca_alb_sg01.id]
  subnets         = aws_subnet.chewbacca_public_subnets[*].id

access_logs {
    bucket  = aws_s3_bucket.chewbacca_alb_logs_bucket01[0].bucket
    prefix  = var.alb_access_logs_prefix
    enabled = var.enable_alb_access_logs
  }

  tags = {
    Name = "${var.project_name}-alb01"
  }
}

resource "aws_lb_target_group" "chewbacca_tg01" {
  name     = "${var.project_name}-tg01"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.chewbacca_vpc01.id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    matcher             = "200-399"
  }

  tags = {
    Name = "${var.project_name}-tg01"
  }
}

resource "aws_lb_target_group_attachment" "chewbacca_tg_attach01" {
  target_group_arn = aws_lb_target_group.chewbacca_tg01.arn
  target_id        = aws_instance.chewbacca_ec201_private_bonus.id
  port             = 80
}

############################################
# ACM Certificate (TLS) for app.chewbacca-growl.com
############################################

resource "aws_acm_certificate" "chewbacca_acm_cert01" {
  domain_name       = local.chewbacca_fqdn
  validation_method = var.certificate_validation_method

  tags = {
    Name = "${var.project_name}-acm-cert01"
  }
}

############################################
# ALB Listeners: HTTP -> HTTPS redirect, HTTPS -> TG
############################################

resource "aws_lb_listener" "chewbacca_http_listener01" {
  load_balancer_arn = aws_lb.chewbacca_alb01.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "chewbacca_https_listener01" {
  load_balancer_arn = aws_lb.chewbacca_alb01.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.chewbacca_acm_cert01.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.chewbacca_tg01.arn
  }

  depends_on = [ aws_acm_certificate_validation.chewbacca_acm_validation01_dns_bonus ]
}

############################################
# WAFv2 Web ACL (Basic managed rules)
############################################

resource "aws_wafv2_web_acl" "chewbacca_waf01" {
  count = var.enable_waf ? 1 : 0
  name  = "${var.project_name}-waf01"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf01"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-waf-common"
      sampled_requests_enabled   = true
    }
  }

  tags = {
    Name = "${var.project_name}-waf01"
  }
}

resource "aws_wafv2_web_acl_association" "chewbacca_waf_assoc01" {
  count = var.enable_waf ? 1 : 0
  resource_arn = aws_lb.chewbacca_alb01.arn
  web_acl_arn  = aws_wafv2_web_acl.chewbacca_waf01[0].arn
}

############################################
# CloudWatch Alarm: ALB 5xx -> SNS
############################################

resource "aws_cloudwatch_metric_alarm" "chewbacca_alb_5xx_alarm01" {
  alarm_name          = "${var.project_name}-alb-5xx-alarm01"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alb_5xx_evaluation_periods
  threshold           = var.alb_5xx_threshold
  period              = var.alb_5xx_period_seconds
  statistic           = "Sum"

  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_ELB_5XX_Count"

  dimensions = {
    LoadBalancer = aws_lb.chewbacca_alb01.arn_suffix
  }

  alarm_actions = [aws_sns_topic.chewbacca_sns_topic01.arn]

  tags = {
    Name = "${var.project_name}-alb-5xx-alarm01"
  }
}

############################################
# CloudWatch Dashboard (Skeleton)
############################################

resource "aws_cloudwatch_dashboard" "chewbacca_dashboard01" {
  dashboard_name = "${var.project_name}-dashboard01"

  dashboard_body = jsonencode({
    widgets = [
      {
        type  = "metric"
        x     = 0
        y     = 0
        width = 12
        height = 6
        properties = {
          metrics = [
            [ "AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.chewbacca_alb01.arn_suffix ],
            [ ".", "HTTPCode_ELB_5XX_Count", ".", aws_lb.chewbacca_alb01.arn_suffix ]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Chewbacca ALB: Requests + 5XX"
        }
      },
      {
        type  = "metric"
        x     = 12
        y     = 0
        width = 12
        height = 6
        properties = {
          metrics = [
            [ "AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.chewbacca_alb01.arn_suffix ]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Chewbacca ALB: Target Response Time"
        }
      }
    ]
  })
}
