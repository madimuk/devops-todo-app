# DevOps Todo App

Простое todo-приложение на Flask + PostgreSQL — учебный pet-проект для отработки полного DevOps-цикла: контейнеризация, IaC, CI/CD.

## Статус проекта

- [x] Шаг 1: базовое приложение (Flask + PostgreSQL)
- [ ] Шаг 2: контейнеризация (Docker + Docker Compose)
- [ ] Шаг 3: инфраструктура как код (Terraform, AWS)
- [ ] Шаг 4: CI/CD пайплайн (GitHub Actions)
- [ ] Шаг 5: мониторинг (Prometheus + Grafana)

## Запуск локально (пока без Docker)

1. Установить PostgreSQL локально, создать базу `tododb`
2. `pip install -r requirements.txt`
3. `python app.py`
4. Открыть http://localhost:5000

## Переменные окружения

| Переменная | По умолчанию | Описание |
|---|---|---|
| DB_HOST | localhost | Хост базы данных |
| DB_PORT | 5432 | Порт базы данных |
| DB_NAME | tododb | Имя базы данных |
| DB_USER | postgres | Пользователь БД |
| DB_PASSWORD | postgres | Пароль БД |
