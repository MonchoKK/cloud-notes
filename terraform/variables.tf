variable "aws_region" {
  description = "AWS Region where infrastructure will be deployed"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name prefix applied to all AWS resources"
  type        = string
  default     = "cloudnotes"
}

variable "environment" {
  description = "Deployment environment name (e.g. prod, staging, dev)"
  type        = string
  default     = "prod"
}

# --- Networking Variables ---
variable "vpc_cidr" {
  description = "CIDR block for the custom VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet housing EC2"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_1_cidr" {
  description = "CIDR block for private subnet 1 (RDS AZ A)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_2_cidr" {
  description = "CIDR block for private subnet 2 (RDS AZ B)"
  type        = string
  default     = "10.0.3.0/24"
}

# --- Compute Variables ---
variable "instance_type" {
  description = "EC2 instance type for the CloudNotes application server"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Optional EC2 SSH Key Pair name for SSH remote administration"
  type        = string
  default     = null
}

variable "container_image" {
  description = "Container image tag from GitHub Container Registry or Docker Hub"
  type        = string
  default     = "ghcr.io/monchokk/cloud-notes:latest"
}

variable "app_port" {
  description = "Application HTTP port inside and exposed from the container"
  type        = number
  default     = 8080
}

# --- Database Variables ---
variable "db_instance_class" {
  description = "Amazon RDS PostgreSQL compute instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage size in Gigabytes for RDS PostgreSQL"
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "PostgreSQL major.minor engine version"
  type        = string
  default     = "16.3"
}

variable "db_name" {
  description = "Name of the initial PostgreSQL database created on RDS"
  type        = string
  default     = "cloudnotes"
}

variable "db_username" {
  description = "Master administrative username for PostgreSQL"
  type        = string
  default     = "cloudnotes"
}

variable "db_password" {
  description = "Master administrative password for PostgreSQL"
  type        = string
  sensitive   = true
  default     = "CloudNotesMaster2026!"
}

# --- Resource Tags ---
variable "tags" {
  description = "Common tags applied to all provisioned resources"
  type        = map(string)
  default = {
    Project   = "CloudNotes"
    ManagedBy = "Terraform"
  }
}

