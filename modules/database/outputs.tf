output "db_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = aws_db_instance.main.endpoint
}

output "db_port" {
  description = "The port the RDS instance is listening on"
  value       = aws_db_instance.main.port
}

output "db_identifier" {
  description = "The identifier of the RDS instance"
  value       = aws_db_instance.main.identifier
}

output "db_secret_arn" {
  description = "The ARN of the Secrets Manager secret containing the DB password (never the password value)"
  value       = aws_secretsmanager_secret.db_password.arn
}
