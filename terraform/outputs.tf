# ==============================================================================
# Network Outputs
# ==============================================================================
output "vpc_id" {
  description = "ID of the CloudNotes custom VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet where the application server runs"
  value       = aws_subnet.public.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets housing the RDS PostgreSQL instance"
  value       = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}

# ==============================================================================
# Security Outputs
# ==============================================================================
output "app_security_group_id" {
  description = "ID of the EC2 application security group"
  value       = aws_security_group.app.id
}

output "db_security_group_id" {
  description = "ID of the RDS database security group"
  value       = aws_security_group.db.id
}

# ==============================================================================
# Compute & Application Outputs
# ==============================================================================
output "ec2_instance_id" {
  description = "EC2 application instance ID"
  value       = aws_instance.app.id
}

output "ec2_public_ip" {
  description = "Public IPv4 address of the CloudNotes instance"
  value       = aws_instance.app.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS hostname of the CloudNotes instance"
  value       = aws_instance.app.public_dns
}

output "app_url" {
  description = "Primary URL to access the CloudNotes web application (Port 80)"
  value       = "http://${aws_instance.app.public_ip}"
}

output "app_direct_url" {
  description = "Direct Spring Boot URL to access the CloudNotes application (Port 8080)"
  value       = "http://${aws_instance.app.public_ip}:${var.app_port}"
}

output "health_check_url" {
  description = "Actuator health check probe endpoint"
  value       = "http://${aws_instance.app.public_ip}:${var.app_port}/actuator/health"
}

output "metrics_url" {
  description = "Actuator metrics endpoint"
  value       = "http://${aws_instance.app.public_ip}:${var.app_port}/actuator/metrics"
}

# ==============================================================================
# Database Outputs
# ==============================================================================
output "rds_endpoint" {
  description = "Full endpoint address and port of the private RDS PostgreSQL instance"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_address" {
  description = "Hostname/Address of the private RDS PostgreSQL instance"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "Port number of the RDS PostgreSQL instance"
  value       = aws_db_instance.postgres.port
}

output "rds_database_name" {
  description = "Database name on the RDS PostgreSQL instance"
  value       = aws_db_instance.postgres.db_name
}

