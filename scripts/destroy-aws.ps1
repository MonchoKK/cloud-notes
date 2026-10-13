<#
.SYNOPSIS
    Automated AWS Cloud Teardown Script for CloudNotes
.DESCRIPTION
    Tears down all resources created by deploy-aws.ps1 using deployment-state.json:
    - Terminates EC2 instance
    - Deletes RDS instance (skipping final snapshot) and DB subnet group
    - Deletes Security Groups
    - Detaches and deletes Internet Gateway, Subnets, Route Tables, and VPC
#>

[CmdletBinding()]
param(
    [string]$StatePath = ""
)

$ErrorActionPreference = "Continue"

# Locate AWS CLI binary
$awsCmd = if (Get-Command "aws" -ErrorAction SilentlyContinue) { "aws" }
          elseif (Test-Path "C:\Program Files\Amazon\AWSCLIV2\aws.exe") { "C:\Program Files\Amazon\AWSCLIV2\aws.exe" }
          else { throw "AWS CLI is not installed or not in PATH." }

if (-not $StatePath) {
    $StatePath = Join-Path $PSScriptRoot "deployment-state.json"
}

if (-not (Test-Path $StatePath)) {
    Write-Host "❌ Deployment state file not found at: $StatePath" -ForegroundColor Red
    Write-Host "Nothing to tear down."
    exit 1
}

$state = Get-Content $StatePath | ConvertFrom-Json
$Region = $state.Region

Write-Host "`n⚠️  CloudNotes AWS Resource Teardown" -ForegroundColor Red
Write-Host "====================================`n" -ForegroundColor Red
Write-Host "Target Region: $Region" -ForegroundColor Yellow

# 1. Terminate EC2
if ($state.InstanceId) {
    Write-Host "🗑️  Terminating EC2 Instance $($state.InstanceId)..." -ForegroundColor Yellow
    & $awsCmd ec2 terminate-instances --instance-ids $state.InstanceId --region $Region | Out-Null
    Write-Host "   Waiting for instance to terminate..." -ForegroundColor Gray
    & $awsCmd ec2 wait instance-terminated --instance-ids $state.InstanceId --region $Region
    Write-Host "✅ EC2 Instance terminated." -ForegroundColor Green
}

# 2. Delete RDS
if ($state.DbInstanceId) {
    Write-Host "🗑️  Deleting RDS Instance $($state.DbInstanceId)..." -ForegroundColor Yellow
    & $awsCmd rds delete-db-instance --db-instance-identifier $state.DbInstanceId --skip-final-snapshot --delete-automated-backups --region $Region | Out-Null
    Write-Host "   Waiting for RDS instance deletion (takes 2-4 minutes)..." -ForegroundColor Gray
    & $awsCmd rds wait db-instance-deleted --db-instance-identifier $state.DbInstanceId --region $Region
    Write-Host "✅ RDS Instance deleted." -ForegroundColor Green
}

# 3. Delete DB Subnet Group
if ($state.DbSubnetGroupName) {
    Write-Host "🗑️  Deleting DB Subnet Group $($state.DbSubnetGroupName)..." -ForegroundColor Yellow
    & $awsCmd rds delete-db-subnet-group --db-subnet-group-name $state.DbSubnetGroupName --region $Region | Out-Null
    Write-Host "✅ DB Subnet Group deleted." -ForegroundColor Green
}

# 4. Delete Security Groups
Start-Sleep -Seconds 10
if ($state.DbSgId) {
    Write-Host "🗑️  Deleting RDS Security Group $($state.DbSgId)..." -ForegroundColor Yellow
    & $awsCmd ec2 delete-security-group --group-id $state.DbSgId --region $Region | Out-Null
}
if ($state.AppSgId) {
    Write-Host "🗑️  Deleting App Security Group $($state.AppSgId)..." -ForegroundColor Yellow
    & $awsCmd ec2 delete-security-group --group-id $state.AppSgId --region $Region | Out-Null
}

# 5. Delete Subnets & Route Table
if ($state.RouteTableId) {
    Write-Host "🗑️  Deleting Public Route Table $($state.RouteTableId)..." -ForegroundColor Yellow
    & $awsCmd ec2 delete-route-table --route-table-id $state.RouteTableId --region $Region | Out-Null
}
if ($state.PublicSubnetId) {
    Write-Host "🗑️  Deleting Public Subnet $($state.PublicSubnetId)..." -ForegroundColor Yellow
    & $awsCmd ec2 delete-subnet --subnet-id $state.PublicSubnetId --region $Region | Out-Null
}
if ($state.PrivateSubnet1Id) {
    Write-Host "🗑️  Deleting Private Subnet 1 $($state.PrivateSubnet1Id)..." -ForegroundColor Yellow
    & $awsCmd ec2 delete-subnet --subnet-id $state.PrivateSubnet1Id --region $Region | Out-Null
}
if ($state.PrivateSubnet2Id) {
    Write-Host "🗑️  Deleting Private Subnet 2 $($state.PrivateSubnet2Id)..." -ForegroundColor Yellow
    & $awsCmd ec2 delete-subnet --subnet-id $state.PrivateSubnet2Id --region $Region | Out-Null
}

# 6. Detach & Delete Internet Gateway
if ($state.IgwId -and $state.VpcId) {
    Write-Host "🗑️  Detaching and deleting Internet Gateway $($state.IgwId)..." -ForegroundColor Yellow
    & $awsCmd ec2 detach-internet-gateway --internet-gateway-id $state.IgwId --vpc-id $state.VpcId --region $Region | Out-Null
    & $awsCmd ec2 delete-internet-gateway --internet-gateway-id $state.IgwId --region $Region | Out-Null
}

# 7. Delete VPC
if ($state.VpcId) {
    Write-Host "🗑️  Deleting VPC $($state.VpcId)..." -ForegroundColor Yellow
    & $awsCmd ec2 delete-vpc --vpc-id $state.VpcId --region $Region | Out-Null
    Write-Host "✅ VPC deleted." -ForegroundColor Green
}

Remove-Item $StatePath -Force -ErrorAction SilentlyContinue
Write-Host "`n🎉 All CloudNotes AWS resources have been successfully cleaned up!`n" -ForegroundColor Green
