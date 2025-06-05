// create a terraform basic example

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  required_version = ">= 1.0.0"
}

provider "aws" {
  region = var.aws_region
}

// Variables
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_count" {
  description = "Number of subnets to create"
  type        = number
  default     = 3
}

variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 2
}

// Resource 1: VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
    yor_trace   = "254ac4ca-55d8-4156-8c7f-cd4c0bdcf556"
  }
}

// Resource 2: Multiple Subnets using count
resource "aws_subnet" "public" {
  count                   = var.subnet_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = "${var.aws_region}${["a", "b", "c"][count.index % 3]}"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.environment}-public-subnet-${count.index + 1}"
    Environment = var.environment
    yor_trace   = "48524c5c-c8a9-4b27-8b5e-dbcc5c8d3a02"
  }
}

// Resource 3: Security Group
resource "aws_security_group" "web" {
  name        = "${var.environment}-web-sg"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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
    Name        = "${var.environment}-web-sg"
    Environment = var.environment
    yor_trace   = "7fcaaeba-53fc-4990-b0d1-ccb97b7b4fb8"
  }
}

// Resource 4: S3 Bucket
resource "aws_s3_bucket" "data" {
  bucket = "${var.environment}-data-bucket-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "${var.environment}-data-bucket"
    Environment = var.environment
    yor_trace   = "4c936ee0-c927-4d0a-8a09-f2084a46d45e"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

// Resource 5: Multiple EC2 Instances using count
resource "aws_instance" "web_server" {
  count                  = var.instance_count
  ami                    = "ami-0c55b159cbfafe1f0" // Amazon Linux 2 (update as needed)
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public[count.index % var.subnet_count].id
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from Terraform - Server ${count.index + 1}</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name        = "${var.environment}-web-server-${count.index + 1}"
    Environment = var.environment
    yor_trace   = "17158bcf-5e27-479e-a1f6-eda72ea9afc7"
  }
}

// Example of using for_each with a map
variable "additional_tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default = {
    Project     = "TerraformDemo"
    Owner       = "DevOps"
    CostCenter  = "IT-123"
    Compliance  = "SOC2"
  }
}

// Resource 6: Route53 records using for_each
resource "aws_route53_record" "web_servers" {
  for_each = {
    for idx, instance in aws_instance.web_server : 
    "server-${idx}" => instance.public_ip
  }
  
  zone_id = "DUMMY_ZONE_ID" // Replace with actual zone ID
  name    = "${each.key}.example.com"
  type    = "A"
  ttl     = 300
  records = [each.value]
}

// Outputs
output "vpc_id" {
  value = aws_vpc.main.id
}

output "web_server_public_ips" {
  value = [for instance in aws_instance.web_server : instance.public_ip]
}

output "subnet_ids" {
  value = aws_subnet.public[*].id
}

output "s3_bucket_name" {
  value = aws_s3_bucket.data.bucket
}

output "route53_records" {
  value = [for record in aws_route53_record.web_servers : record.name]
}
