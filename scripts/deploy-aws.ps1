<#
.SYNOPSIS
    Automated AWS Cloud Deployment Script for CloudNotes
.DESCRIPTION
    Provisions full AWS infrastructure matching the project architecture:
    - Custom VPC with Public and Private Subnets across 2 Availability Zones
    - Internet Gateway & Public Route Table
    - Security Groups (App EC2 SG and strict private RDS PostgreSQL SG)
    - Amazon RDS PostgreSQL 16 instance in private subnets
    - Amazon Linux 2023 EC2 instance with Docker runtime & CloudNotes container
.EXAMPLE
    .\scripts\deploy-aws.ps1 -Region "eu-west-1" -DbPassword "MySecurePassword123!"
#>

[CmdletBinding()]
param(
    [string]$Region = "eu-west-1",
    [string]$DbPassword = "",
    [string]$InstanceType = "t3.micro",
    [string]$DbInstanceClass = "db.t4g.micro",
    [string]$KeyName = ""
)

$ErrorActionPreference = "Stop"

# Locate AWS CLI binary
$awsCmd = if (Get-Command "aws" -ErrorAction SilentlyContinue) { "aws" }
          elseif (Test-Path "C:\Program Files\Amazon\AWSCLIV2\aws.exe") { "C:\Program Files\Amazon\AWSCLIV2\aws.exe" }
          else { throw "AWS CLI is not installed or not in PATH. Please install AWS CLI v2." }

Write-Host "`n☁️  CloudNotes AWS Deployment Automation" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# 1. Verify AWS Identity
Write-Host "🔍 [1/6] Verifying AWS credentials..." -ForegroundColor Yellow
try {
    $identityJson = & $awsCmd sts get-caller-identity --output json | ConvertFrom-Json
    Write-Host "✅ Authenticated as Account: $($identityJson.Account) (ARN: $($identityJson.Arn))" -ForegroundColor Green
    Write-Host "📍 Target Region: $Region" -ForegroundColor Green
} catch {
    Write-Host "❌ Unable to authenticate with AWS." -ForegroundColor Red
    Write-Host "`nPlease configure credentials by running:" -ForegroundColor Yellow
    Write-Host "   aws configure" -ForegroundColor White
    Write-Host "Or set environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_DEFAULT_REGION`n"
    exit 1
}

# 2. Database Password Validation / Generation
if ([string]::IsNullOrWhiteSpace($DbPassword)) {
    $DbPassword = "CloudNotes" + (-join ((65..90) + (97..122) + (48..57) | Get-Random -Count 12 | ForEach-Object {[char]$_})) + "!"
    Write-Host "🔑 Generated secure database password: $DbPassword" -ForegroundColor Magenta
}

$stateFile = Join-Path $PSScriptRoot "deployment-state.json"
$state = @{
    Region = $Region
    DbPassword = $DbPassword
    CreatedAt = (Get-Date).ToString("o")
}

# 3. Create VPC & Networking
Write-Host "`n🌐 [2/6] Provisioning VPC and Networking..." -ForegroundColor Yellow

$vpcId = (& $awsCmd ec2 create-vpc --cidr-block "10.0.0.0/16" --region $Region --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=cloudnotes-vpc}]" --query "Vpc.VpcId" --output text).Trim()
Write-Host "  • Created VPC: $vpcId" -ForegroundColor Gray
$state.VpcId = $vpcId

& $awsCmd ec2 modify-vpc-attribute --vpc-id $vpcId --enable-dns-hostnames "{\"Value\":true}" --region $Region
& $awsCmd ec2 modify-vpc-attribute --vpc-id $vpcId --enable-dns-support "{\"Value\":true}" --region $Region

# Internet Gateway
$igwId = (& $awsCmd ec2 create-internet-gateway --region $Region --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=cloudnotes-igw}]" --query "InternetGateway.InternetGatewayId" --output text).Trim()
& $awsCmd ec2 attach-internet-gateway --vpc-id $vpcId --internet-gateway-id $igwId --region $Region
Write-Host "  • Attached Internet Gateway: $igwId" -ForegroundColor Gray
$state.IgwId = $igwId

# Availability Zones
$azs = (& $awsCmd ec2 describe-availability-zones --region $Region --query "AvailabilityZones[?State=='available'].ZoneName" --output text).Split("`t", [System.StringSplitOptions]::RemoveEmptyEntries)
if ($azs.Count -lt 2) { throw "Selected region $Region must have at least 2 available AZs for RDS Subnet Group." }
$azA = $azs[0].Trim()
$azB = $azs[1].Trim()

# Public Subnet (AZ A)
$publicSubnetId = (& $awsCmd ec2 create-subnet --vpc-id $vpcId --cidr-block "10.0.1.0/24" --availability-zone $azA --region $Region --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=cloudnotes-public-subnet}]" --query "Subnet.SubnetId" --output text).Trim()
& $awsCmd ec2 modify-subnet-attribute --subnet-id $publicSubnetId --map-public-ip-on-launch --region $Region
Write-Host "  • Created Public Subnet: $publicSubnetId ($azA)" -ForegroundColor Gray
$state.PublicSubnetId = $publicSubnetId

