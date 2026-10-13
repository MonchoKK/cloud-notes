#!/usr/bin/env bash
# ==============================================================================
# CloudNotes - AWS Cloud Deployment Automation (Bash)
# ==============================================================================

set -euo pipefail

REGION="${1:-eu-west-1}"
DB_PASSWORD="${2:-}"
INSTANCE_TYPE="${3:-t3.micro}"
DB_INSTANCE_CLASS="${4:-db.t4g.micro}"

echo -e "\n\033[1;36m☁️  CloudNotes AWS Deployment Automation\033[0m"
echo -e "\033[1;36m========================================\033[0m\n"

# 1. Verify AWS Identity
echo -e "\033[1;33m🔍 [1/6] Verifying AWS credentials...\033[0m"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
echo -e "\033[1;32m✅ Authenticated as Account: ${ACCOUNT_ID}\033[0m"
echo -e "\033[1;32m📍 Target Region: ${REGION}\033[0m"

# 2. Database Password
if [ -z "${DB_PASSWORD}" ]; then
  DB_PASSWORD="CloudNotes$(openssl rand -hex 6 2>/dev/null || date +%s%N)!"
  echo -e "\033[1;35m🔑 Generated secure database password: ${DB_PASSWORD}\033[0m"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="${SCRIPT_DIR}/deployment-state.json"

# 3. Create VPC & Networking
echo -e "\n\033[1;33m🌐 [2/6] Provisioning VPC and Networking...\033[0m"
VPC_ID=$(aws ec2 create-vpc --cidr-block "10.0.0.0/16" --region "${REGION}" --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=cloudnotes-vpc}]" --query "Vpc.VpcId" --output text)
aws ec2 modify-vpc-attribute --vpc-id "${VPC_ID}" --enable-dns-hostnames '{"Value":true}' --region "${REGION}"
aws ec2 modify-vpc-attribute --vpc-id "${VPC_ID}" --enable-dns-support '{"Value":true}' --region "${REGION}"
echo "  • Created VPC: ${VPC_ID}"

IGW_ID=$(aws ec2 create-internet-gateway --region "${REGION}" --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=cloudnotes-igw}]" --query "InternetGateway.InternetGatewayId" --output text)
aws ec2 attach-internet-gateway --vpc-id "${VPC_ID}" --internet-gateway-id "${IGW_ID}" --region "${REGION}"
echo "  • Attached Internet Gateway: ${IGW_ID}"

AZ_A=$(aws ec2 describe-availability-zones --region "${REGION}" --query "AvailabilityZones[0].ZoneName" --output text)
AZ_B=$(aws ec2 describe-availability-zones --region "${REGION}" --query "AvailabilityZones[1].ZoneName" --output text)

PUBLIC_SUBNET_ID=$(aws ec2 create-subnet --vpc-id "${VPC_ID}" --cidr-block "10.0.1.0/24" --availability-zone "${AZ_A}" --region "${REGION}" --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=cloudnotes-public-subnet}]" --query "Subnet.SubnetId" --output text)
aws ec2 modify-subnet-attribute --subnet-id "${PUBLIC_SUBNET_ID}" --map-public-ip-on-launch --region "${REGION}"

PRIVATE_SUBNET_1_ID=$(aws ec2 create-subnet --vpc-id "${VPC_ID}" --cidr-block "10.0.2.0/24" --availability-zone "${AZ_A}" --region "${REGION}" --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=cloudnotes-private-subnet-1}]" --query "Subnet.SubnetId" --output text)
PRIVATE_SUBNET_2_ID=$(aws ec2 create-subnet --vpc-id "${VPC_ID}" --cidr-block "10.0.3.0/24" --availability-zone "${AZ_B}" --region "${REGION}" --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=cloudnotes-private-subnet-2}]" --query "Subnet.SubnetId" --output text)

ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id "${VPC_ID}" --region "${REGION}" --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=cloudnotes-public-rt}]" --query "RouteTable.RouteTableId" --output text)
aws ec2 create-route --route-table-id "${ROUTE_TABLE_ID}" --destination-cidr-block "0.0.0.0/0" --gateway-id "${IGW_ID}" --region "${REGION}" >/dev/null
aws ec2 associate-route-table --route-table-id "${ROUTE_TABLE_ID}" --subnet-id "${PUBLIC_SUBNET_ID}" --region "${REGION}" >/dev/null

# 4. Security Groups
echo -e "\n\033[1;33m🛡️  [3/6] Configuring Security Groups...\033[0m"
APP_SG_ID=$(aws ec2 create-security-group --group-name "cloudnotes-app-sg" --description "Security group for CloudNotes EC2" --vpc-id "${VPC_ID}" --region "${REGION}" --query "GroupId" --output text)
aws ec2 authorize-security-group-ingress --group-id "${APP_SG_ID}" --protocol tcp --port 80 --cidr "0.0.0.0/0" --region "${REGION}" >/dev/null
aws ec2 authorize-security-group-ingress --group-id "${APP_SG_ID}" --protocol tcp --port 8080 --cidr "0.0.0.0/0" --region "${REGION}" >/dev/null
aws ec2 authorize-security-group-ingress --group-id "${APP_SG_ID}" --protocol tcp --port 22 --cidr "0.0.0.0/0" --region "${REGION}" >/dev/null

