output "db_instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.main.id
}

output "db_instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.main.arn
}

output "db_instance_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "db_instance_name" {
  description = "RDS instance database name"
  value       = aws_db_instance.main.db_name
}

output "db_instance_username" {
  description = "RDS instance root username"
  value       = aws_db_instance.main.username
}

output "db_instance_password_secret_arn" {
  description = "ARN of the secret containing the database password"
  value       = aws_secretsmanager_secret.rds_password.arn
}

output "db_security_group_id" {
  description = "Security group ID for the RDS instance"
  value       = aws_security_group.rds.id
}

output "db_subnet_group_name" {
  description = "DB subnet group name"
  value       = aws_db_subnet_group.main.name
}

output "kms_key_id" {
  description = "KMS key ID used for encryption"
  value       = aws_kms_key.rds.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN used for encryption"
  value       = aws_kms_key.rds.arn
}
