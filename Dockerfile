# Базовый образ — лёгкий Python без лишнего мусора
FROM python:3.12-slim

# Рабочая директория внутри контейнера
WORKDIR /app

# Ставим обновления безопасности ОС: базовый образ может отставать от патчей Debian
RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Сначала копируем только requirements.txt — это позволяет Docker кэшировать
# слой с зависимостями, если сам код меняется, а зависимости нет
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копируем только то, что нужно приложению — а не всю папку проекта
COPY app.py .
COPY templates/ templates/

# Порт, на котором работает Flask
EXPOSE 5000

# Переменные окружения по умолчанию (можно переопределить при запуске)
ENV DB_HOST=db \
    DB_PORT=5432 \
    DB_NAME=tododb \
    DB_USER=postgres \
    DB_PASSWORD=postgres

# Команда запуска приложения
CMD ["python", "app.py"]
