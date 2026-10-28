# ==============================================================================
# Amazon RDS PostgreSQL Database (Private Subnet Isolation)
# ==============================================================================

# 1. DB Subnet Group across 2 Availability Zones
resource "aws_db_subnet_group" "postgres" {
  name        = "${var.project_name}-db-subnet-group"
  description = "CloudNotes private DB Subnet Group across multiple AZs"
  subnet_ids  = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# 2. Managed PostgreSQL Instance
# Conforms to strict security requirements:
# - Placed in private subnets with zero public IP / zero public accessibility
# - Firewall access restricted exclusively to the EC2 application security group
resource "aws_db_instance" "postgres" {
  identifier                  = "${var.project_name}-postgres-db"
  engine                      = "postgres"
  engine_version              = var.db_engine_version
  instance_class              = var.db_instance_class
  allocated_storage           = var.db_allocated_storage
  storage_type                = "gp3"
  db_name                     = var.db_name
  username                    = var.db_username
  password                    = var.db_password
  db_subnet_group_name        = aws_db_subnet_group.postgres.name
  vpc_security_group_ids      = [aws_security_group.db.id]
  publicly_accessible         = false
  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false
  backup_retention_period     = 1
  skip_final_snapshot         = true
  deletion_protection         = false

  tags = {
    Name = "${var.project_name}-postgres"
  }
}

