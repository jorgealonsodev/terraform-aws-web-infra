variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, or prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for restricting DB egress to VPC-only"
  type        = string
}

variable "app_port" {
  description = "Application port for the app security group ingress rule"
  type        = number
  default     = 80
}

variable "db_port" {
  description = "Database port for the DB security group ingress rule"
  type        = number
  default     = 5432
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
