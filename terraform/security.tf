# ==============================================================================
# Security Groups
# ==============================================================================

# 1. EC2 Application Security Group
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Security group for CloudNotes EC2 application server"
  vpc_id      = aws_vpc.main.id

  # Inbound HTTP (Reverse proxy / direct web access)
  ingress {
    description = "Allow inbound HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound Application Port (Spring Boot direct)
  ingress {
    description = "Allow inbound Spring Boot direct access from anywhere"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound SSH (Management & Troubleshooting)
  ingress {
    description = "Allow inbound SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound All (Package updates, GHCR container pull, CloudWatch telemetry)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-app-sg"
  }
}

# 2. RDS Database Security Group
# CRITICAL: Restricts port 5432 ingress STRICTLY to the Application Security Group.
resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Security group for CloudNotes RDS PostgreSQL (isolated to App SG)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow PostgreSQL access strictly from CloudNotes EC2 App SG"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-db-sg"
  }
}

# ==============================================================================
# IAM Roles & Instance Profile for CloudWatch & EC2 Telemetry
# ==============================================================================

# 3. IAM Role for EC2
resource "aws_iam_role" "ec2" {
  name        = "${var.project_name}-ec2-role"
  description = "IAM execution role for CloudNotes EC2 instance to publish CloudWatch telemetry"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ec2-role"
  }
}

# 4. Attach CloudWatchAgentServerPolicy to EC2 IAM Role
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# 5. EC2 Instance Profile
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-instance-profile"
  role = aws_iam_role.ec2.name

  tags = {
    Name = "${var.project_name}-ec2-instance-profile"
  }
}

