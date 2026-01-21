#!/bin/bash

# 🔧 Простое решение - сначала HTTP, потом SSL

echo "🔧 Простое решение - сначала HTTP, потом SSL"
echo "=========================================="

cd /opt/turner-bot

echo "📁 Проверка SSL сертификатов:"
ls -la ssl/

echo ""
echo "🚀 Сначала запускаем без SSL для проверки работы..."

# Создаем HTTP версию
cat > docker-compose.http.yml << 'EOF'
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
    image: python:3.11
    restart: always
    working_dir: /app
    command: >
      sh -c "pip install --no-cache-dir python-telegram-bot==20.7 python-dotenv==1.0.0 pymysql==1.1.0 streamlit pandas cryptography &&
             python3 bot.py"
    volumes:
      - ./:/app
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
    image: php:8.2-apache
    restart: always
    volumes:
      - ./admin:/var/www/html/turner-admin
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

  nginx:
    image: nginx:alpine
    restart: always
    ports:
      - "8443:8443"
    volumes:
      - ./nginx_http.conf:/etc/nginx/nginx.conf:ro
      - ./.htpasswd:/etc/nginx/.htpasswd:ro
    depends_on:
      - web-admin
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  mysql_data:
EOF

# Создаем HTTP конфиг
cat > nginx_http.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    server_tokens off;
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    # Резолвер для Docker DNS
    resolver 127.0.0.11 valid=30s;

    # Админка Turner Bot - HTTP версия для теста
    server {
        listen 8443;
        server_name motorist-ufa.online www.motorist-ufa.online;

        # Защита админки
        auth_basic "Turner Bot Admin";
        auth_basic_user_file /etc/nginx/.htpasswd;

        # Проксирование на web-admin
        location / {
            proxy_pass http://web-admin:80;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Port $server_port;
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
            proxy_buffering off;
            proxy_request_buffering off;
        }

        # Обработка PHP файлов
        location ~ \.php$ {
            proxy_pass http://web-admin:80;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Статические файлы
        location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
            proxy_pass http://web-admin:80;
            expires 1d;
            add_header Cache-Control "public";
        }
    }

    # Health check
    server {
        listen 8080;
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF

echo "🔄 Остановка текущих контейнеров..."
docker-compose -f docker-compose.final.yml down

echo ""
echo "🚀 Запуск HTTP версии..."
docker-compose -f docker-compose.http.yml up -d

echo ""
echo "⏳ Ожидание 10 секунд..."
sleep 10

echo ""
echo "🔍 Проверка HTTP версии:"
docker-compose -f docker-compose.http.yml ps

echo ""
echo "🌐 Проверка доступа к HTTP:"
IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "localhost")
timeout 5 bash -c "</dev/tcp/$IP/8443" 2>/dev/null && echo "✅ HTTP доступен!" || echo "❌ HTTP не доступен"

echo ""
echo "🌐 Попробуйте в браузере:"
echo "http://$IP:8443/"
echo "http://motorist-ufa.online:8443/"

echo ""
echo "📋 Если HTTP работает, то:"
echo "1. Админ-панель доступна по HTTP"
echo "2. Можно добавить SSL позже"
echo "3. Основная функциональность работает"

echo ""
echo "🔧 Для добавления SSL позже:"
echo "1. Проверьте что файлы сертификатов в ssl/"
echo "2. Используйте letsencrypt или самоподписанные"
echo "3. Измените конфигурацию nginx на HTTPS"
