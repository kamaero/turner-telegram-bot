#!/bin/bash

# 🔧 Диагностика и исправление проблем с Turner Bot

echo "🔧 Диагностика проблем Turner Bot"
echo "==============================="

cd /opt/turner-bot

echo "📊 Проверка статуса контейнеров:"
docker-compose -f docker-compose.with-site.yml ps

echo ""
echo "🔍 Проверка логов контейнеров:"

echo ""
echo "🔄 Логи Nginx:"
docker-compose -f docker-compose.with-site.yml logs nginx | tail -10

echo ""
echo "🌐 Логи Web Admin:"
docker-compose -f docker-compose.with-site.yml logs web-admin | tail -10

echo ""
echo "🤖 Логи Turner Bot:"
docker-compose -f docker-compose.with-site.yml logs turner-bot | tail -5

echo ""
echo "🗄️  Логи MySQL:"
docker-compose -f docker-compose.with-site.yml logs mysql_db | tail -5

echo ""
echo "🔍 Проверка конфигурации:"

echo "SSL сертификаты:"
ls -la ssl/ 2>/dev/null || echo "❌ Папка ssl не найдена"

echo ""
echo ".htpasswd файл:"
ls -la .htpasswd 2>/dev/null || echo "❌ .htpasswd не найден"

echo ""
echo "nginx.conf:"
test -f nginx_fixed.conf && echo "✅ nginx_fixed.conf найден" || echo "❌ nginx_fixed.conf не найден"

echo ""
echo "docker-compose.with-site.yml:"
test -f docker-compose.with-site.yml && echo "✅ docker-compose.with-site.yml найден" || echo "❌ docker-compose.with-site.yml не найден"

echo ""
echo "🛡️  Проверка файрвола:"
if command -v ufw &> /dev/null; then
    sudo ufw status | grep -E "(8443|80|443)"
elif command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --list-all | grep -E "(8443|80|443)"
fi

echo ""
echo "🔧 Попытка исправления:"

# Проверяем и открываем порт 8443
if command -v ufw &> /dev/null; then
    echo "Открытие порта 8443 в UFW..."
    sudo ufw allow 8443/tcp 2>/dev/null && echo "✅ Порт 8443 открыт" || echo "❌ Не удалось открыть порт 8443"
elif command -v firewall-cmd &> /dev/null; then
    echo "Открытие порта 8443 в firewalld..."
    sudo firewall-cmd --permanent --add-port=8443/tcp 2>/dev/null && echo "✅ Порт 8443 открыт" && sudo firewall-cmd --reload 2>/dev/null || echo "❌ Не удалось открыть порт 8443"
fi

echo ""
echo "🔄 Перезапуск проблемных сервисов:"
echo "Перезапуск Nginx..."
docker-compose -f docker-compose.with-site.yml restart nginx

echo "Перезапуск Web Admin..."
docker-compose -f docker-compose.with-site.yml restart web-admin

echo ""
echo "⏳ Ожидание запуска сервисов..."
sleep 10

echo ""
echo "🔍 Повторная проверка:"
echo "Проверка Nginx:"
docker-compose -f docker-compose.with-site.yml exec nginx wget -q --spider http://localhost:8080/health 2>/dev/null && echo "✅ Nginx работает" || echo "❌ Nginx все еще не работает"

echo "Проверка Web Admin:"
docker-compose -f docker-compose.with-site.yml exec web-admin curl -s localhost 2>/dev/null && echo "✅ Web Admin работает" || echo "❌ Web Admin все еще не работает"

echo ""
echo "🌐 Проверка внешнего доступа к порту 8443:"
IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "localhost")
timeout 5 bash -c "</dev/tcp/$IP/8443" 2>/dev/null && echo "✅ Порт 8443 доступен извне" || echo "❌ Порт 8443 не доступен извне"

echo ""
echo "📋 Следующие шаги:"
echo "1. Если Nginx/Web Admin не работают: docker-compose -f docker-compose.with-site.yml logs nginx"
echo "2. Если порт 8443 не доступен: проверьте файрвол и провайдера"
echo "3. Проверьте SSL сертификаты: ls -la ssl/"
echo "4. Попробуйте доступ через http://$IP:8443/ (если HTTPS не работает)"
