variable "owner" { 
  type = string 
  description = "Owner of the resources"
}

variable "branch" { 
  type = string 
  description = "Git branch name"
}

variable "cluster_name" { 
  type = string 
  description = "Name of the EKS cluster"
}

variable "region" { 
  type = string 
  default = "us-east-1" 
  description = "AWS region"
}

variable "ttl_hours" { 
  type = number 
  default = 720 
  description = "TTL in hours for the playground"
}

variable "node_instance_type" { 
  type = string 
  default = "t3.large" 
  description = "EC2 instance type for EKS nodes"
}

variable "desired_capacity" { 
  type = number 
  default = 5 
  description = "Desired number of nodes in the EKS node group"
}

variable "enable_rds" { 
  type = bool 
  default = true 
  description = "Enable RDS database for the environment"
}
