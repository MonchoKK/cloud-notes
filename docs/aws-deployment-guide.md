# ☁️ CloudNotes AWS Deployment Guide

## 1. Overview & Cloud Architecture

This guide details the deployment of **CloudNotes** onto Amazon Web Services (AWS) conforming to the target cloud architecture specified in [docs/architecture.md](docs/architecture.md).

```mermaid
graph TB
    User([User Browser])

    subgraph AWS ["AWS Cloud (eu-west-1 / af-south-1)"]
        subgraph VPC ["Custom VPC: 10.0.0.0/16"]
            
            subgraph PublicSubnet ["Public Subnet: 10.0.1.0/24 (AZ A)"]
                IGW[Internet Gateway]
                EC2["EC2 Instance (t3.micro / AL2023)<br/>Docker Container: cloudnotes-app<br/>Ports: 80, 8080"]
            end

            subgraph PrivateSubnets ["Private Subnets: 10.0.2.0/24 & 10.0.3.0/24 (AZ A & B)"]
                RDS[("Amazon RDS PostgreSQL 16<br/>db.t4g.micro / db.t3.micro<br/>Port: 5432 (Internal Only)")]
            end

            SG_App["Security Group: cloudnotes-app-sg<br/>Inbound: 80, 8080, 22 from 0.0.0.0/0"]
            SG_DB["Security Group: cloudnotes-db-sg<br/>Inbound: 5432 ONLY from cloudnotes-app-sg"]
        end
    end

    User -->|HTTP :80| IGW
    IGW --> EC2
    EC2 -->|PostgreSQL :5432| RDS
```

### Architectural Principles:
1. **Network Defense-in-Depth**:
   - The PostgreSQL database is placed in **private subnets** with **zero public IP** and **no direct internet gateway routing**.
   - Database security group (`cloudnotes-db-sg`) permits inbound traffic on port `5432` strictly from the application security group (`cloudnotes-app-sg`).
2. **Automated Bootstrapping**:
   - The EC2 instance automatically installs Docker, clones the repository, configures production environment variables with the private RDS endpoint, builds the image, and launches the application container on boot via EC2 User-Data.

---

## 2. Step 1: AWS Account & IAM Credentials Setup

