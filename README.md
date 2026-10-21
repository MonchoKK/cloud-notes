# ☁️ CloudNotes

[![CI/CD Pipeline](https://github.com/MonchoKK/cloud-notes/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/MonchoKK/cloud-notes/actions/workflows/ci-cd.yml)
[![Tests](https://img.shields.io/badge/Tests-17%2F17%20Passing-brightgreen.svg)]()
[![Java Version](https://img.shields.io/badge/Java-21%20LTS-orange.svg)](https://openjdk.org/)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.3.4-brightgreen.svg)](https://spring.io/projects/spring-boot)
[![Docker Image](https://img.shields.io/badge/GHCR-ghcr.io%2Fmonchokk%2Fcloud--notes-blue.svg)](https://github.com/MonchoKK/cloud-notes/pkgs/container/cloud-notes)

> A cloud-hosted notes application engineered to demonstrate cloud deployment, infrastructure networking, managed databases, security, CI/CD, and observability. WTC-88EXSGHH

---

## 🎯 Main Goal

The primary goal of **CloudNotes** is to demonstrate hands-on mastery of full-lifecycle cloud application engineering:
- **Application Development:** Build a reliable, clean CRUD application using Java 21 and Spring Boot 3.
- **Managed Cloud Database:** Integrate Amazon RDS PostgreSQL with connection pooling and automated health checks.
- **Secure Networking:** Configure an isolated Virtual Private Cloud (VPC) with public/private subnets and strict Security Groups.
- **Cloud Compute & Deployment:** Package the service with Docker and deploy to AWS (EC2/ECS).
- **CI/CD Automation:** Automate tests, container building, and deployment using GitHub Actions.
- **Observability:** Monitor service health and logs using Spring Boot Actuator and AWS CloudWatch.
- **Infrastructure as Code (IaC):** Provision repeatable cloud infrastructure with Terraform.

---

## 🗺️ Project Progression

- [x] **Phase 1 — Plan & Architecture**
  - [x] Functional requirements & API specification
  - [x] System & cloud networking architecture design ([docs/architecture.md](docs/architecture.md))
  - [x] Repository initialization & project structure
- [x] **Phase 2 — Local Implementation**
  - [x] Spring Boot 3 + Java 21 REST API
  - [x] Spring Data JPA entity model & repository
  - [x] Database configuration (Local PostgreSQL + Docker Compose + H2 fallback)
  - [x] Spring Boot Actuator health checks
  - [x] Modern, responsive web frontend (Vanilla HTML/CSS/JS)
  - [x] Unit & integration tests
- [x] **Phase 3 — Containerization**
  - [x] Multi-stage Dockerfile ([Dockerfile](Dockerfile))
  - [x] Local Docker Compose orchestration ([docker-compose.yml](docker-compose.yml))
  - [x] Local production-like environment ([docker-compose.prod.yml](docker-compose.prod.yml) & [docs/containerization.md](docs/containerization.md))
- [x] **Phase 4 — First Cloud Deployment (AWS)**
  - [x] AWS account/environment & CLI integration ([docs/aws-deployment-guide.md](docs/aws-deployment-guide.md))
  - [x] VPC, public/private subnets, internet gateway, and security groups
  - [x] Amazon RDS PostgreSQL in private subnet (zero public exposure)
  - [x] EC2 compute with automated Docker bootstrapping ([scripts/user-data.sh](scripts/user-data.sh))
  - [x] Deployment automation & teardown scripts ([scripts/deploy-aws.ps1](scripts/deploy-aws.ps1), [scripts/destroy-aws.ps1](scripts/destroy-aws.ps1))
- [x] **Phase 5 — CI/CD Pipeline**
  - [x] GitHub Actions workflow for test & build ([.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml))
  - [x] Multi-stage Docker image build with GitHub Actions layer caching
  - [x] Live container smoke testing with Actuator probes & REST persistence invariants
  - [x] Docker image publishing to GitHub Container Registry (`ghcr.io/monchokk/cloud-notes`)
  - [x] CI/CD architecture & deployment specification ([docs/ci-cd.md](docs/ci-cd.md))
- [x] **Phase 6 — Monitoring & Observability**
  - [x] CloudWatch Unified Agent metrics (RAM & Disk) & log streaming ([scripts/user-data.sh](scripts/user-data.sh))
  - [x] IAM instance profile integration for seamless telemetry ([scripts/deploy-aws.ps1](scripts/deploy-aws.ps1) & [scripts/deploy-aws.sh](scripts/deploy-aws.sh))
  - [x] Spring Boot Actuator probes & production file logging ([src/main/resources/application-prod.yml](src/main/resources/application-prod.yml))
  - [x] Operational runbook, CloudWatch queries & post-deployment verification ([docs/monitoring-observability.md](docs/monitoring-observability.md))
- [ ] **Phase 7 — Infrastructure as Code (IaC)**
  - [ ] Declarative cloud infrastructure provisioning with Terraform

---

## 🛠️ Tech Stack

- **Backend:** Java 21 LTS, Spring Boot 3.3, Spring Data JPA, Spring Boot Actuator
- **Database:** PostgreSQL 16
- **Frontend:** HTML5, CSS3, JavaScript (Fetch API)
- **Containerization:** Docker & Docker Compose
- **Cloud (AWS):** VPC, EC2, RDS PostgreSQL, IAM, Security Groups
- **CI/CD:** GitHub Actions

---

## 🚀 Quick Start (Local Development)

### Prerequisites
- **Java 21** or later
- **Maven 3.9+** (or use `./mvnw`)
- **Docker & Docker Compose**

### Option A: Full Containerized Stack (Recommended)

Run both the Spring Boot app and PostgreSQL in Docker containers with automatic database initialization:

```bash
# Start local development stack
docker compose up -d --build

# View application logs
docker compose logs -f app

# Stop services
docker compose down
```

### Option B: Local Production-Like Environment

Run with production profile, resource limits (1 CPU, 512MB RAM), HikariCP pool, and strict database subnet isolation (zero host port publishing on PostgreSQL):

```bash
# Start production-like stack
docker compose -f docker-compose.prod.yml up -d --build

# View status and resource allocation
docker compose -f docker-compose.prod.yml ps

# Stop and clean up
docker compose -f docker-compose.prod.yml down -v
```

### Option C: Native Java Execution + Dockerized Database

```bash
# 1. Start the PostgreSQL database only
docker compose up -d postgres

# 2. Run the Spring Boot application locally
./mvnw spring-boot:run
```

Once running:
- **Application Web UI:** [http://localhost:8080](http://localhost:8080)
- **REST API:** [http://localhost:8080/api/notes](http://localhost:8080/api/notes)
- **Health Probes:** [http://localhost:8080/actuator/health](http://localhost:8080/actuator/health)

---

## ☁️ AWS Cloud Deployment

Deploy the complete isolated cloud stack (VPC, Private Subnets, RDS PostgreSQL, and EC2 with Docker) onto AWS:

### 1. Configure Credentials
```powershell
aws configure
```

### 2. Run Automated Deployment
```powershell
# Windows PowerShell
.\scripts\deploy-aws.ps1 -Region "eu-west-1"

# Linux / macOS
./scripts/deploy-aws.sh "eu-west-1"
```

### 3. Teardown Resources
```powershell
.\scripts\destroy-aws.ps1
```

See [docs/aws-deployment-guide.md](docs/aws-deployment-guide.md) for full step-by-step console instructions, security group matrices, and architecture details.

---

## 📖 Architecture & Design

- **System Architecture & Cloud Design:** [docs/architecture.md](docs/architecture.md)
- **Containerization & Local Prod Architecture:** [docs/containerization.md](docs/containerization.md)
- **AWS Cloud Deployment Guide:** [docs/aws-deployment-guide.md](docs/aws-deployment-guide.md)
- **CI/CD Pipeline & Registry Publishing Guide:** [docs/ci-cd.md](docs/ci-cd.md)
- **Monitoring, Observability & Operational Runbook:** [docs/monitoring-observability.md](docs/monitoring-observability.md)


