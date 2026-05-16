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
  description = "VPC ID where resources will be created"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the ASG instances"
  type        = list(string)
}

variable "app_sg_id" {
  description = "ID of the application security group (from security module)"
  type        = string
}

variable "alb_sg_id" {
  description = "ID of the ALB security group (from security module)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the launch template"
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances in the ASG"
  type        = number
  default     = 2
}

variable "desired_capacity" {
  description = "Desired number of instances in the ASG"
  type        = number
  default     = 1
}

variable "app_port" {
  description = "Application port for the target group and health check"
  type        = number
  default     = 80
}

variable "ami_id" {
  description = "AMI ID to use for instances. If empty, the latest Amazon Linux 2023 AMI is looked up automatically"
  type        = string
  default     = ""
}

variable "user_data" {
  description = "User data script for EC2 instances. If empty, a default nginx setup script is used"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
