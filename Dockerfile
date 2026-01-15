FROM python:3.11-slim

WORKDIR /app

# Устанавливаем системные зависимости
RUN apt-get update && apt-get install -y \
    gcc \
    default-libmysqlclient-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Копируем зависимости
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копируем все файлы проекта
COPY . .

# Делаем entrypoint исполняемым
RUN chmod +x docker-entrypoint.sh

# Указываем entrypoint и команду по умолчанию
ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["python3", "bot.py"]