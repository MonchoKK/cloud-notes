#!/usr/bin/env bash
# ==============================================================================
# CloudNotes - AWS Cloud Resource Teardown Automation (Bash)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="${1:-${SCRIPT_DIR}/deployment-state.json}"

if [ ! -f "${STATE_FILE}" ]; then
  echo -e "\033[1;31m❌ State file not found: ${STATE_FILE}\033[0m"
  exit 1
fi

echo -e "\n\033[1;31m⚠️  CloudNotes AWS Resource Teardown\033[0m"
echo -e "\033[1;31m====================================\033[0m\n"

REGION=$(grep -o '"Region": "[^"]*' "${STATE_FILE}" | cut -d'"' -f4)
INSTANCE_ID=$(grep -o '"InstanceId": "[^"]*' "${STATE_FILE}" | cut -d'"' -f4 || true)
DB_INSTANCE_ID=$(grep -o '"DbInstanceId": "[^"]*' "${STATE_FILE}" | cut -d'"' -f4 || true)
DB_SUBNET_GROUP="cloudnotes-db-subnet-group"
APP_SG_ID=$(grep -o '"AppSgId": "[^"]*' "${STATE_FILE}" | cut -d'"' -f4 || true)
DB_SG_ID=$(grep -o '"DbSgId": "[^"]*' "${STATE_FILE}" | cut -d'"' -f4 || true)
ROUTE_TABLE_ID=$(grep -o '"RouteTableId": "[^"]*' "${STATE_FILE}" | cut -d'"' -f4 || true)
PUBLIC_SUBNET_ID=$(grep -o '"PublicSubnetId": "[^"]*' "${STATE_FILE}" | cut -d'"' -f4 || true)
PRIVATE_SUBNET_1_ID=$(grep -o '"PrivateSubnet1Id": "[^"]*' "${STATE_FILE}" | cut -d'"' -f4 || true)
PRIVATE_SUBNET_2_ID=$(grep -o '"PrivateSubnet2Id": "[^"]*' "${STATE_FILE}" | cut -d'"' -f4 || true)
IGW_ID=$(grep -o '"IgwId": "[^"]*' "${STATE_FILE}" | cut -d'"' -f4 || true)
VPC_ID=$(grep -o '"VpcId": "[^"]*' "${STATE_FILE}" | cut -d'"' -f4 || true)
IAM_ROLE_NAME=$(grep -o '"IamRoleName": "[^"]*' "${STATE_FILE}" | cut -d'"' -f4 || true)
INSTANCE_PROFILE_NAME=$(grep -o '"InstanceProfileName": "[^"]*' "${STATE_FILE}" | cut -d'"' -f4 || true)

# 1. Terminate EC2
if [ -n "${INSTANCE_ID}" ]; then
  echo "🗑️  Terminating EC2 instance ${INSTANCE_ID}..."
  aws ec2 terminate-instances --instance-ids "${INSTANCE_ID}" --region "${REGION}" >/dev/null || true
  aws ec2 wait instance-terminated --instance-ids "${INSTANCE_ID}" --region "${REGION}" || true
fi

# 2. Delete RDS
if [ -n "${DB_INSTANCE_ID}" ]; then
  echo "🗑️  Deleting RDS instance ${DB_INSTANCE_ID}..."
  aws rds delete-db-instance --db-instance-identifier "${DB_INSTANCE_ID}" --skip-final-snapshot --delete-automated-backups --region "${REGION}" >/dev/null || true
  aws rds wait db-instance-deleted --db-instance-identifier "${DB_INSTANCE_ID}" --region "${REGION}" || true
fi

# 3. Delete DB Subnet Group
echo "🗑️  Deleting DB Subnet Group ${DB_SUBNET_GROUP}..."
aws rds delete-db-subnet-group --db-subnet-group-name "${DB_SUBNET_GROUP}" --region "${REGION}" >/dev/null || true

# 4. Security Groups
sleep 10
if [ -n "${DB_SG_ID}" ]; then
  aws ec2 delete-security-group --group-id "${DB_SG_ID}" --region "${REGION}" >/dev/null || true
fi
if [ -n "${APP_SG_ID}" ]; then
  aws ec2 delete-security-group --group-id "${APP_SG_ID}" --region "${REGION}" >/dev/null || true
fi

# 5. Route Table & Subnets
if [ -n "${ROUTE_TABLE_ID}" ]; then
  aws ec2 delete-route-table --route-table-id "${ROUTE_TABLE_ID}" --region "${REGION}" >/dev/null || true
fi
if [ -n "${PUBLIC_SUBNET_ID}" ]; then
  aws ec2 delete-subnet --subnet-id "${PUBLIC_SUBNET_ID}" --region "${REGION}" >/dev/null || true
fi
if [ -n "${PRIVATE_SUBNET_1_ID}" ]; then
  aws ec2 delete-subnet --subnet-id "${PRIVATE_SUBNET_1_ID}" --region "${REGION}" >/dev/null || true
fi
if [ -n "${PRIVATE_SUBNET_2_ID}" ]; then
  aws ec2 delete-subnet --subnet-id "${PRIVATE_SUBNET_2_ID}" --region "${REGION}" >/dev/null || true
fi

# 6. Internet Gateway
if [ -n "${IGW_ID}" ] && [ -n "${VPC_ID}" ]; then
  aws ec2 detach-internet-gateway --internet-gateway-id "${IGW_ID}" --vpc-id "${VPC_ID}" --region "${REGION}" >/dev/null || true
  aws ec2 delete-internet-gateway --internet-gateway-id "${IGW_ID}" --region "${REGION}" >/dev/null || true
fi

# 7. VPC
if [ -n "${VPC_ID}" ]; then
  aws ec2 delete-vpc --vpc-id "${VPC_ID}" --region "${REGION}" >/dev/null || true
fi

# 8. IAM Role & Instance Profile
if [ -n "${INSTANCE_PROFILE_NAME}" ]; then
  echo "🗑️  Cleaning up IAM Instance Profile ${INSTANCE_PROFILE_NAME}..."
  if [ -n "${IAM_ROLE_NAME}" ]; then
    aws iam remove-role-from-instance-profile --instance-profile-name "${INSTANCE_PROFILE_NAME}" --role-name "${IAM_ROLE_NAME}" >/dev/null 2>&1 || true
  fi
  aws iam delete-instance-profile --instance-profile-name "${INSTANCE_PROFILE_NAME}" >/dev/null 2>&1 || true
fi
if [ -n "${IAM_ROLE_NAME}" ]; then
  echo "🗑️  Cleaning up IAM Role ${IAM_ROLE_NAME}..."
  aws iam detach-role-policy --role-name "${IAM_ROLE_NAME}" --policy-arn "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy" >/dev/null 2>&1 || true
  aws iam delete-role --role-name "${IAM_ROLE_NAME}" >/dev/null 2>&1 || true
fi

rm -f "${STATE_FILE}"
echo -e "\n\033[1;32m🎉 All CloudNotes AWS resources have been successfully cleaned up!\033[0m\n"

