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
dnf install -y docker git amazon-cloudwatch-agent

# 2. Start and enable Docker daemon
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# 3. Configure log directories & CloudWatch Unified Agent
echo "=== [CloudNotes] Configuring Amazon CloudWatch Unified Agent ==="
mkdir -p /var/log/cloudnotes
chmod 777 /var/log/cloudnotes

mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
cat << 'EOF' > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/cloudnotes/app.log",
            "log_group_name": "/cloudnotes/application",
            "log_stream_name": "{instance_id}-app",
            "timestamp_format": "%Y-%m-%d %H:%M:%S.%f",
            "auto_removal": false
          },
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "/cloudnotes/provisioning",
            "log_stream_name": "{instance_id}-user-data",
            "timestamp_format": "%Y-%m-%d %H:%M:%S",
            "auto_removal": false
          },
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/cloudnotes/system",
            "log_stream_name": "{instance_id}-system",
            "timestamp_format": "%b %d %H:%M:%S"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "CloudNotes/EC2",
    "metrics_collected": {
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "/"
        ]
      }
    },
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}"
    }
  }
}
EOF

# Start and enable CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
systemctl enable amazon-cloudwatch-agent

# 4. Create application working directory
APP_DIR="/opt/cloudnotes"
mkdir -p "${APP_DIR}"
cd "${APP_DIR}"

# 5. Clone repository
git clone https://github.com/MonchoKK/cloud-notes.git .

# 6. Retrieve deployment parameters injected via script or environment
# Note: If placeholders are present, they are substituted during deploy script execution
DB_HOST="${DB_HOST:-postgres}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-cloudnotes}"
DB_USER="${DB_USER:-cloudnotes}"
DB_PASSWORD="${DB_PASSWORD:-cloudnotes_secret}"
APP_PORT="${APP_PORT:-8080}"

# 7. Generate production .env file
cat <<EOF > .env
APP_PORT=${APP_PORT}
SPRING_PROFILES_ACTIVE=prod
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
LOG_PATH=/var/log/cloudnotes/app.log
JAVA_OPTS=-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0
EOF

echo "=== [CloudNotes] Launching CloudNotes container ==="

# 8. Pull prebuilt image from GitHub Container Registry (GHCR) or fallback to local docker build
IMAGE_TAG="${IMAGE_TAG:-ghcr.io/monchokk/cloud-notes:latest}"
echo "Attempting to pull published container image: ${IMAGE_TAG}"

if docker pull "${IMAGE_TAG}"; then
  echo "Successfully pulled ${IMAGE_TAG} from container registry."
  CONTAINER_IMAGE="${IMAGE_TAG}"
else
  echo "Registry pull failed or image not yet published; falling back to local container build..."
  docker build -t cloudnotes:latest .
  CONTAINER_IMAGE="cloudnotes:latest"
fi

# Run container with auto-restart, port forwarding, and host log volume mount
docker run -d \
  --name cloudnotes-app \
  --restart always \
  -p 80:8080 \
  -p 8080:8080 \
  -v /var/log/cloudnotes:/var/log/cloudnotes \
  --env-file .env \
  "${CONTAINER_IMAGE}"

echo "=== [CloudNotes] Provisioning completed successfully at $(date) ==="
