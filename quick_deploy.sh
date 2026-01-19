#!/bin/bash

# 🚀 Временное развертывание Turner Telegram Bot
# Используйте пока deploy.sh не доступен в репозитории

set -e

echo "🚀 Развертывание Turner Telegram Bot на VPS"
echo "============================================="

# Проверка Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker не установлен. Устанавливаем..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    echo "✅ Docker установлен"
fi

# Проверка Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose не установлен. Устанавливаем..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "✅ Docker Compose установлен"
fi

# Клонирование проекта
echo "📥 Загрузка проекта..."
if [ -d "turner-telegram-bot" ]; then
    cd turner-telegram-bot
    git pull
else
    git clone https://github.com/kamaero/turner-telegram-bot.git
    cd turner-telegram-bot
fi

# Создание .env
if [ ! -f ".env" ]; then
    echo "⚙️ Создание .env файла..."
    cp .env.example .env
    echo ""
    echo "📝 ОТКРОЙТЕ .env ФАЙЛ И УСТАНОВИТЕ:"
    echo "- BOT_TOKEN=ваш_telegram_токен"
    echo "- ADMIN_PANEL_PASSWORD=ваш_пароль_админки"
    echo "- DB_PASS=ваш_пароль_бд"
    echo ""
    echo "Команда для редактирования: nano .env"
    echo "После редактирования запустите: docker-compose up -d"
    exit 0
fi

# Настройка файрвола
echo "🛡️ Настройка файрвола..."
if command -v ufw &> /dev/null; then
    sudo ufw allow ssh
    sudo ufw allow 8080
    sudo ufw --force enable
    echo "✅ UFW настроен"
elif command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --permanent --add-service=ssh
    sudo firewall-cmd --permanent --add-port=8080/tcp
    sudo firewall-cmd --reload
    echo "✅ Firewalld настроен"
fi

# Запуск проекта
echo "🚀 Запуск проекта..."
docker-compose down 2>/dev/null || true
docker-compose up -d --build

# Проверка статуса
sleep 10
if docker-compose ps | grep -q "Up"; then
    echo "✅ Проект успешно запущен!"
    echo ""
    IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "localhost")
    echo "🌐 Доступные URL:"
    echo "Админ-панель: http://$IP:8080/admin/"
    echo "Тест токена:  http://$IP:8080/admin/test_token.php"
    echo ""
    echo "📊 Полезные команды:"
    echo "docker-compose ps        # Статус"
    echo "docker-compose logs -f   # Логи"
    echo "docker-compose restart    # Перезапуск"
else
    echo "❌ Ошибка запуска. Проверьте логи:"
    docker-compose logs
    exit 1
fi
