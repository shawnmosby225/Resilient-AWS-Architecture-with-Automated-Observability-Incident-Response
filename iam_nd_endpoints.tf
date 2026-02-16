############################################
# Bonus A - Data + Locals
############################################

data "aws_caller_identity" "chewbacca_self01" {}

data "aws_region" "chewbacca_region01" {}

locals {
  chewbacca_prefix = var.project_name
  chewbacca_secret_arn = aws_secretsmanager_secret.chewbacca_db_secret01
}

############################################
# Move EC2 into PRIVATE subnet (no public IP)
############################################

resource "aws_instance" "chewbacca_ec201_private_bonus" {
  ami                         = var.ec2_ami_id
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.chewbacca_private_subnets[0].id
  vpc_security_group_ids      = [aws_security_group.chewbacca_ec2_sg01.id]
  iam_instance_profile        = aws_iam_instance_profile.chewbacca_instance_profile01.name
  associate_public_ip_address = false
  user_data                   = file("${path.module}/user_data.sh")

  tags = {
    Name = "${local.chewbacca_prefix}-ec201-private"
  }
}

############################################
# Security Group for VPC Interface Endpoints
############################################

resource "aws_security_group" "chewbacca_vpce_sg01" {
  name        = "${local.chewbacca_prefix}-vpce-sg01"
  description = "SG for VPC Interface Endpoints"
  vpc_id      = aws_vpc.chewbacca_vpc01.id

  tags = {
    Name = "${local.chewbacca_prefix}-vpce-sg01"
  }
}

resource "aws_security_group_rule" "endpoint_ingress_from_ec2" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.chewbacca_vpce_sg01.id
  source_security_group_id = aws_security_group.chewbacca_ec2_sg01.id
}
############################################
# VPC Endpoint - S3 (Gateway)
############################################

resource "aws_vpc_endpoint" "chewbacca_vpce_s3_gw01" {
  vpc_id            = aws_vpc.chewbacca_vpc01.id
  service_name      = "com.amazonaws.${data.aws_region.chewbacca_region01.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.chewbacca_private_rt01.id
  ]

  tags = {
    Name = "${local.chewbacca_prefix}-vpce-s3-gw01"
  }
}

############################################
# VPC Endpoints - SSM (Interface)
############################################

resource "aws_vpc_endpoint" "chewbacca_vpce_ssm01" {
  vpc_id              = aws_vpc.chewbacca_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.chewbacca_region01.name}.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.chewbacca_private_subnets[*].id
  security_group_ids = [aws_security_group.chewbacca_vpce_sg01.id]

  tags = {
    Name = "${local.chewbacca_prefix}-vpce-ssm01"
  }
}

resource "aws_vpc_endpoint" "chewbacca_vpce_ec2messages01" {
  vpc_id              = aws_vpc.chewbacca_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.chewbacca_region01.name}.ec2messages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.chewbacca_private_subnets[*].id
  security_group_ids = [aws_security_group.chewbacca_vpce_sg01.id]

  tags = {
    Name = "${local.chewbacca_prefix}-vpce-ec2messages01"
  }
}

resource "aws_vpc_endpoint" "chewbacca_vpce_ssmmessages01" {
  vpc_id              = aws_vpc.chewbacca_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.chewbacca_region01.name}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.chewbacca_private_subnets[*].id
  security_group_ids = [aws_security_group.chewbacca_vpce_sg01.id]

  tags = {
    Name = "${local.chewbacca_prefix}-vpce-ssmmessages01"
  }
}

############################################
# VPC Endpoint - CloudWatch Logs (Interface)
############################################

resource "aws_vpc_endpoint" "chewbacca_vpce_logs01" {
  vpc_id              = aws_vpc.chewbacca_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.chewbacca_region01.name}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.chewbacca_private_subnets[*].id
  security_group_ids = [aws_security_group.chewbacca_vpce_sg01.id]

  tags = {
    Name = "${local.chewbacca_prefix}-vpce-logs01"
  }
}

############################################
# VPC Endpoint - Secrets Manager (Interface)
############################################

resource "aws_vpc_endpoint" "chewbacca_vpce_secrets01" {
  vpc_id              = aws_vpc.chewbacca_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.chewbacca_region01.name}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.chewbacca_private_subnets[*].id
  security_group_ids = [aws_security_group.chewbacca_vpce_sg01.id]

  tags = {
    Name = "${local.chewbacca_prefix}-vpce-secrets01"
  }
}

############################################
# Optional: VPC Endpoint - KMS (Interface)
############################################

resource "aws_vpc_endpoint" "chewbacca_vpce_kms01" {
  vpc_id              = aws_vpc.chewbacca_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.chewbacca_region01.name}.kms"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.chewbacca_private_subnets[*].id
  security_group_ids = [aws_security_group.chewbacca_vpce_sg01.id]

  tags = {
    Name = "${local.chewbacca_prefix}-vpce-kms01"
  }
}

############################################
# Least-Privilege IAM 
############################################

resource "aws_iam_policy" "chewbacca_leastpriv_read_params01" {
  name        = "${local.chewbacca_prefix}-lp-ssm-read01"
  description = "Least-privilege read for SSM Parameter Store under /lab/db/*"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadLabDbParams"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.chewbacca_region01.name}:${data.aws_caller_identity.chewbacca_self01.account_id}:parameter/lab/db/*"
        ]
      }
    ]
  })
}

resource "aws_ssm_parameter" "db-endpoint" {
  name  = "/lab/db/endpoint"
  type  = "String"
  value = aws_db_instance.chewbacca_rds01.endpoint
  overwrite = true
}

resource "aws_iam_policy" "chewbacca_leastpriv_read_secret01" {
  name        = "${local.chewbacca_prefix}-lp-secrets-read01"
  description = "Least-privilege read for the lab DB secret"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadOnlyLabSecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [aws_secretsmanager_secret.chewbacca_db_secret01.arn]
      }
    ]
  })
}

resource "aws_iam_policy" "chewbacca_leastpriv_cwlogs01" {
  name        = "${local.chewbacca_prefix}-lp-cwlogs01"
  description = "Least-privilege CloudWatch Logs write for the app log group"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WriteLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.chewbacca_log_group01.arn}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "chewbacca_attach_lp_params01" {
  role       = aws_iam_role.chewbacca_ec2_role01.name
  policy_arn = aws_iam_policy.chewbacca_leastpriv_read_params01.arn
}

resource "aws_iam_role_policy_attachment" "chewbacca_attach_lp_secret01" {
  role       = aws_iam_role.chewbacca_ec2_role01.name
  policy_arn = aws_iam_policy.chewbacca_leastpriv_read_secret01.arn
}

resource "aws_iam_role_policy_attachment" "chewbacca_attach_lp_cwlogs01" {
  role       = aws_iam_role.chewbacca_ec2_role01.name
  policy_arn = aws_iam_policy.chewbacca_leastpriv_cwlogs01.arn
}

resource "aws_iam_role_policy_attachment" "chewbacca_ssm_managed_policy_attach" {
  role       = aws_iam_role.chewbacca_ec2_role01.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
