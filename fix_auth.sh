#!/bin/bash

# 🔧 Исправление авторизации и проверка бота

echo "🔧 Исправление авторизации и проверка бота"
echo "======================================"

cd /opt/turner-bot

echo "🔍 Проверка .htpasswd файла:"
cat .htpasswd

echo ""
echo "🔍 Проверка пароля admin:"
if grep -q "admin:" .htpasswd; then
    echo "✅ Пользователь admin найден в .htpasswd"
else
    echo "❌ Пользователь admin не найден в .htpasswd"
    echo "🔐 Создание нового пароля для admin:"
    htpasswd .htpasswd admin
fi

echo ""
echo "🔍 Проверка переменных окружения:"
if [ -f .env ]; then
    echo "✅ .env файл найден"
    echo "📋 Содержимое .env:"
    cat .env | grep -E "(ADMIN_PANEL_PASSWORD|BOT_TOKEN)" | sed 's/=.*/=***/'
else
    echo "❌ .env файл не найден"
    echo "📝 Создание .env файла:"
    cat > .env << 'EOF'
BOT_TOKEN=your_bot_token_here
BOT_ADMIN_PASSWORD=botadmin123
DB_HOST=mysql_db
DB_USER=app_user
DB_PASS=app_password123
DB_NAME=turner_bot
ADMIN_PANEL_PASSWORD=admin123
DB_ROOT_PASSWORD=rootpassword123
EOF
    echo "✅ .env файл создан. Отредактируйте BOT_TOKEN"
fi

echo ""
echo "🤖 Проверка статуса бота:"
docker-compose -f docker-compose.http.yml logs turner-bot | tail -10

echo ""
echo "🔍 Проверка подключения к базе:"
docker-compose -f docker-compose.http.yml exec mysql_db mysqladmin ping -h localhost 2>/dev/null && echo "✅ MySQL работает" || echo "❌ MySQL не работает"

echo ""
echo "🌐 Проверка доступа к админке:"
IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "localhost")
echo "🔗 URL: http://$IP:8443/"

echo ""
echo "🔧 Попытка исправления авторизации:"
# Проверяем правильность монтирования .htpasswd
docker-compose -f docker-compose.http.yml exec nginx ls -la /etc/nginx/.htpasswd 2>/dev/null && echo "✅ .htpasswd смонтирован" || echo "❌ .htpasswd не смонтирован"

# Перезапускаем nginx с правильными правами
docker-compose -f docker-compose.http.yml restart nginx

echo ""
echo "⏳ Ожидание 5 секунд..."
sleep 5

echo ""
echo "🌐 Повторная проверка доступа:"
timeout 5 bash -c "</dev/tcp/$IP/8443" 2>/dev/null && echo "✅ Порт 8443 доступен" || echo "❌ Порт 8443 не доступен"

echo ""
echo "📋 Инструкция по входу:"
echo "1. Откройте: http://$IP:8443/"
echo "2. Логин: admin"
echo "3. Пароль: тот что установили через htpasswd"
echo ""
echo "🔐 Если пароль не работает:"
echo "htpasswd .htpasswd admin"
echo "docker-compose -f docker-compose.http.yml restart nginx"

echo ""
echo "🤖 Для проверки бота:"
echo "1. Убедитесь что BOT_TOKEN правильный в .env"
echo "2. Проверьте логи: docker-compose -f docker-compose.http.yml logs turner-bot"
echo "3. Отправьте /start боту"
