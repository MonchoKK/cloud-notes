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
- [ ] **Phase 2 — Local Implementation**
  - [ ] Spring Boot 3 + Java 21 REST API
  - [ ] Spring Data JPA entity model & repository
  - [ ] Database configuration (Local PostgreSQL + Docker Compose + H2 fallback)
  - [ ] Spring Boot Actuator health checks
  - [ ] Modern, responsive web frontend (Vanilla HTML/CSS/JS)
  - [ ] Unit & integration tests
- [ ] **Phase 3 — Containerization**
  - [ ] Multi-stage Dockerfile
  - [ ] Local Docker Compose orchestration
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
- **Docker & Docker Compose** (for local PostgreSQL)

### Running Locally

```bash
# 1. Start the PostgreSQL database
docker compose up -d postgres

# 2. Run the Spring Boot application
./mvnw spring-boot:run
```

Once running:
- **Application Web UI:** [http://localhost:8080](http://localhost:8080)
- **REST API:** [http://localhost:8080/api/notes](http://localhost:8080/api/notes)
- **Health Probes:** [http://localhost:8080/actuator/health](http://localhost:8080/actuator/health)

---

## 📖 Architecture & Design

See [docs/architecture.md](docs/architecture.md) for full architecture diagrams, security boundary details, and the API specification.
