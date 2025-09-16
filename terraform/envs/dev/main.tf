terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
  
  backend "s3" {
    # Configured via backend-config.hcl
  }
}

provider "aws" { 
  region = var.region 
}

locals {
  environment = "dev"
  ttl_timestamp = formatdate("YYYY-MM-DDTHH:mm:ssZ", timeadd(timestamp(), "${var.ttl_hours}h"))
  common_tags = {
    Owner = var.owner
    Branch = var.branch
    Playground = "true"
    TTL = local.ttl_timestamp
    Environment = local.environment
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"
  
  name = "${var.cluster_name}-${local.environment}"
  vpc_cidr = "10.0.0.0/16"
  availability_zones = ["${var.region}a", "${var.region}b"]
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24"]
  
  tags = local.common_tags
}

# EKS Module
module "eks" {
  source = "../../modules/eks"
  
  cluster_name = "${var.cluster_name}-${local.environment}"
  kubernetes_version = "1.29"
  subnet_ids = module.vpc.private_subnet_ids
  vpc_id = module.vpc.vpc_id
  public_access_cidrs = ["0.0.0.0/0"]
  
  instance_types = [var.node_instance_type]
  desired_size = var.desired_capacity
  min_size = 1
  max_size = 3
  
  tags = local.common_tags
}

# RDS Module (optional for dev)
module "rds" {
  count = var.enable_rds ? 1 : 0
  source = "../../modules/rds"
  
  name = "${var.cluster_name}-${local.environment}-db"
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  allowed_cidr_blocks = [module.vpc.vpc_cidr_block]
  
  instance_class = "db.t3.micro"
  allocated_storage = 20
  max_allocated_storage = 100
  
  tags = local.common_tags
}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.cluster_name}-${local.environment}-terraform-state-${random_string.bucket_suffix.result}"
  
  tags = merge(local.common_tags, {
    Name = "Terraform State Bucket"
  })
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for Terraform state locking
resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "${var.cluster_name}-${local.environment}-terraform-state-lock"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(local.common_tags, {
    Name = "Terraform State Lock Table"
  })
}

# Random string for unique bucket naming
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Outputs
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = module.eks.ecr_repository_url
}

output "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "terraform_state_lock_table" {
  description = "DynamoDB table for Terraform state locking"
  value       = aws_dynamodb_table.terraform_state_lock.name
}
