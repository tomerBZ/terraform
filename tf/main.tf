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

// Resource 1: VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
    yor_trace   = "c0f16cf6-543c-43f0-a629-308d2994a4bc"
  }
}

// Resource 2: Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.environment}-public-subnet"
    Environment = var.environment
    yor_trace   = "1c97155f-18e1-4d7b-909d-b41251b450f9"
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
    yor_trace   = "2d2ae835-c5e3-4348-aec0-85ce3f90558c"
  }
}

// Resource 4: S3 Bucket
resource "aws_s3_bucket" "data" {
  bucket = "${var.environment}-data-bucket-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "${var.environment}-data-bucket"
    Environment = var.environment
    yor_trace   = "4c97e8cd-a348-49f0-b2bc-b78321194bd5"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

// Resource 5: EC2 Instance
resource "aws_instance" "web_server" {
  ami                    = "ami-0c55b159cbfafe1f0" // Amazon Linux 2 (update as needed)
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from Terraform</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name        = "${var.environment}-web-server"
    Environment = var.environment
    yor_trace   = "82f039c1-373e-48c2-82fa-4c149e0e1666"
  }
}

// Outputs
output "vpc_id" {
  value = aws_vpc.main.id
}

output "web_server_public_ip" {
  value = aws_instance.web_server.public_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.data.bucket
}