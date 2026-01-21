#!/bin/bash

# 🔧 Финальное исправление SSL и Nginx

echo "🔧 Финальное исправление SSL и Nginx"
echo "================================="

cd /opt/turner-bot

echo "📁 Проверка SSL сертификатов:"
ls -la ssl/

echo ""
echo "🔍 Проверка логов nginx:"
docker-compose -f docker-compose.ssl-fixed.yml logs nginx | tail -5

echo ""
echo "📁 Проверка файлов в контейнере nginx:"
docker-compose -f docker-compose.ssl-fixed.yml exec nginx ls -la /etc/ssl/ 2>/dev/null || echo "❌ /etc/ssl/ не доступен"

docker-compose -f docker-compose.ssl-fixed.yml exec nginx ls -la /etc/ssl/certs/ 2>/dev/null || echo "❌ /etc/ssl/certs/ не доступен"

echo ""
echo "🔧 Создание правильной конфигурации..."

# Останавливаем все
docker-compose -f docker-compose.ssl-fixed.yml down

# Создаем правильную конфигурацию
cat > docker-compose.final.yml << 'EOF'
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
      - ./nginx_ssl_fixed.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/ssl:ro
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

echo ""
echo "🚀 Запуск финальной конфигурации:"
docker-compose -f docker-compose.final.yml up -d

echo ""
echo "⏳ Ожидание 15 секунд..."
sleep 15

echo ""
echo "🔍 Проверка логов nginx:"
docker-compose -f docker-compose.final.yml logs nginx | tail -10

echo ""
echo "🌐 Проверка статуса:"
docker-compose -f docker-compose.final.yml ps

echo ""
echo "🌐 Проверка внешнего доступа:"
IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "localhost")
timeout 5 bash -c "</dev/tcp/$IP/8443" 2>/dev/null && echo "✅ Порт 8443 доступен!" || echo "❌ Порт 8443 не доступен"

echo ""
echo "🌐 Попробуйте прямой доступ:"
echo "curl -I https://motorist-ufa.online/"
echo "curl -I http://$IP:8443/"

echo ""
echo "📋 Если все еще не работает:"
echo "1. Проверьте логи: docker-compose -f docker-compose.final.yml logs nginx"
echo "2. Проверьте сертификаты: docker-compose -f docker-compose.final.yml exec nginx ls -la /etc/ssl/"
echo "3. Попробуйте без SSL: временно измените nginx_ssl_fixed.conf"
