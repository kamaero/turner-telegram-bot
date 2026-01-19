# 🔧 Исправление ошибки сборки Docker

## 🚨 Ошибка:
```
failed to solve: process "/bin/sh -c apt-get update && apt-get install -y gcc default-libmysqlclient-dev pkg-config && rm -rf /var/lib/apt/lists/*" did not complete successfully: exit code: 100
```

## 📝 Что это значит:
- Docker не может установить системные пакеты
- Код ошибки 100 - общая ошибка apt-get
- Обычно происходит из-за проблем с репозиториями или сетью

## 🛠️ Решения:

### ✅ Решение 1: Исправленный Dockerfile (уже применен)

Основной Dockerfile обновлен с флагами:
```dockerfile
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    gcc \
    default-libmysqlclient-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*
```

### ✅ Решение 2: Альтернативный Dockerfile

Если проблема осталась, используйте `Dockerfile.stable`:
```bash
# Переименуйте
mv Dockerfile Dockerfile.backup
mv Dockerfile.stable Dockerfile

# Или используйте напрямую
docker build -f Dockerfile.stable -t turner-bot .
```

### ✅ Решение 3: Очистка и пересборка

```bash
# Очистите Docker
docker system prune -a

# Пересоберите образ
docker-compose build --no-cache
```

### ✅ Решение 4: Проверка сети

```bash
# Проверьте доступ к репозиториям
docker run --rm python:3.11-slim apt-get update

# Если ошибка, попробуйте другой DNS
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

## 🔄 Команды для исправления:

### 1. Обновите код:
```bash
cd turner-telegram-bot
git pull
```

### 2. Очистите и пересоберите:
```bash
docker-compose down
docker system prune -a
docker-compose build --no-cache
docker-compose up -d
```

### 3. Если не помогает - используйте стабильную версию:
```bash
docker-compose -f docker-compose.yml -f docker-compose.stable.yml up -d
```

## 📋 Создайте docker-compose.stable.yml:

```yaml
version: '3.8'

services:
  mysql_db:
    image: mysql:8.0
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD:-rootpassword123}
      MYSQL_DATABASE: ${DB_NAME:-turner_bot}
      MYSQL_USER: ${DB_USER:-app_user}
      MYSQL_PASSWORD: ${DB_PASS:-app_password123}
    volumes:
      - mysql_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      timeout: 10s
      retries: 10
      start_period: 30s

  turner-bot:
    build:
      context: .
      dockerfile: Dockerfile.stable
    restart: always
    environment:
      - BOT_TOKEN=${BOT_TOKEN}
      - BOT_ADMIN_PASSWORD=${BOT_ADMIN_PASSWORD:-botadmin123}
      - DB_HOST=mysql_db
      - DB_USER=${DB_USER:-app_user}
      - DB_PASS=${DB_PASS:-app_password123}
      - DB_NAME=${DB_NAME:-turner_bot}
      - WAIT_FOR_DB=true
    depends_on:
      mysql_db:
        condition: service_healthy

  web-admin:
    build:
      context: .
      dockerfile: Dockerfile-web-admin
    restart: always
    ports:
      - "${WEB_PORT:-8080}:80"
    volumes:
      - ./admin:/var/www/html
      - ./schema.sql:/docker-entrypoint-initdb.d/init.sql
    environment:
      - DB_HOST=mysql_db
      - DB_NAME=${DB_NAME:-turner_bot}
      - DB_USER=${DB_USER:-app_user}
      - DB_PASS=${DB_PASS:-app_password123}
      - ADMIN_PANEL_PASSWORD=${ADMIN_PANEL_PASSWORD:-admin123}
      - BOT_TOKEN=${BOT_TOKEN}
    depends_on:
      mysql_db:
        condition: service_healthy

volumes:
  mysql_data:
```

## 🎯 Что должно помочь:

1. **DEBIAN_FRONTEND=noninteractive** - отключает интерактивные запросы
2. **--no-install-recommends** - устанавливает только необходимые пакеты
3. **Поэтапная установка** - в Dockerfile.stable
4. **Очистка кеша** - перед пересборкой

## 🔍 Если ничего не помогает:

```bash
# Проверьте версию Docker
docker --version

# Проверьте место на диске
df -h

# Используйте другой базовый образ
# FROM python:3.11 (вместо slim)
```

**После исправления попробуйте развертывание снова!** 🚀
