#!/bin/bash

# 🔧 Диагностика и исправление сети Docker

echo "🔧 Диагностика сети Docker"
echo "========================"

cd /opt/turner-bot

echo "📊 Статус всех контейнеров:"
docker-compose -f docker-compose.with-site.yml ps

echo ""
echo "🌐 Проверка сетей Docker:"
docker network ls

echo ""
echo "🔍 Детальная информация о сети turner-bot_default:"
docker network inspect turner-bot_default

echo ""
echo "🌐 Проверка подключения контейнеров к сети:"
echo "MySQL:"
docker-compose -f docker-compose.with-site.yml exec mysql_db hostname -i 2>/dev/null || echo "❌ MySQL не в сети"

echo "Web Admin:"
docker-compose -f docker-compose.with-site.yml exec web-admin hostname -i 2>/dev/null || echo "❌ Web Admin не в сети"

echo "Nginx:"
docker-compose -f docker-compose.with-site.yml exec nginx hostname -i 2>/dev/null || echo "❌ Nginx не в сети"

echo ""
echo "🌐 Тестирование связи между контейнерами:"
echo "Из nginx в web-admin:"
docker-compose -f docker-compose.with-site.yml exec nginx ping -c 2 web-admin 2>/dev/null && echo "✅ nginx -> web-admin: OK" || echo "❌ nginx -> web-admin: FAIL"

echo "Из nginx в mysql_db:"
docker-compose -f docker-compose.with-site.yml exec nginx ping -c 2 mysql_db 2>/dev/null && echo "✅ nginx -> mysql_db: OK" || echo "❌ nginx -> mysql_db: FAIL"

echo ""
echo "🌐 Проверка HTTP доступа из nginx в web-admin:"
docker-compose -f docker-compose.with-site.yml exec nginx wget -q --spider http://web-admin 2>/dev/null && echo "✅ HTTP nginx -> web-admin: OK" || echo "❌ HTTP nginx -> web-admin: FAIL"

echo ""
echo "🔧 Попытка исправления:"

# 1. Пересоздаем сеть
echo "1. Пересоздание сети..."
docker-compose -f docker-compose.with-site.yml down
docker network rm turner-bot_default 2>/dev/null || true
docker-compose -f docker-compose.with-site.yml up -d

echo ""
echo "⏳ Ожидание 15 секунд..."
sleep 15

echo ""
echo "🔍 Повторная проверка сети:"
docker network inspect turner-bot_default | grep -A 10 "Containers"

echo ""
echo "🌐 Повторное тестирование связи:"
docker-compose -f docker-compose.with-site.yml exec nginx ping -c 2 web-admin 2>/dev/null && echo "✅ nginx -> web-admin: OK" || echo "❌ nginx -> web-admin: FAIL"

echo ""
echo "🔄 Перезапуск nginx:"
docker-compose -f docker-compose.with-site.yml restart nginx

echo ""
echo "⏳ Ожидание 10 секунд..."
sleep 10

echo ""
echo "🌐 Финальная проверка HTTP:"
docker-compose -f docker-compose.with-site.yml exec nginx wget -q --spider http://web-admin 2>/dev/null && echo "✅ HTTP доступ работает!" || echo "❌ HTTP доступ не работает"

echo ""
echo "🌐 Проверка health check nginx:"
docker-compose -f docker-compose.with-site.yml exec nginx wget -q --spider http://localhost:8080/health 2>/dev/null && echo "✅ Nginx health check: OK!" || echo "❌ Nginx health check: FAIL"

echo ""
echo "🌐 Внешний доступ к порту 8443:"
IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "localhost")
timeout 5 bash -c "</dev/tcp/$IP/8443" 2>/dev/null && echo "✅ Порт 8443 доступен!" || echo "❌ Порт 8443 не доступен"

echo ""
echo "📋 Если все еще не работает:"
echo "1. Проверьте логи nginx: docker-compose -f docker-compose.with-site.yml logs nginx"
echo "2. Проверьте логи web-admin: docker-compose -f docker-compose.with-site.yml logs web-admin"
echo "3. Попробуйте прямой доступ: curl http://localhost:8443/"
