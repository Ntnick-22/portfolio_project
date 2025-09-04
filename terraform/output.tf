output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.portfolio_vpc.id
}

output "public_subnets" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public_subnets[*].id
}

output "private_subnets" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private_subnets[*].id
}

output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.portfolio_alb.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.portfolio_alb.zone_id
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.portfolio_assets.bucket
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.visitor_counter.name
}

output "ec2_security_group_id" {
  description = "ID of the EC2 security group"
  value       = aws_security_group.ec2_sg.id
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb_sg.id
}

output "website_url" {
  description = "URL of the deployed website"
  value       = var.create_ssl_certificate ? "https://${var.subdomain}.${var.domain_name}" : "http://${aws_lb.portfolio_alb.dns_name}"
}

output "cloudwatch_log_group" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.portfolio_logs.name
}

output "domain_name" {
  description = "Custom domain name"
  value       = "${var.subdomain}.${var.domain_name}"
}

output "ssl_certificate_arn" {
  description = "ARN of the SSL certificate"
  value       = var.create_ssl_certificate ? aws_acm_certificate.ssl_cert[0].arn : null
}