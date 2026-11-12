# devops-todo-app

**English** | [Русский](README.ru.md)

![CI/CD](https://github.com/madimuk/devops-todo-app/actions/workflows/ci-cd.yml/badge.svg)

An end-to-end DevOps project: taking a simple Flask application from `git push` to a running server on AWS, with containerization, Infrastructure as Code, CI/CD, monitoring and Kubernetes.

The application itself is intentionally simple (a todo list on Flask + PostgreSQL). The focus of the project is not the code but **how the code is built, delivered and observed in production**.

## Architecture

```mermaid
flowchart LR
    dev[Developer] -->|git push| gh[GitHub repo]
    gh --> ci[GitHub Actions<br/>lint → build]
    ci -->|docker push| reg[(ghcr.io<br/>image :latest + :sha)]

    subgraph AWS["AWS · eu-central-1 (provisioned by Terraform)"]
        direction TB
        subgraph VPC["VPC 10.0.0.0/16 · public subnet · IGW · Security Group"]
            ec2[EC2 Ubuntu 24.04<br/>user_data: Docker + Compose]
            ec2 --- app[Flask app :5000]
            app --- db[(PostgreSQL 16)]
        end
    end

    reg -->|docker pull| ec2
    prom[Prometheus] -->|scrape /metrics| app
    graf[Grafana] --> prom
    user[User] -->|HTTP :5000| app
```

## Tech stack

| Layer | Technology | What was done |
|---|---|---|
| Application | Python, Flask, PostgreSQL | Todo CRUD, configuration via environment variables, DB connection retry |
| Containers | Docker, Docker Compose | Image based on `python:3.12-slim` with a cached dependency layer; DB healthcheck and `depends_on: service_healthy` |
| IaC | Terraform | VPC, subnet, IGW, route table, Security Group, SSH key pair, EC2; Ubuntu AMI resolved via a `data` source instead of a hardcoded ID |
| Deployment | EC2 `user_data` | On first boot the instance installs Docker, pulls the image from ghcr.io and starts the app with PostgreSQL — `terraform apply` gives a working app with no manual steps |
| IaC test environment | LocalStack | Terraform debugged locally at zero AWS cost |
| CI/CD | GitHub Actions | `flake8` → image build → push to ghcr.io from `main` only; pull requests are built but not published |
| Registry | GitHub Container Registry | `latest` and short commit SHA tags, so any version can be rolled back to |
| Monitoring | Prometheus, Grafana | `/metrics` endpoint via `prometheus-flask-exporter`, Prometheus + Grafana in Docker Compose, dashboard for requests and errors |
| Orchestration | Kubernetes (minikube), NGINX Ingress | Namespace, Secret, PostgreSQL with a PVC, app Deployment with 2 replicas and readiness/liveness probes on `/health`, Ingress |

## CI/CD pipeline

```mermaid
flowchart LR
    push[push / PR to main] --> lint[lint<br/>flake8]
    lint --> build[build<br/>Docker Buildx + GHA cache]
    build -->|push to main only| publish[push to ghcr.io<br/>:latest, :sha-xxxxxxx]
```

- `lint` and `build` run sequentially (`needs: lint`), so broken code never becomes an image.
- For pull requests the image is built but not published: the Dockerfile is validated without cluttering the registry.
- Authentication to ghcr.io uses the built-in `GITHUB_TOKEN` with least-privilege permissions (`packages: write`).
- Docker layer cache is stored in the GitHub Actions cache to speed up rebuilds.

## Repository layout

```
.
├── app.py                      # Flask application
├── templates/                  # HTML templates
├── requirements.txt
├── Dockerfile
├── docker-compose.yml          # app + PostgreSQL
├── .github/workflows/ci-cd.yml # CI/CD pipeline
├── terraform/                  # AWS infrastructure (+ LocalStack guide)
├── docker-compose.ghcr-test.yml # run the published image from ghcr.io locally
├── monitoring/prometheus.yml   # Prometheus scrape config
└── k8s/                        # Kubernetes manifests (namespace → secret → postgres → app → ingress)
```

## Quick start

### Locally with Docker Compose

```bash
git clone https://github.com/madimuk/devops-todo-app.git
cd devops-todo-app
docker compose up -d
# app:        http://localhost:5000
# metrics:    http://localhost:5000/metrics
# Prometheus: http://localhost:9090
# Grafana:    http://localhost:3000 (admin / admin)
```

### Prebuilt image from the registry

```bash
docker pull ghcr.io/madimuk/devops-todo-app:latest
```

### AWS infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
# outputs: instance_public_ip and ssh_command
# the app is available at http://<instance_public_ip>:5000 a few minutes after boot
# always clean up after experiments:
terraform destroy
```

### Kubernetes (minikube)

```bash
minikube start
minikube addons enable ingress
kubectl apply -f k8s/
kubectl get pods -n devops-todo-app
echo "$(minikube ip) todo-app.local" | sudo tee -a /etc/hosts
# app: http://todo-app.local
```

A detailed Terraform guide, including running against LocalStack, is in [terraform/README.md](terraform/README.md) (in Russian).

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `DB_HOST` | `localhost` (`db` in Docker) | Database host |
| `DB_PORT` | `5432` | Database port |
| `DB_NAME` | `tododb` | Database name |
| `DB_USER` | `postgres` | Database user |
| `DB_PASSWORD` | `postgres` | Database password (local development only) |

## Problems solved

Real issues hit during the build and how they were fixed.

**Prometheus: targets in DOWN state**
- *Symptom:* Prometheus could not scrape the application metrics.
- *Cause:* the target in `prometheus.yml` pointed to `localhost`. Inside a container, `localhost` is the Prometheus container itself, not the application.
- *Fix:* use the Docker Compose service name (`app:5000`); containers on the same network resolve each other through Docker's built-in DNS.

**prometheus-flask-exporter failing in debug mode**
- *Symptom:* metric registration errors.
- *Cause:* the Flask debug reloader runs two processes (a file watcher and the application itself), so the exporter was initialized twice.
- *Fix:* disable the reloader (debug mode is never used in production anyway).

**Terraform: AMI lookup on LocalStack**
- *Cause:* LocalStack does not emulate all public AMIs, so the image lookup behaved differently than on real AWS.
- *Fix:* use LocalStack for syntax and logic, verify the AMI lookup against real AWS.

**`.terraform/` accidentally committed to git**
- *Fix:* `git rm -r --cached`, plus `.gitignore` rules (`**/.terraform/*`, `*.tfstate`).

## AWS cost control

- `t2.micro` instance, no NAT Gateway or ALB.
- Terraform syntax is debugged on LocalStack, Kubernetes runs on minikube instead of EKS.
- `terraform destroy` after every experiment; AWS Budgets alerts are enabled.

## Roadmap

- [x] Flask + PostgreSQL
- [x] Docker and Docker Compose
- [x] Terraform: LocalStack → AWS EC2 (eu-central-1)
- [x] CI/CD: GitHub Actions → ghcr.io
- [x] Monitoring: Prometheus + Grafana (local)
- [x] Kubernetes on minikube + NGINX Ingress
- [ ] Terraform remote state: S3 + state locking
- [ ] OIDC for GitHub Actions → AWS instead of long-lived keys
- [ ] Ansible: EC2 configuration and app deployment
- [ ] Trivy: image scanning in the pipeline
- [ ] SSH restricted to my IP, access via SSM Session Manager
- [ ] Helm chart for the application
