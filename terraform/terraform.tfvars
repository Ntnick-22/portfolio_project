# AWS Configuration
aws_region = "eu-west-1"  # Change to your preferred region

# Project Configuration
project_name = "portfolio-dashboard-v2"
environment  = "production"

# Network Configuration
vpc_cidr        = "10.0.0.0/16"
public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]

# EC2 Configuration
instance_type = "t3.micro"  # Free tier eligible

# Auto Scaling Configuration
min_size         = 1
max_size         = 3
desired_capacity = 2

# Security Configuration
ssh_cidr_block = "80.233.75.251/32"  # CHANGE THIS to your IP for better security (e.g., "YOUR.IP.ADDRESS/32")

# SSH Key - ADD YOUR PUBLIC KEY HERE
public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC48vYEWl/J6Afw+ZteQO1FxJUs5Y8J3KUnTJHtU3Wsux0XR8Kgh5EVnGUzTVqAanZUqq8RntMZQcqEjzaohOHtyXHkkOPw9WsF8n+o0xfksLTPjzGhiDAFUxLarTU1VXnnW33EhWuh+4Doq+9glMXEKiY9DiqVXCCZHlxjWte6T1QvVl2iEf16sYJS96L5gjULGHmp0/HzfMZD0oc51+qLKZTB9RadZkm6S/vH0qXf8jkd7hYJmvo7YxF2dnhFQm0yZxx7LDblaw60gZ5iwpUA8wh9Kmx2u3sjxIobrxtwjG05iZYi8s1T0Z5Gt0a1xvWVZPeHYDAiYzaC6ICXEbQqFP+vcLRkt8a37uDqaL8zLAobxD9NGHZe810gvxw+gW8KX/4vinokSY+osg2GjFftJ7gvEJJfDLXAMmowa8TJ7mEGX48QZhvj4SWc4keJQOAFf+UGgVtSszI2YesAzHA4hyuPUu4D7KyuqZjf+mG9SoV4BKguTszVnjzR8Ss93L17E6YuXpgySvnGJ+kTlD1wDUSNP6NKwV2GtU0DVLDXlhUZ4GVKW3lsnpba8wykW7nifM1oIirsFmEqyb+l/4YO2cmD3TrO1jrTURtZGG3BNIugI4VCYeLiclwHRGS7etr2rU6xZs+Xal9I8aaEJHB7SJM0scBnURELZum4kEgEhQ== kyaws@Nick22 "  # Paste your SSH public key here

# Domain Configuration
domain_name = "nt-nick.link"
subdomain   = "portfolio"  # Creates portfolio.nt-nick.link
create_ssl_certificate = true