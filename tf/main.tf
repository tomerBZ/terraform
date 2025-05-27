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
    yor_trace   = "faaf48b8-ea07-4e96-8355-ded2550a50f9"
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
    yor_trace   = "0114240f-892b-405c-8c89-f25be3781c1c"
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
    yor_trace   = "cbd59529-39ad-464e-bd2c-4b34e31cbc65"
  }
}

// Resource 4: S3 Bucket
resource "aws_s3_bucket" "data" {
  bucket = "${var.environment}-data-bucket-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "${var.environment}-data-bucket"
    Environment = var.environment
    yor_trace   = "b2cc72e8-ab52-4088-9ba1-2ad62e7bd7e2"
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
    yor_trace   = "ca96fd59-88ad-45d5-948f-40166b90b3d0"
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