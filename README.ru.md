# devops-todo-app

[English](README.md) | **Русский**

![CI/CD](https://github.com/madimuk/devops-todo-app/actions/workflows/ci-cd.yml/badge.svg)

End-to-end DevOps-проект: путь простого Flask-приложения от `git push` до работающего сервера в AWS — контейнеризация, Infrastructure as Code, CI/CD, мониторинг и Kubernetes.

Само приложение намеренно простое (todo-список на Flask + PostgreSQL): фокус проекта не на коде, а на том, **как код собирается, доставляется и наблюдается в продакшене**.

## Архитектура

```mermaid
flowchart LR
    dev[Разработчик] -->|git push| gh[GitHub repo]
    gh --> ci[GitHub Actions<br/>lint → build]
    ci -->|docker push| reg[(ghcr.io<br/>образ :latest + :sha)]

    subgraph AWS["AWS · eu-central-1 (создано Terraform)"]
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
    user[Пользователь] -->|HTTP :5000| app
```

## Стек

| Слой | Технология | Что сделано |
|---|---|---|
| Приложение | Python, Flask, PostgreSQL | CRUD todo-списка, конфиг через переменные окружения, retry подключения к БД |
| Контейнеры | Docker, Docker Compose | Образ на `python:3.12-slim` с кэшированием слоя зависимостей; healthcheck БД и `depends_on: service_healthy` |
| IaC | Terraform | Remote state в S3 (версии, шифрование, нативная блокировка через `use_lockfile`); VPC, подсеть, IGW, route table, Security Group, SSH key pair, EC2; AMI Ubuntu ищется через `data` source, без хардкода ID |
| Деплой | EC2 `user_data` | При первом запуске инстанс ставит Docker, скачивает образ из ghcr.io и поднимает приложение с PostgreSQL — после `terraform apply` приложение работает без ручных шагов |
| Тестовая среда IaC | LocalStack | Отладка Terraform локально, без затрат на AWS |
| CI/CD | GitHub Actions | `flake8` → сборка образа → сканирование Trivy → push в ghcr.io только из `main`; для PR — сборка и сканирование без публикации |
| Безопасность | Trivy, Dependabot | Сканирование образа блокирует HIGH/CRITICAL уязвимости, для которых есть исправление; сторонние actions закреплены по SHA коммита; еженедельные PR от Dependabot для actions, pip и базового образа |
| Доступ в облако | GitHub OIDC → AWS STS | `terraform plan` выполняется в CI с временными кредами IAM-роли — никаких AWS-ключей в GitHub; trust policy привязана к этому репозиторию (`main` и pull request) через immutable `sub` claim |
| Registry | GitHub Container Registry | Теги `latest` и короткий SHA коммита — можно откатиться на любую версию |
| Мониторинг | Prometheus, Grafana | Эндпоинт `/metrics` через `prometheus-flask-exporter`, Prometheus + Grafana в Docker Compose, дашборд запросов и ошибок |
| Оркестрация | Kubernetes (minikube), NGINX Ingress | Namespace, Secret, PostgreSQL с PVC, Deployment приложения на 2 реплики с readiness/liveness-пробами на `/health`, Ingress |

## CI/CD pipeline

```mermaid
flowchart LR
    push[push / PR в main] --> lint[lint<br/>flake8]
    lint --> build[build<br/>Docker Buildx + GHA cache]
    build --> scan[Trivy scan<br/>HIGH/CRITICAL = fail]
    scan -->|только push в main| publish[push в ghcr.io<br/>:latest, :sha-xxxxxxx]
    lint --> plan[terraform plan<br/>OIDC → AWS, read-only роль]
```

- `lint` и `build` идут последовательно (`needs: lint`) — сломанный код не превращается в образ.
- Образ сканируется Trivy **до** публикации: уязвимый образ не попадает в registry.
- Для pull request образ собирается, но не публикуется: проверяем Dockerfile, не засоряя registry.
- Авторизация в ghcr.io через встроенный `GITHUB_TOKEN` с минимальными правами (`packages: write`).
- Кэш слоёв Docker хранится в GitHub Actions cache — повторные сборки быстрее.

### Доступ в AWS без ключей через OIDC

Job `terraform-plan` получает доступ к AWS без хранимых секретов: GitHub выдаёт короткоживущий OIDC-токен (`id-token: write`), AWS STS меняет его на временные креды роли `github-actions-devops-todo-plan`.

```
"Arn": "arn:aws:sts::965317436147:assumed-role/github-actions-devops-todo-plan/GitHubActions"
```

- OIDC-провайдер и роль вынесены в отдельный Terraform-стек [`terraform/github-oidc/`](terraform/github-oidc/) со своим ключом state — `terraform destroy` окружения приложения не ломает доступ CI.
- Trust policy проверяет `aud = sts.amazonaws.com` и `sub` только для `main` и pull request этого репозитория.
- Роль только на чтение (`ReadOnlyAccess`) плюс запись только lock-файла state.
- `aws-actions/configure-aws-credentials` и `hashicorp/setup-terraform` закреплены по SHA коммита.

## Структура репозитория

```
.
├── app.py                      # Flask-приложение
├── templates/                  # HTML-шаблоны
├── requirements.txt
├── Dockerfile
├── docker-compose.yml          # app + PostgreSQL
├── .github/workflows/ci-cd.yml # CI/CD pipeline
├── terraform/                  # инфраструктура AWS (+ инструкция для LocalStack)
│   └── github-oidc/            # OIDC-провайдер + IAM-роль для GitHub Actions (отдельный state)
├── docker-compose.ghcr-test.yml # запуск опубликованного образа из ghcr.io локально
├── monitoring/prometheus.yml   # конфиг сбора метрик Prometheus
└── k8s/                        # манифесты Kubernetes (namespace → secret → postgres → app → ingress)
```

## Быстрый старт

### Локально через Docker Compose

```bash
git clone https://github.com/madimuk/devops-todo-app.git
cd devops-todo-app
docker compose up -d
# приложение: http://localhost:5000
# метрики:    http://localhost:5000/metrics
# Prometheus: http://localhost:9090
# Grafana:    http://localhost:3000 (admin / admin)
```

### Готовый образ из registry

```bash
docker pull ghcr.io/madimuk/devops-todo-app:latest
```

### Инфраструктура в AWS

```bash
cd terraform
terraform init
terraform plan
terraform apply
# outputs: instance_public_ip и ssh_command
# приложение откроется на http://<instance_public_ip>:5000 через несколько минут после старта
# после экспериментов — обязательно:
terraform destroy
```

### Kubernetes (minikube)

```bash
minikube start
minikube addons enable ingress
kubectl apply -f k8s/
kubectl get pods -n devops-todo-app
echo "$(minikube ip) todo-app.local" | sudo tee -a /etc/hosts
# приложение: http://todo-app.local
```

Подробная инструкция по Terraform, включая запуск на LocalStack, — в [terraform/README.md](terraform/README.md).

## Переменные окружения

| Переменная | По умолчанию | Описание |
|---|---|---|
| `DB_HOST` | `localhost` (`db` в Docker) | Хост базы данных |
| `DB_PORT` | `5432` | Порт базы данных |
| `DB_NAME` | `tododb` | Имя базы данных |
| `DB_USER` | `postgres` | Пользователь БД |
| `DB_PASSWORD` | `postgres` | Пароль БД (только для локальной разработки) |

## Решённые проблемы

Реальные ошибки, которые возникли в ходе работы, и как они были исправлены.

**Prometheus: targets в статусе DOWN**
- *Симптом:* Prometheus не мог собрать метрики приложения.
- *Причина:* в `prometheus.yml` target был указан как `localhost`. Внутри контейнера `localhost` — это сам контейнер Prometheus, а не приложение.
- *Решение:* указать имя сервиса из Docker Compose (`app:5000`) — контейнеры в одной сети находят друг друга через встроенный DNS Docker.

**prometheus-flask-exporter ломался в debug-режиме**
- *Симптом:* ошибки регистрации метрик.
- *Причина:* debug reloader Flask запускает два процесса — наблюдатель за файлами и само приложение, — и экспортер инициализировался дважды.
- *Решение:* отключить reloader (в продакшене debug-режим не используется).

**Terraform: путь к AMI в LocalStack**
- *Причина:* LocalStack эмулирует не все публичные AMI, поиск образа вёл себя иначе, чем в реальном AWS.
- *Решение:* отлаживать синтаксис на LocalStack, а поиск AMI проверять на реальном AWS.

**Trivy: 54 уязвимости в Go-библиотеках в Python-образе**
- *Причина:* `COPY . .` копировал в образ весь контекст сборки, включая бинарник провайдера AWS из `terraform/.terraform/`.
- *Решение:* явный `COPY` только файлов приложения и расширенный `.dockerignore`.

**Trivy: HIGH CVE в `zlib1g` из базового образа**
- *Решение:* `apt-get upgrade` в Dockerfile — патчи безопасности ОС ставятся, даже если базовый образ отстаёт.

**Случайный коммит `.terraform/` в git**
- *Решение:* `git rm -r --cached`, добавить правила в `.gitignore` (`**/.terraform/*`, `*.tfstate`).

**OIDC: `Not authorized to perform sts:AssumeRoleWithWebIdentity`**
- *Причина:* GitHub выдаёт immutable `sub` claim с ID владельца и репозитория (`repo:madimuk@156674890/devops-todo-app@1354639612:...`), а trust policy ждала именной формат `repo:madimuk/devops-todo-app:...`.
- *Решение:* получить реальный префикс через `gh api repos/<owner>/<repo>/actions/oidc/customization/sub` и использовать его в trust policy.

**OIDC bootstrap: `AccessDenied` на `iam:CreateOpenIDConnectProvider`**
- *Причина:* у IAM-пользователя Terraform намеренно нет прав на IAM.
- *Решение:* временная inline-политика, ограниченная OIDC-провайдером и `role/github-actions-*`, удалена сразу после `apply` (право менять роли — путь к повышению привилегий).

## Контроль стоимости AWS

- Инстанс `t2.micro`, без NAT Gateway и ALB.
- Синтаксис Terraform отлаживается на LocalStack, Kubernetes — на minikube вместо EKS.
- После экспериментов — `terraform destroy`; настроены алерты AWS Budgets.

## Roadmap

- [x] Flask + PostgreSQL
- [x] Docker и Docker Compose
- [x] Terraform: LocalStack → AWS EC2 (eu-central-1)
- [x] CI/CD: GitHub Actions → ghcr.io
- [x] Мониторинг: Prometheus + Grafana (локально)
- [x] Kubernetes на minikube + NGINX Ingress
- [x] Terraform remote state: S3 + нативная блокировка (`use_lockfile`)
- [x] OIDC для GitHub Actions → AWS вместо постоянных ключей
- [ ] Ansible: настройка EC2 и деплой приложения
- [x] Trivy: сканирование образа в pipeline
- [x] Dependabot: еженедельные обновления actions, pip и Docker
- [ ] SSH только с моего IP, доступ через SSM Session Manager
- [ ] Helm-чарт для приложения
