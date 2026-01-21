#!/bin/bash

# 🔧 Исправление Forbidden и aiogram

echo "🔧 Исправление Forbidden и aiogram"
echo "================================="

cd /opt/turner-bot

echo "🔍 Проблема 1: Forbidden в админке"
echo "📁 Проверка .htpasswd:"
ls -la .htpasswd

echo ""
echo "📋 Содержимое .htpasswd:"
cat .htpasswd

echo ""
echo "🔧 Проверка монтирования .htpasswd в nginx:"
docker-compose -f docker-compose.http.yml exec nginx ls -la /etc/nginx/.htpasswd 2>/dev/null && echo "✅ .htpasswd смонтирован" || echo "❌ .htpasswd не смонтирован"

echo ""
echo "🔧 Исправление .htpasswd:"
# Создаем правильный .htpasswd с паролем admin123
echo "admin:$(openssl passwd -apr1 admin123)" > .htpasswd.new
mv .htpasswd.new .htpasswd

echo "✅ Создан новый .htpasswd с паролем: admin123"

echo ""
echo "🔍 Проблема 2: aiogram не найден"
echo "📦 Проверяем requirements.txt:"
if [ -f requirements.txt ]; then
    echo "✅ requirements.txt найден:"
    cat requirements.txt
else
    echo "❌ requirements.txt не найден, создаем..."
    cat > requirements.txt << 'EOF'
python-telegram-bot==20.7
python-dotenv==1.0.0
pymysql==1.1.0
streamlit
pandas
cryptography
EOF
fi

echo ""
echo "🔧 Исправление docker-compose для бота:"
# Создаем исправленную версию с правильными зависимостями
cat > docker-compose.fixed.yml << 'EOF'
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
      sh -c "pip install --no-cache-dir python-telegram-bot==20.7 aiogram==3.4.1 python-dotenv==1.0.0 pymysql==1.1.0 streamlit pandas cryptography &&
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

echo ""
echo "🔄 Перезапуск сервисов:"
docker-compose -f docker-compose.http.yml down

echo ""
echo "🚀 Запуск исправленной версии:"
docker-compose -f docker-compose.fixed.yml up -d

echo ""
echo "⏳ Ожидание 15 секунд..."
sleep 15

echo ""
echo "🔍 Проверка статуса:"
docker-compose -f docker-compose.fixed.yml ps

echo ""
echo "🤖 Проверка логов бота:"
docker-compose -f docker-compose.fixed.yml logs turner-bot | tail -10

echo ""
echo "🌐 Проверка доступа к админке:"
IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "localhost")
timeout 5 bash -c "</dev/tcp/$IP/8443" 2>/dev/null && echo "✅ Порт 8443 доступен" || echo "❌ Порт 8443 не доступен"

echo ""
echo "📋 Данные для входа:"
echo "🔗 URL: http://$IP:8443/"
echo "👤 Логин: admin"
echo "🔑 Пароль: admin123"

echo ""
echo "🤖 Для проверки бота:"
echo "1. Убедитесь что BOT_TOKEN правильный в .env"
echo "2. Отправьте /start боту"
echo "3. Проверьте логи: docker-compose -f docker-compose.fixed.yml logs turner-bot"
