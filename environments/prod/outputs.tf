output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = module.compute.alb_dns_name
}

output "db_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = module.database.db_endpoint
  sensitive   = true
}

output "db_secret_arn" {
  description = "The ARN of the Secrets Manager secret containing the DB password"
  value       = module.database.db_secret_arn
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.networking.vpc_id
}

output "bucket_arn" {
  description = "The ARN of the S3 storage bucket"
  value       = module.storage.bucket_arn
}
