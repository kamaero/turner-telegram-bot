#!/bin/bash

# 🚀 Пошаговое восстановление после перезагрузки

echo "🚀 Пошаговое восстановление после перезагрузки"
echo "======================================"

cd /opt/turner-bot

echo "📍 Шаг 1: Проверка статуса системы"
echo "Время: $(date)"
echo "Uptime: $(uptime 2>/dev/null || echo 'неизвестно')"
echo ""

echo "📍 Шаг 2: Проверка Docker"
systemctl is-active docker 2>/dev/null && echo "✅ Docker запущен" || echo "❌ Docker не запущен"
if ! systemctl is-active docker 2>/dev/null; then
    echo "🔄 Запуск Docker..."
    sudo systemctl start docker
    sleep 5
fi

echo ""
echo "📍 Шаг 3: Проверка контейнеров"
echo "Текущие контейнеры:"
docker ps -a

echo ""
echo "📍 Шаг 4: Очистка старых контейнеров"
echo "Остановка всех контейнеров..."
docker-compose -f docker-compose.fixed.yml down 2>/dev/null || true
docker-compose -f docker-compose.http.yml down 2>/dev/null || true
docker-compose -f docker-compose.with-site.yml down 2>/dev/null || true

echo ""
echo "📍 Шаг 5: Запуск базовых сервисов"
echo "Запуск MySQL и Web Admin..."
docker-compose -f docker-compose.fixed.yml up -d mysql_db web-admin

echo "⏳ Ожидание запуска MySQL (30 секунд)..."
sleep 30

echo ""
echo "📍 Шаг 6: Проверка MySQL"
docker-compose -f docker-compose.fixed.yml exec mysql_db mysqladmin ping -h localhost 2>/dev/null && echo "✅ MySQL работает" || echo "❌ MySQL не работает"

echo ""
echo "📍 Шаг 7: Запуск бота"
echo "Запуск Turner Bot..."
docker-compose -f docker-compose.fixed.yml up -d turner-bot

echo "⏳ Ожидание запуска бота (15 секунд)..."
sleep 15

echo ""
echo "📍 Шаг 8: Запуск Nginx"
echo "Запуск Nginx..."
docker-compose -f docker-compose.fixed.yml up -d nginx

echo "⏳ Ожидание запуска Nginx (10 секунд)..."
sleep 10

echo ""
echo "📍 Шаг 9: Финальная проверка статуса"
echo "Статус всех сервисов:"
docker-compose -f docker-compose.fixed.yml ps

echo ""
echo "📍 Шаг 10: Проверка работоспособности"
IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "localhost")

echo "🗄️ MySQL:"
docker-compose -f docker-compose.fixed.yml exec mysql_db mysqladmin ping -h localhost 2>/dev/null && echo "✅ Работает" || echo "❌ Не работает"

echo "🌐 Web Admin:"
docker-compose -f docker-compose.fixed.yml exec web-admin curl -s localhost 2>/dev/null && echo "✅ Работает" || echo "❌ Не работает"

echo "🔄 Nginx:"
docker-compose -f docker-compose.fixed.yml exec nginx wget -q --spider http://localhost:8080/health 2>/dev/null && echo "✅ Работает" || echo "❌ Не работает"

echo "🤖 Turner Bot:"
docker-compose -f docker-compose.fixed.yml logs turner-bot 2>/dev/null | grep -q "Started" && echo "✅ Работает" || echo "❌ Не работает"

echo ""
echo "📍 Шаг 11: Проверка внешнего доступа"
echo "🔗 Порт 8443 (админка):"
timeout 5 bash -c "</dev/tcp/$IP/8443" 2>/dev/null && echo "✅ Доступен" || echo "❌ Не доступен"

echo "🔗 Порт 80 (основной сайт):"
timeout 5 bash -c "</dev/tcp/$IP/80" 2>/dev/null && echo "✅ Доступен" || echo "❌ Не доступен"

echo ""
echo "📍 Шаг 12: Информация для доступа"
echo "================================"
echo "🌐 Админ-панель Turner Bot:"
echo "   URL: http://$IP:8443/"
echo "   Логин: admin"
echo "   Пароль: admin123"
echo ""
echo "🌐 Основной сайт:"
echo "   URL: http://motorist-ufa.ru/"
echo ""
echo "🤖 Telegram Bot:"
echo "   Отправьте команду /start боту"
echo "   Проверьте BOT_TOKEN в .env файле"

echo ""
echo "📍 Шаг 13: Автозапуск при перезагрузке"
echo "Настройка автозапуска Docker..."
sudo systemctl enable docker

echo "Настройка автозапуска Turner Bot..."
cat > /etc/systemd/system/turner-bot.service << 'EOF'
[Unit]
Description=Turner Bot Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/turner-bot
ExecStart=/usr/bin/docker-compose -f docker-compose.fixed.yml up -d
ExecStop=/usr/bin/docker-compose -f docker-compose.fixed.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable turner-bot.service

echo "✅ Автозапуск настроен"

echo ""
echo "🎉 Восстановление завершено!"
echo "================================"
echo "Если что-то не работает:"
echo "1. Проверьте логи: docker-compose -f docker-compose.fixed.yml logs [service]"
echo "2. Перезапустите сервис: docker-compose -f docker-compose.fixed.yml restart [service]"
echo "3. Проверьте .env файл: cat .env | grep BOT_TOKEN"
