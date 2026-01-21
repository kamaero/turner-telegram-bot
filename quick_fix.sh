#!/bin/bash

# 🚑 Скорая помощь - быстрое исправление проблем

echo "🚑 Скорая помощь Turner Bot"
echo "========================"

cd /opt/turner-bot

echo "1. 🛡️  Открытие порта 8443..."
if command -v ufw &> /dev/null; then
    sudo ufw allow 8443/tcp && echo "✅ UFW: порт 8443 открыт"
elif command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --permanent --add-port=8443/tcp && sudo firewall-cmd --reload && echo "✅ Firewalld: порт 8443 открыт"
fi

echo ""
echo "2. 🔄 Перезапуск сервисов..."
docker-compose -f docker-compose.with-site.yml restart nginx web-admin

echo ""
echo "3. ⏳ Ожидание 15 секунд..."
sleep 15

echo ""
echo "4. 🔍 Проверка доступа..."
IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "localhost")

echo "Внутренняя проверка Nginx:"
docker-compose -f docker-compose.with-site.yml exec nginx wget -q --spider http://localhost:8080/health 2>/dev/null && echo "✅ Nginx: OK" || echo "❌ Nginx: FAIL"

echo "Внутренняя проверка Web Admin:"
docker-compose -f docker-compose.with-site.yml exec web-admin curl -s localhost 2>/dev/null && echo "✅ Web Admin: OK" || echo "❌ Web Admin: FAIL"

echo "Внешний доступ к порту 8443:"
timeout 5 bash -c "</dev/tcp/$IP/8443" 2>/dev/null && echo "✅ Порт 8443: OK" || echo "❌ Порт 8443: FAIL"

echo ""
echo "🌐 Попробуйте открыть в браузере:"
echo "https://motorist-ufa.online/"
echo "или если HTTPS не работает:"
echo "http://$IP:8443/"

echo ""
echo "🔧 Если все еще не работает, запустите полную диагностику:"
echo "./diagnose.sh"
