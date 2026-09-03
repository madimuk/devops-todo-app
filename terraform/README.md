# Terraform + LocalStack — инструкция по запуску

## Что нужно установить

### 1. Terraform
```bash
# Ubuntu/WSL2
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Проверка
terraform version
```

### 2. LocalStack CLI (опционально, но удобно)
```bash
pip install localstack --break-system-packages
```

## Запуск LocalStack

LocalStack можно запустить прямо через Docker (проще всего, раз Docker уже настроен):

```bash
docker run -d --name localstack \
  -p 4566:4566 \
  -e SERVICES=ec2 \
  localstack/localstack
```

Проверить, что LocalStack поднялся:
```bash
curl http://localhost:4566/_localstack/health
```
Должен вернуть JSON со статусом сервисов.

## Применение Terraform-конфигурации

Перейди в папку `terraform/` внутри проекта:

```bash
cd terraform
```

### 1. Инициализация — скачивает нужные провайдеры
```bash
terraform init
```

### 2. Просмотр плана — что именно будет создано (без реального применения)
```bash
terraform plan
```

### 3. Применение — реально создаёт ресурсы (в LocalStack — эмулированно)
```bash
terraform apply
```
Terraform покажет план и спросит подтверждение — введи `yes`.

### 4. Проверка результата
После `apply` в конце будут выведены `outputs`: ID VPC, подсети, Security Group, инстанса.

Дополнительно можно посмотреть созданные ресурсы через AWS CLI, направленный на LocalStack:
```bash
aws --endpoint-url=http://localhost:4566 ec2 describe-vpcs
aws --endpoint-url=http://localhost:4566 ec2 describe-instances
```
(нужен `pip install awscli-local` или обычный `aws configure` с любыми фейковыми ключами + флаг `--endpoint-url`)

### 5. Уничтожение ресурсов — важно делать после каждого эксперимента
```bash
terraform destroy
```
Введи `yes` для подтверждения. На LocalStack это не стоит денег, но привычка важна — на реальном AWS `destroy` обязателен, чтобы не платить за забытые ресурсы.

## Остановка LocalStack

```bash
docker stop localstack
docker rm localstack
```

## Частые проблемы

**Ошибка `Failed to query available provider packages`** — нет интернета или проблема с прокси. Проверь подключение.

**Ошибка подключения к `localhost:4566`** — LocalStack не запущен или ещё не успел подняться (может занять 10-20 секунд после `docker run`). Проверь: `docker ps` — должен быть в списке контейнер `localstack`.

**`terraform apply` зависает** — проверь `docker logs localstack` на предмет ошибок внутри контейнера.