# Private Subnet 1 (AZ A)
$privateSubnet1Id = (& $awsCmd ec2 create-subnet --vpc-id $vpcId --cidr-block "10.0.2.0/24" --availability-zone $azA --region $Region --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=cloudnotes-private-subnet-1}]" --query "Subnet.SubnetId" --output text).Trim()
Write-Host "  • Created Private Subnet 1: $privateSubnet1Id ($azA)" -ForegroundColor Gray
$state.PrivateSubnet1Id = $privateSubnet1Id

# Private Subnet 2 (AZ B)
$privateSubnet2Id = (& $awsCmd ec2 create-subnet --vpc-id $vpcId --cidr-block "10.0.3.0/24" --availability-zone $azB --region $Region --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=cloudnotes-private-subnet-2}]" --query "Subnet.SubnetId" --output text).Trim()
Write-Host "  • Created Private Subnet 2: $privateSubnet2Id ($azB)" -ForegroundColor Gray
$state.PrivateSubnet2Id = $privateSubnet2Id

# Route Table for Public Subnet
$routeTableId = (& $awsCmd ec2 create-route-table --vpc-id $vpcId --region $Region --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=cloudnotes-public-rt}]" --query "RouteTable.RouteTableId" --output text).Trim()
& $awsCmd ec2 create-route --route-table-id $routeTableId --destination-cidr-block "0.0.0.0/0" --gateway-id $igwId --region $Region | Out-Null
& $awsCmd ec2 associate-route-table --route-table-id $routeTableId --subnet-id $publicSubnetId --region $Region | Out-Null
Write-Host "  • Associated Public Route Table: $routeTableId" -ForegroundColor Gray
$state.RouteTableId = $routeTableId

# 4. Security Groups
Write-Host "`n🛡️  [3/6] Configuring Security Groups..." -ForegroundColor Yellow

# EC2 App Security Group
$appSgId = (& $awsCmd ec2 create-security-group --group-name "cloudnotes-app-sg" --description "Security group for CloudNotes EC2 application instance" --vpc-id $vpcId --region $Region --query "GroupId" --output text).Trim()
& $awsCmd ec2 create-tags --resources $appSgId --tags "Key=Name,Value=cloudnotes-app-sg" --region $Region
& $awsCmd ec2 authorize-security-group-ingress --group-id $appSgId --protocol tcp --port 80 --cidr "0.0.0.0/0" --region $Region
& $awsCmd ec2 authorize-security-group-ingress --group-id $appSgId --protocol tcp --port 8080 --cidr "0.0.0.0/0" --region $Region
& $awsCmd ec2 authorize-security-group-ingress --group-id $appSgId --protocol tcp --port 22 --cidr "0.0.0.0/0" --region $Region
Write-Host "  • Created App SG: $appSgId (Inbound ports 80, 8080, 22)" -ForegroundColor Gray
$state.AppSgId = $appSgId

# RDS Database Security Group
$dbSgId = (& $awsCmd ec2 create-security-group --group-name "cloudnotes-db-sg" --description "Security group for CloudNotes RDS PostgreSQL" --vpc-id $vpcId --region $Region --query "GroupId" --output text).Trim()
& $awsCmd ec2 create-tags --resources $dbSgId --tags "Key=Name,Value=cloudnotes-db-sg" --region $Region
& $awsCmd ec2 authorize-security-group-ingress --group-id $dbSgId --protocol tcp --port 5432 --source-group $appSgId --region $Region
Write-Host "  • Created RDS SG: $dbSgId (Inbound 5432 restricted strictly to $appSgId)" -ForegroundColor Gray
$state.DbSgId = $dbSgId

# 5. Provision RDS PostgreSQL Database
Write-Host "`n🗄️  [4/6] Provisioning Amazon RDS PostgreSQL Database in Private Subnets..." -ForegroundColor Yellow

$dbSubnetGroupName = "cloudnotes-db-subnet-group"
& $awsCmd rds create-db-subnet-group `
    --db-subnet-group-name $dbSubnetGroupName `
    --db-subnet-group-description "CloudNotes private DB Subnet Group" `
    --subnet-ids $privateSubnet1Id $privateSubnet2Id `
    --region $Region | Out-Null
Write-Host "  • Created DB Subnet Group: $dbSubnetGroupName" -ForegroundColor Gray
$state.DbSubnetGroupName = $dbSubnetGroupName

$dbInstanceId = "cloudnotes-postgres-db"
$state.DbInstanceId = $dbInstanceId
Write-Host "  • Requesting RDS PostgreSQL 16 instance ($DbInstanceClass)..." -ForegroundColor Gray

