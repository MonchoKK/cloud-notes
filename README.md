# ☁️ CloudNotes

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
- [ ] **Phase 4 — CI/CD Pipeline**
  - [ ] GitHub Actions workflow for test & build
  - [ ] Docker image publishing
- [ ] **Phase 5 — Cloud Infrastructure (AWS)**
  - [ ] VPC, subnets, route tables, internet gateway
  - [ ] RDS PostgreSQL instance in private subnet
  - [ ] Compute instance (EC2/ECS) in public subnet with security groups
  - [ ] IAM least-privilege roles
- [ ] **Phase 6 — Monitoring & Observability**
  - [ ] CloudWatch logs & metrics integration
  - [ ] Operational runbook & post-deployment verification

---

## 🛠️ Tech Stack

- **Backend:** Java 21 LTS, Spring Boot 3.3, Spring Data JPA, Spring Boot Actuator
- **Database:** PostgreSQL 16
- **Frontend:** HTML5, CSS3, JavaScript (Fetch API)
- **Containerization:** Docker & Docker Compose
- **Cloud (AWS):** VPC, EC2 / ECS, RDS PostgreSQL, IAM, CloudWatch
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

## 📖 Architecture & Design

- **System Architecture & Cloud Design:** [docs/architecture.md](docs/architecture.md)
- **Containerization & Local Prod Architecture:** [docs/containerization.md](docs/containerization.md)

