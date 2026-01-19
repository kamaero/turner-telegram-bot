#!/bin/bash

# 🚀 Развертывание Turner Bot в отдельной директории /opt

set -e

echo "🚀 Развертывание Turner Telegram Bot в /opt/turner-bot"
echo "===================================================="

# Проверка зависимостей
if ! command -v docker &> /dev/null; then
    echo "❌ Docker не установлен"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose не установлен"
    exit 1
fi

# Создаем директорию для проекта
echo "📁 Создание директории проекта..."
sudo mkdir -p /opt/turner-bot
sudo chown $USER:$USER /opt/turner-bot

# Клонирование проекта
echo "📥 Загрузка проекта..."
cd /opt/turner-bot

if [ -d ".git" ]; then
    echo "⚠️  Проект уже существует. Обновление..."
    git pull
else
    git clone https://github.com/kamaero/turner-telegram-bot.git .
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
    echo "Команда для редактирования: nano /opt/turner-bot/.env"
    echo "После редактирования запустите: cd /opt/turner-bot && docker-compose up -d"
    exit 0
fi

# Настройка файрвола
echo "🛡️ Настройка файрвола..."
if command -v ufw &> /dev/null; then
    sudo ufw allow ssh
    sudo ufw allow 8081
    sudo ufw --force enable
    echo "✅ UFW настроен"
elif command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --permanent --add-service=ssh
    sudo firewall-cmd --permanent --add-port=8081/tcp
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
    echo "Админ-панель: http://$IP:8081/admin/"
    echo "Тест токена:  http://$IP:8081/admin/test_token.php"
    echo ""
    echo "📊 Управление проектом:"
    echo "cd /opt/turner-bot"
    echo "docker-compose ps        # Статус"
    echo "docker-compose logs -f   # Логи"
    echo "docker-compose restart    # Перезапуск"
    echo ""
    echo "🔧 Для автозапуска при загрузке системы:"
    echo "sudo nano /etc/systemd/system/turner-bot.service"
    echo "И добавьте содержимое из /opt/turner-bot/turner-bot.service"
else
    echo "❌ Ошибка запуска. Проверьте логи:"
    docker-compose logs
    exit 1
fi

# Создаем systemd сервис для автозапуска
echo "🔧 Создание сервиса автозапуска..."
cat > turner-bot.service << EOF
[Unit]
Description=Turner Telegram Bot
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/turner-bot
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Сервис создан: /opt/turner-bot/turner-bot.service"
echo "Для включения автозапуска выполните:"
echo "sudo cp /opt/turner-bot/turner-bot.service /etc/systemd/system/"
echo "sudo systemctl enable turner-bot"
echo "sudo systemctl start turner-bot"
