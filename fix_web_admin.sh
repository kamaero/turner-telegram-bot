#!/bin/bash

# 🔧 Исправление проблемы с web-admin контейнером

echo "🔧 Исправление проблемы web-admin"
echo "================================"

cd /opt/turner-bot

echo "📊 Полный статус всех контейнеров:"
docker-compose -f docker-compose.with-site.yml ps

echo ""
echo "🔍 Проверка запущен ли web-admin:"
if docker-compose -f docker-compose.with-site.yml ps | grep -q "web-admin.*Up"; then
    echo "✅ web-admin запущен"
else
    echo "❌ web-admin не запущен - это главная проблема!"
fi

echo ""
echo "🌐 Проверка сети Docker:"
docker network ls | grep turner

echo ""
echo "🔄 Проверка логов web-admin:"
docker-compose -f docker-compose.with-site.yml logs web-admin | tail -20

echo ""
echo "🚀 Попытка запуска web-admin:"
docker-compose -f docker-compose.with-site.yml up -d web-admin

echo ""
echo "⏳ Ожидание 10 секунд..."
sleep 10

echo ""
echo "🔍 Повторная проверка:"
docker-compose -f docker-compose.with-site.yml ps | grep web-admin

echo ""
echo "🌐 Проверка доступности web-admin из nginx:"
docker-compose -f docker-compose.with-site.yml exec nginx wget -q --spider http://web-admin 2>/dev/null && echo "✅ web-admin доступен из nginx" || echo "❌ web-admin не доступен из nginx"

echo ""
echo "🔄 Перезапуск nginx после запуска web-admin:"
docker-compose -f docker-compose.with-site.yml restart nginx

echo ""
echo "⏳ Ожидание 5 секунд..."
sleep 5

echo ""
echo "🌐 Финальная проверка:"
docker-compose -f docker-compose.with-site.yml exec nginx wget -q --spider http://localhost:8080/health 2>/dev/null && echo "✅ Nginx работает!" || echo "❌ Nginx все еще не работает"

echo ""
echo "🌐 Внешний доступ к порту 8443:"
IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "localhost")
timeout 5 bash -c "</dev/tcp/$IP/8443" 2>/dev/null && echo "✅ Порт 8443 доступен!" || echo "❌ Порт 8443 не доступен"

echo ""
echo "📋 Если web-admin не запускается, проверьте:"
echo "1. Логи: docker-compose -f docker-compose.with-site.yml logs web-admin"
echo "2. Переменные окружения в .env файле"
echo "3. Доступность MySQL: docker-compose -f docker-compose.with-site.yml exec mysql_db mysqladmin ping"
