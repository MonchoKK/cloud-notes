#!/bin/bash
# ==============================================================================
# CloudNotes - EC2 User-Data Bootstrapping Script
# Executes on first boot of Amazon Linux 2023 EC2 instance
# ==============================================================================

set -euo pipefail

# Output all commands and stdout/stderr to log file for debugging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "=== [CloudNotes] Starting EC2 Instance Provisioning at $(date) ==="

# 1. Update OS packages and install dependencies
dnf update -y
dnf install -y docker git

# 2. Start and enable Docker daemon
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# 3. Create application working directory
APP_DIR="/opt/cloudnotes"
mkdir -p "${APP_DIR}"
cd "${APP_DIR}"

# 4. Clone repository
git clone https://github.com/MonchoKK/cloud-notes.git .

# 5. Retrieve deployment parameters injected via script or environment
# Note: If placeholders are present, they are substituted during deploy script execution
DB_HOST="${DB_HOST:-postgres}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-cloudnotes}"
DB_USER="${DB_USER:-cloudnotes}"
DB_PASSWORD="${DB_PASSWORD:-cloudnotes_secret}"
APP_PORT="${APP_PORT:-8080}"

# 6. Generate production .env file
cat <<EOF > .env
APP_PORT=${APP_PORT}
SPRING_PROFILES_ACTIVE=prod
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
JAVA_OPTS=-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0
EOF

echo "=== [CloudNotes] Building and starting CloudNotes container ==="

# 7. Build and run CloudNotes application container
docker build -t cloudnotes:latest .

# Run container with auto-restart and port forwarding
docker run -d \
  --name cloudnotes-app \
  --restart always \
  -p 80:8080 \
  -p 8080:8080 \
  --env-file .env \
  cloudnotes:latest

echo "=== [CloudNotes] Provisioning completed successfully at $(date) ==="
