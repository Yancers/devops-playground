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
  environment = "staging"
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
  vpc_cidr = "10.1.0.0/16"
  availability_zones = ["${var.region}a", "${var.region}b"]
  public_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.101.0/24", "10.1.102.0/24"]
  
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
  min_size = 2
  max_size = 5
  
  tags = local.common_tags
}

# RDS Module
module "rds" {
  count = var.enable_rds ? 1 : 0
  source = "../../modules/rds"
  
  name = "${var.cluster_name}-${local.environment}-db"
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  allowed_cidr_blocks = [module.vpc.vpc_cidr_block]
  
  instance_class = "db.t3.small"
  allocated_storage = 50
  max_allocated_storage = 200
  
  tags = local.common_tags
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