& $awsCmd rds create-db-instance `
    --db-instance-identifier $dbInstanceId `
    --db-instance-class $DbInstanceClass `
    --engine postgres `
    --engine-version "16.3" `
    --master-username "cloudnotes" `
    --master-user-password $DbPassword `
    --allocated-storage 20 `
    --storage-type gp3 `
    --db-name "cloudnotes" `
    --db-subnet-group-name $dbSubnetGroupName `
    --vpc-security-group-ids $dbSgId `
    --no-publicly-accessible `
    --backup-retention-period 1 `
    --tags "Key=Name,Value=cloudnotes-postgres" `
    --region $Region | Out-Null

Write-Host "  • Waiting for RDS instance to initialize (this typically takes 3-6 minutes)..." -ForegroundColor Yellow
$dbEndpoint = ""
while (-not $dbEndpoint) {
    Start-Sleep -Seconds 15
    $dbStatus = (& $awsCmd rds describe-db-instances --db-instance-identifier $dbInstanceId --region $Region --query "DBInstances[0].DBInstanceStatus" --output text).Trim()
    Write-Host "    Current DB Status: $dbStatus..." -ForegroundColor Gray
    if ($dbStatus -eq "available") {
        $dbEndpoint = (& $awsCmd rds describe-db-instances --db-instance-identifier $dbInstanceId --region $Region --query "DBInstances[0].Endpoint.Address" --output text).Trim()
    }
}
Write-Host "✅ RDS PostgreSQL is available at endpoint: $dbEndpoint" -ForegroundColor Green
$state.DbEndpoint = $dbEndpoint

# 6. Provision EC2 Compute & Deploy CloudNotes
Write-Host "`n🚀 [5/6] Launching EC2 Instance & Deploying CloudNotes..." -ForegroundColor Yellow

# Find latest Amazon Linux 2023 AMI
$amiId = (& $awsCmd ec2 describe-images --owners amazon --filters "Name=name,Values=al2023-ami-2023.*-x86_64" "Name=state,Values=available" --query "sort_by(Images, &CreationDate)[-1].ImageId" --region $Region --output text).Trim()
Write-Host "  • Using AMI: $amiId (Amazon Linux 2023)" -ForegroundColor Gray
$state.AmiId = $amiId

# Generate customized user-data script
$userDataTemplate = Get-Content (Join-Path $PSScriptRoot "user-data.sh") -Raw
$customUserData = $userDataTemplate -replace 'DB_HOST="\$\{DB_HOST:-postgres\}"', "DB_HOST=`"$dbEndpoint`""
$customUserData = $customUserData -replace 'DB_PASSWORD="\$\{DB_PASSWORD:-cloudnotes_secret\}"', "DB_PASSWORD=`"$DbPassword`""
$userDataBytes = [System.Text.Encoding]::UTF8.GetBytes($customUserData)
$userDataBase64 = [Convert]::ToBase64String($userDataBytes)

$ec2Params = @(
    "ec2", "run-instances",
    "--image-id", $amiId,
    "--instance-type", $InstanceType,
    "--subnet-id", $publicSubnetId,
    "--security-group-ids", $appSgId,
    "--user-data", $userDataBase64,
    "--tag-specifications", "ResourceType=instance,Tags=[{Key=Name,Value=cloudnotes-app-server}]",
    "--region", $Region,
    "--output", "json"
)
if ($KeyName) { $ec2Params += @("--key-name", $KeyName) }

$ec2Json = & $awsCmd @ec2Params | ConvertFrom-Json
$instanceId = $ec2Json.Instances[0].InstanceId
$state.InstanceId = $instanceId
Write-Host "  • Launched EC2 Instance: $instanceId" -ForegroundColor Gray

Write-Host "  • Waiting for EC2 instance to enter 'running' state..." -ForegroundColor Yellow
& $awsCmd ec2 wait instance-running --instance-ids $instanceId --region $Region

$publicIp = (& $awsCmd ec2 describe-instances --instance-ids $instanceId --region $Region --query "Reservations[0].Instances[0].PublicIpAddress" --output text).Trim()
$publicDns = (& $awsCmd ec2 describe-instances --instance-ids $instanceId --region $Region --query "Reservations[0].Instances[0].PublicDnsName" --output text).Trim()
$state.PublicIp = $publicIp
$state.PublicDns = $publicDns

# Save state file for teardown
$state | ConvertTo-Json -Depth 5 | Set-Content $stateFile -Encoding UTF8

# 7. Deployment Complete Summary
Write-Host "`n🎉 [6/6] CloudNotes Cloud Deployment Complete!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host "🌐 Application Web UI:     http://$publicIp" -ForegroundColor Cyan
Write-Host "📱 Application Direct:     http://${publicIp}:8080" -ForegroundColor Cyan
Write-Host "🩺 Healthcheck Probe:      http://${publicIp}:8080/actuator/health" -ForegroundColor Cyan
Write-Host "🗄️  RDS Endpoint (Private): $dbEndpoint:5432" -ForegroundColor Gray
Write-Host "🔑 Database Master Pass:   $DbPassword" -ForegroundColor Gray
Write-Host "💾 Deployment State:       $stateFile" -ForegroundColor Gray
Write-Host "`nNote: Allow ~1-2 minutes for Docker container build and startup on the instance.`n" -ForegroundColor Yellow