### 2.1 Obtain IAM User Access Keys
1. Log in to the [AWS Management Console](https://console.aws.amazon.com/).
2. In the top search bar, navigate to **IAM (Identity and Access Management)**.
3. In the left navigation menu, click **Users** > **Create user**.
4. Set User name: `cloudnotes-deployer` and click **Next**.
5. Under **Set permissions**, choose **Attach policies directly**.
6. Attach the following policies:
   - `AmazonEC2FullAccess`
   - `AmazonRDSFullAccess`
   - `AmazonVPCFullAccess`
   *(Or `AdministratorAccess` for sandbox environments).*
7. Click **Next** > **Create user**.
8. Click on your newly created user (`cloudnotes-deployer`).
9. Go to the **Security credentials** tab.
10. Under **Access keys**, click **Create access key**.
11. Select **Command Line Interface (CLI)**, check the confirmation checkbox, and click **Next**.
12. Click **Create access key**.
13. Copy or download both:
    - **Access Key ID** (e.g. `AKIAIOSFODNN7EXAMPLE`)
    - **Secret Access Key** (e.g. `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`)

### 2.2 Configure Local AWS CLI
Open PowerShell and run:

```powershell
aws configure
```

Enter your details when prompted:
```text
AWS Access Key ID [None]: <YOUR_ACCESS_KEY_ID>
AWS Secret Access Key [None]: <YOUR_SECRET_ACCESS_KEY>
Default region name [None]: eu-west-1
Default output format [None]: json
```

Verify authentication:
```powershell
aws sts get-caller-identity
```

---

## 3. Step 2: Automated Deployment (Recommended)

An automated deployment script is provided that provisions all networking, RDS, and EC2 resources in order:

### 3.1 Run Deployment (Windows PowerShell)

```powershell
# Deploy into default region (eu-west-1) with auto-generated secure password
.\scripts\deploy-aws.ps1

# Or specify custom parameters:
.\scripts\deploy-aws.ps1 -Region "eu-west-1" -DbPassword "MyCustomPassword123!" -InstanceType "t3.micro"
```

### 3.2 Run Deployment (Linux / macOS Bash)

```bash
chmod +x scripts/deploy-aws.sh
./scripts/deploy-aws.sh "eu-west-1" "MyCustomPassword123!"
```

### What the script executes automatically:
1. Creates a custom VPC (`10.0.0.0/16`) with DNS support and DNS hostnames enabled.
2. Creates and attaches an Internet Gateway (`cloudnotes-igw`).
3. Provisions a public subnet (`10.0.1.0/24`) and two private subnets (`10.0.2.0/24`, `10.0.3.0/24`) across two Availability Zones.
4. Associates the public subnet with an internet-routed Route Table (`0.0.0.0/0 -> IGW`).
5. Configures security groups:
   - `cloudnotes-app-sg`: Inbound TCP ports `80`, `8080`, and `22`.
   - `cloudnotes-db-sg`: Inbound TCP port `5432` referenced strictly from `cloudnotes-app-sg`.
6. Creates a DB Subnet Group across the private subnets.
7. Launches an Amazon RDS PostgreSQL 16 instance (`cloudnotes-postgres-db`, `db.t4g.micro`, 20GB gp3) with public accessibility disabled.
8. Polls until RDS status reaches `available` and extracts the private database endpoint.
9. Injects the database endpoint and credentials into `scripts/user-data.sh`.
10. Launches an Amazon Linux 2023 EC2 instance (`t3.micro`) into the public subnet.
11. Generates `scripts/deployment-state.json` containing resource IDs for subsequent verification and teardown.

---

## 4. Step 3: Manual AWS Management Console Walkthrough

If you prefer provisioning directly through the AWS Web Console:

### 4.1 Networking (VPC & Subnets)
1. Go to **VPC Console** > **Create VPC**.
2. Select **VPC and more**:
   - Name tag: `cloudnotes`
   - IPv4 CIDR: `10.0.0.0/16`
   - Number of Availability Zones: `2`
   - Number of public subnets: `1`
   - Number of private subnets: `2`
   - NAT gateways: `None`
   - VPC endpoints: `None`
3. Click **Create VPC**.

### 4.2 Security Groups
1. In the VPC Console, select **Security groups** > **Create security group**:
   - **App SG**:
     - Name: `cloudnotes-app-sg`, VPC: `cloudnotes-vpc`
     - Inbound rules:
       - Type `HTTP`, Port `80`, Source `0.0.0.0/0`
       - Type `Custom TCP`, Port `8080`, Source `0.0.0.0/0`
       - Type `SSH`, Port `22`, Source `My IP`
   - **Database SG**:
     - Name: `cloudnotes-db-sg`, VPC: `cloudnotes-vpc`
     - Inbound rules:
       - Type `PostgreSQL`, Port `5432`, Source: Choose `cloudnotes-app-sg`
2. Save both security groups.

### 4.3 Database (Amazon RDS PostgreSQL)
1. Go to **RDS Console** > **Subnet groups** > **Create DB subnet group**:
   - Name: `cloudnotes-db-subnets`, VPC: `cloudnotes-vpc`
   - Add the two private subnets created earlier.
2. Go to **Databases** > **Create database**:
   - Engine: **PostgreSQL** (version `16.x`)
   - Template: **Free tier**
   - DB instance identifier: `cloudnotes-postgres-db`
   - Master username: `cloudnotes`
   - Master password: Enter a secure password
   - DB instance class: `db.t4g.micro` or `db.t3.micro`
   - Storage: `20 GiB`, gp3
   - VPC: `cloudnotes-vpc`
   - DB Subnet group: `cloudnotes-db-subnets`
   - Public access: **No**
   - VPC security group: Select `cloudnotes-db-sg` (remove `default`)
   - Initial database name: `cloudnotes`
3. Click **Create database** (takes 3-5 minutes). Once available, copy the **Endpoint**.

### 4.4 Compute (Amazon EC2)
1. Go to **EC2 Console** > **Launch instance**:
   - Name: `cloudnotes-app-server`
   - AMI: **Amazon Linux 2023 AMI**
   - Instance type: `t3.micro`
   - Key pair: Select your key pair or proceed without key pair
   - Network settings:
     - VPC: `cloudnotes-vpc`
     - Subnet: `cloudnotes-public-subnet`
     - Auto-assign public IP: **Enable**
     - Security group: Select `cloudnotes-app-sg`
   - Expand **Advanced details** > **User data**:
     - Paste the contents of [scripts/user-data.sh](scripts/user-data.sh)
     - Replace `DB_HOST="postgres"` with your RDS Endpoint
     - Replace `DB_PASSWORD="cloudnotes_secret"` with your RDS Master Password
2. Click **Launch instance**.

---

## 5. Step 4: Verification & Smoke Testing

After launching, wait ~2 minutes for Docker to build and run on the EC2 instance:

1. **Verify Health Probes**:
   ```bash
   curl -i http://<EC2-PUBLIC-IP>:8080/actuator/health
   ```
   Expected response:
   ```json
   {
     "status": "UP",
     "components": {
       "db": {
         "status": "UP",
         "details": {
           "database": "PostgreSQL"
         }
       },
       "diskSpace": {
         "status": "UP"
       },
       "ping": {
         "status": "UP"
       }
     }
   }
   ```

2. **Access Web Application**:
   Open your browser to:
   - `http://<EC2-PUBLIC-IP>` (or `http://<EC2-PUBLIC-IP>:8080`)
   - Create, edit, and delete notes. The data will be safely persisted in Amazon RDS PostgreSQL.

---

## 6. Step 5: Clean-up & Cost Management

To avoid ongoing AWS charges after testing:

### Automated Teardown:
```powershell
.\scripts\destroy-aws.ps1
```

Or on Linux/macOS:
```bash
./scripts/destroy-aws.sh
```

All AWS resources (EC2, RDS, Security Groups, Subnets, Internet Gateway, and VPC) will be cleanly terminated in the proper dependency order.
