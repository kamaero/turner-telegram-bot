#!/bin/bash

# 🔧 Исправление SSL сертификатов для Nginx

echo "🔧 Исправление SSL сертификатов"
echo "============================"

cd /opt/turner-bot

echo "📁 Проверка SSL сертификатов:"
ls -la ssl/

echo ""
echo "📁 Проверка монтирования в docker-compose:"
grep -A 5 -B 5 ssl docker-compose.with-site.yml

echo ""
echo "🔧 Исправление путей SSL в docker-compose..."

# Создаем исправленную версия с правильными путями
sed 's|./ssl:/etc/ssl:ro|./ssl:/etc/ssl/certs:ro|g' docker-compose.with-site.yml > docker-compose.ssl-fixed.yml

echo ""
echo "🔄 Перезапуск с исправленными SSL путями:"
docker-compose -f docker-compose.with-site.yml down

echo ""
echo "🚀 Запуск с исправленной конфигурацией:"
docker-compose -f docker-compose.ssl-fixed.yml up -d

echo ""
echo "⏳ Ожидание 10 секунд..."
sleep 10

echo ""
echo "🔍 Проверка логов nginx:"
docker-compose -f docker-compose.ssl-fixed.yml logs nginx | tail -10

echo ""
echo "🌐 Проверка статуса:"
docker-compose -f docker-compose.ssl-fixed.yml ps

echo ""
echo "🌐 Проверка внешнего доступа:"
IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "localhost")
timeout 5 bash -c "</dev/tcp/$IP/8443" 2>/dev/null && echo "✅ Порт 8443 доступен!" || echo "❌ Порт 8443 не доступен"

echo ""
echo "📋 Если все еще не работает:"
echo "1. Проверьте сертификаты: ls -la ssl/"
echo "2. Проверьте пути: docker-compose -f docker-compose.ssl-fixed.yml exec nginx ls -la /etc/ssl/certs/"
echo "3. Попробуйте HTTP: curl http://localhost:8443/"
