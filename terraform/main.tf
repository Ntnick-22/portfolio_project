# Configure the AWS Provider
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Data source to get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source to get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create VPC
resource "aws_vpc" "portfolio_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "portfolio_igw" {
  vpc_id = aws_vpc.portfolio_vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Create public subnets
resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.portfolio_vpc.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
}

# Create private subnets
resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.portfolio_vpc.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
  }
}

# Create route table for public subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.portfolio_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.portfolio_igw.id
  }

  tags = {
    Name = "${var.project_name}-public-route-table"
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public_route_table_association" {
  count          = length(aws_subnet.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

# Security Group for Application Load Balancer
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.portfolio_vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# Security Group for EC2 instances
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-ec2-sg"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.portfolio_vpc.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

# Create S3 bucket for application assets
resource "aws_s3_bucket" "portfolio_assets" {
  bucket = "${var.project_name}-assets-${random_string.bucket_suffix.result}"

  tags = {
    Name = "${var.project_name}-assets"
  }
}

# Random string for unique bucket naming
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "portfolio_assets_versioning" {
  bucket = aws_s3_bucket.portfolio_assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "portfolio_assets_pab" {
  bucket = aws_s3_bucket.portfolio_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for visitor counter
resource "aws_dynamodb_table" "visitor_counter" {
  name           = "${var.project_name}-visitor-counter"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name = "${var.project_name}-visitor-counter"
  }
}

# DynamoDB table item for visitor counter
resource "aws_dynamodb_table_item" "visitor_counter_item" {
  table_name = aws_dynamodb_table.visitor_counter.name
  hash_key   = aws_dynamodb_table.visitor_counter.hash_key

  item = <<ITEM
{
  "id": {"S": "visitor_count"},
  "count": {"N": "0"}
}
ITEM
}

# IAM role for EC2 instances
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for DynamoDB and S3 access
resource "aws_iam_policy" "ec2_policy" {
  name        = "${var.project_name}-ec2-policy"
  description = "Policy for EC2 instances to access DynamoDB and S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.visitor_counter.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.portfolio_assets.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.portfolio_assets.arn
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "ec2_policy_attachment" {
  policy_arn = aws_iam_policy.ec2_policy.arn
  role       = aws_iam_role.ec2_role.name
}

# Instance profile for EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# Key pair for EC2 instances
resource "aws_key_pair" "portfolio_key" {
  key_name   = "${var.project_name}-key"
  public_key = var.public_key
}

# Launch template for EC2 instances
resource "aws_launch_template" "portfolio_lt" {
  name_prefix   = "${var.project_name}-lt"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.portfolio_key.key_name

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    s3_bucket    = aws_s3_bucket.portfolio_assets.bucket
    dynamodb_table = aws_dynamodb_table.visitor_counter.name
    aws_region   = var.aws_region
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-instance"
    }
  }
}

# Application Load Balancer
resource "aws_lb" "portfolio_alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public_subnets[*].id

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Target group for ALB
resource "aws_lb_target_group" "portfolio_tg" {
  name     = "${var.project_name}-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.portfolio_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/api/health"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}

# ALB listener
resource "aws_lb_listener" "portfolio_listener" {
  load_balancer_arn = aws_lb.portfolio_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "forward"
    
    forward {
      target_group {
        arn = aws_lb_target_group.portfolio_tg.arn
      }
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "portfolio_asg" {
  name                = "${var.project_name}-asg"
  vpc_zone_identifier = aws_subnet.public_subnets[*].id
  target_group_arns   = [aws_lb_target_group.portfolio_tg.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  launch_template {
    id      = aws_launch_template.portfolio_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "portfolio_logs" {
  name              = "/aws/ec2/${var.project_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-logs"
  }
}

# Data source for existing Route 53 hosted zone
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# SSL Certificate
resource "aws_acm_certificate" "ssl_cert" {
  count             = var.create_ssl_certificate ? 1 : 0
  domain_name       = "${var.subdomain}.${var.domain_name}"
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.domain_name}",
    var.domain_name
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-ssl-cert"
  }
}

# Route 53 record for SSL certificate validation
resource "aws_route53_record" "ssl_validation" {
  for_each = var.create_ssl_certificate ? {
    for dvo in aws_acm_certificate.ssl_cert[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

# SSL Certificate validation
resource "aws_acm_certificate_validation" "ssl_validation" {
  count           = var.create_ssl_certificate ? 1 : 0
  certificate_arn = aws_acm_certificate.ssl_cert[0].arn
  validation_record_fqdns = [for record in aws_route53_record.ssl_validation : record.fqdn]

  timeouts {
    create = "5m"
  }
}

# Update ALB to support HTTPS
resource "aws_lb_listener" "portfolio_https_listener" {
  count             = var.create_ssl_certificate ? 1 : 0
  load_balancer_arn = aws_lb.portfolio_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate_validation.ssl_validation[0].certificate_arn

  default_action {
    type = "forward"
    
    forward {
      target_group {
        arn = aws_lb_target_group.portfolio_tg.arn
      }
    }
  }
}

# Update HTTP listener to redirect to HTTPS
resource "aws_lb_listener" "portfolio_http_redirect" {
  count             = var.create_ssl_certificate ? 1 : 0
  load_balancer_arn = aws_lb.portfolio_alb.arn
  port              = "80"
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

# Route 53 record pointing to ALB
resource "aws_route53_record" "portfolio" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.portfolio_alb.dns_name
    zone_id                = aws_lb.portfolio_alb.zone_id
    evaluate_target_health = true
  }
}