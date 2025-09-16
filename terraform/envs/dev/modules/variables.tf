variable "owner" { type = string }
variable "branch" { type = string }
variable "cluster_name" { type = string }
variable "region" { type = string, default = "us-east-1" }
variable "ttl_hours" { type = number, default = 24 }
variable "node_instance_type" { type = string, default = "t3.small" }
variable "desired_capacity" { type = number, default = 1 }