DB_SG_ID=$(aws ec2 create-security-group --group-name "cloudnotes-db-sg" --description "Security group for CloudNotes RDS" --vpc-id "${VPC_ID}" --region "${REGION}" --query "GroupId" --output text)
aws ec2 authorize-security-group-ingress --group-id "${DB_SG_ID}" --protocol tcp --port 5432 --source-group "${APP_SG_ID}" --region "${REGION}" >/dev/null

# 5. RDS PostgreSQL
echo -e "\n\033[1;33m🗄️  [4/6] Provisioning Amazon RDS PostgreSQL Database...\033[0m"
DB_SUBNET_GROUP="cloudnotes-db-subnet-group"
aws rds create-db-subnet-group \
  --db-subnet-group-name "${DB_SUBNET_GROUP}" \
  --db-subnet-group-description "CloudNotes private DB Subnet Group" \
  --subnet-ids "${PRIVATE_SUBNET_1_ID}" "${PRIVATE_SUBNET_2_ID}" \
  --region "${REGION}" >/dev/null

DB_INSTANCE_ID="cloudnotes-postgres-db"
aws rds create-db-instance \
  --db-instance-identifier "${DB_INSTANCE_ID}" \
  --db-instance-class "${DB_INSTANCE_CLASS}" \
  --engine postgres \
  --engine-version "16.3" \
  --master-username "cloudnotes" \
  --master-user-password "${DB_PASSWORD}" \
  --allocated-storage 20 \
  --storage-type gp3 \
  --db-name "cloudnotes" \
  --db-subnet-group-name "${DB_SUBNET_GROUP}" \
  --vpc-security-group-ids "${DB_SG_ID}" \
  --no-publicly-accessible \
  --region "${REGION}" >/dev/null

echo "  • Waiting for RDS instance to initialize (typically 3-6 minutes)..."
aws rds wait db-instance-available --db-instance-identifier "${DB_INSTANCE_ID}" --region "${REGION}"
DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier "${DB_INSTANCE_ID}" --region "${REGION}" --query "DBInstances[0].Endpoint.Address" --output text)
echo -e "\033[1;32m✅ RDS PostgreSQL available at: ${DB_ENDPOINT}\033[0m"

# 6. EC2 Compute
echo -e "\n\033[1;33m🚀 [5/6] Launching EC2 Instance & Deploying CloudNotes...\033[0m"
AMI_ID=$(aws ec2 describe-images --owners amazon --filters "Name=name,Values=al2023-ami-2023.*-x86_64" "Name=state,Values=available" --query "sort_by(Images, &CreationDate)[-1].ImageId" --region "${REGION}" --output text)

USER_DATA_CONTENT=$(sed \
  -e "s|DB_HOST=\"\${DB_HOST:-postgres}\"|DB_HOST=\"${DB_ENDPOINT}\"|g" \
  -e "s|DB_PASSWORD=\"\${DB_PASSWORD:-cloudnotes_secret}\"|DB_PASSWORD=\"${DB_PASSWORD}\"|g" \
  "${SCRIPT_DIR}/user-data.sh")
USER_DATA_BASE64=$(echo "${USER_DATA_CONTENT}" | base64 | tr -d '\n')

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "${AMI_ID}" \
  --instance-type "${INSTANCE_TYPE}" \
  --subnet-id "${PUBLIC_SUBNET_ID}" \
  --security-group-ids "${APP_SG_ID}" \
  --user-data "${USER_DATA_BASE64}" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=cloudnotes-app-server}]" \
  --region "${REGION}" \
  --query "Instances[0].InstanceId" --output text)

echo "  • Waiting for EC2 instance (${INSTANCE_ID}) to run..."
aws ec2 wait instance-running --instance-ids "${INSTANCE_ID}" --region "${REGION}"
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "${INSTANCE_ID}" --region "${REGION}" --query "Reservations[0].Instances[0].PublicIpAddress" --output text)

cat <<EOF > "${STATE_FILE}"
{
  "Region": "${REGION}",
  "VpcId": "${VPC_ID}",
  "IgwId": "${IGW_ID}",
  "PublicSubnetId": "${PUBLIC_SUBNET_ID}",
  "PrivateSubnet1Id": "${PRIVATE_SUBNET_1_ID}",
  "PrivateSubnet2Id": "${PRIVATE_SUBNET_2_ID}",
  "RouteTableId": "${ROUTE_TABLE_ID}",
  "AppSgId": "${APP_SG_ID}",
  "DbSgId": "${DB_SG_ID}",
  "DbInstanceId": "${DB_INSTANCE_ID}",
  "DbEndpoint": "${DB_ENDPOINT}",
  "InstanceId": "${INSTANCE_ID}",
  "PublicIp": "${PUBLIC_IP}"
}
EOF

echo -e "\n\033[1;32m🎉 [6/6] CloudNotes Cloud Deployment Complete!\033[0m"
echo -e "============================================="
echo -e "🌐 Application Web UI:     http://${PUBLIC_IP}"
echo -e "📱 Application Direct:     http://${PUBLIC_IP}:8080"
echo -e "🩺 Healthcheck Probe:      http://${PUBLIC_IP}:8080/actuator/health"
echo -e "🗄️  RDS Endpoint (Private): ${DB_ENDPOINT}:5432"
echo -e "💾 Deployment State:       ${STATE_FILE}"
echo -e "\n\033[1;33mNote: Allow ~1-2 minutes for Docker container build and startup on the instance.\033[0m\n"
