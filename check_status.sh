#!/bin/bash

# 🔍 Проверка статуса и доступности Turner Bot после настройки домена

echo "🔍 Проверка статуса Turner Bot"
echo "============================="

# Проверка контейнеров
echo "📊 Статус контейнеров:"
docker-compose -f docker-compose.with-site.yml ps

echo ""
echo "🔍 Проверка доступности сервисов:"

# Проверка MySQL
echo "🗄️  MySQL:"
docker-compose -f docker-compose.with-site.yml exec mysql_db mysqladmin ping -h localhost 2>/dev/null && echo "✅ MySQL работает" || echo "❌ MySQL не работает"

# Проверка web-admin
echo "🌐 Web Admin:"
docker-compose -f docker-compose.with-site.yml exec web-admin curl -s localhost 2>/dev/null && echo "✅ Web Admin работает" || echo "❌ Web Admin не работает"

# Проверка Nginx
echo "🔄 Nginx:"
docker-compose -f docker-compose.with-site.yml exec nginx wget -q --spider http://localhost:8080/health 2>/dev/null && echo "✅ Nginx работает" || echo "❌ Nginx не работает"

echo ""
echo "🌐 Проверка внешнего доступа:"

# Получаем IP
IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "localhost")

# Проверка порта 8443
echo "🔗 Порт 8443 (админка):"
timeout 5 bash -c "</dev/tcp/$IP/8443" 2>/dev/null && echo "✅ Порт 8443 доступен" || echo "❌ Порт 8443 не доступен"

# Проверка порта 80 (основной сайт)
echo "🔗 Порт 80 (основной сайт):"
timeout 5 bash -c "</dev/tcp/$IP/80" 2>/dev/null && echo "✅ Порт 80 доступен" || echo "❌ Порт 80 не доступен"

echo ""
echo "📋 Полезная информация:"
echo "📍 Ваш IP: $IP"
echo "🌐 Админ-панель: https://motorist-ufa.online/"
echo "🌐 Основной сайт: http://motorist-ufa.ru/"
echo ""
echo "🔧 Команды для управления:"
echo "docker-compose -f docker-compose.with-site.yml logs -f nginx"
echo "docker-compose -f docker-compose.with-site.yml logs -f web-admin"
echo "docker-compose -f docker-compose.with-site.yml restart nginx"

echo ""
echo "🔍 Если что-то не работает:"
echo "1. Проверьте логи: docker-compose -f docker-compose.with-site.yml logs"
echo "2. Проверьте SSL сертификаты: ls -la ssl/"
echo "3. Проверьте .htpasswd: ls -la .htpasswd"
echo "4. Проверьте файрвол: sudo ufw status"
