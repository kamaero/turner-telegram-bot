#!/bin/bash

# 🚀 Настройка домена motorist-ufa.online для админки Turner Bot

set -e

echo "🌐 Настройка домена motorist-ufa.online для админки Turner Bot"
echo "=========================================================="

DOMAIN="motorist-ufa.online"
EMAIL="admin@motorist-ufa.online"  # Измените на ваш email

# Проверка зависимостей
check_dependencies() {
    echo "📋 Проверка зависимостей..."
    
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker не установлен"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo "❌ Docker Compose не установлен"
        exit 1
    fi
    
    echo "✅ Зависимости проверены"
}

# Создание директорий
setup_directories() {
    echo "📁 Создание директорий..."
    
    sudo mkdir -p /etc/ssl/certs
    sudo mkdir -p /etc/ssl/private
    sudo mkdir -p /var/www/html
    sudo mkdir -p ssl
    
    echo "✅ Директории созданы"
}

# Настройка DNS
setup_dns() {
    echo "🌐 Настройка DNS..."
    echo "Убедитесь что A запись $DOMAIN указывает на ваш IP:"
    
    IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "localhost")
    echo "📍 Ваш IP: $IP"
    echo "🔗 DNS запись: $DOMAIN -> $IP"
    echo ""
    echo "Проверьте DNS:"
    echo "nslookup $DOMAIN"
    echo ""
    read -p "DNS настроен? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "⚠️  Сначала настройте DNS запись!"
        exit 1
    fi
}

# Получение SSL сертификата
setup_ssl() {
    echo "🔒 Настройка SSL..."
    
    # Установка Certbot
    if ! command -v certbot &> /dev/null; then
        echo "📦 Установка Certbot..."
        sudo apt update
        sudo apt install -y certbot python3-certbot-nginx
    fi
    
    # Получение сертификата
    echo "🔑 Получение SSL сертификата для $DOMAIN..."
    sudo certbot certonly --standalone -d $DOMAIN --email $EMAIL --agree-tos --non-interactive
    
    if [ $? -eq 0 ]; then
        echo "✅ SSL сертификат получен"
        
        # Копирование сертификатов
        sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ssl/motorist-ufa.online.crt
        sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ssl/motorist-ufa.online.key
        sudo chown $USER:$USER ssl/motorist-ufa.online.*
        echo "✅ Сертификаты скопированы в ssl/"
    else
        echo "⚠️  Не удалось получить сертификат, используем самоподписанный..."
        generate_self_signed
    fi
}

# Генерация самоподписанного сертификата
generate_self_signed() {
    echo "🔐 Генерация самоподписанного сертификата..."
    
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ssl/motorist-ufa.online.key \
        -out ssl/motorist-ufa.online.crt \
        -subj "/C=RU/ST=Ufa/L=Ufa/O=Motorist/OU=IT/CN=$DOMAIN"
    
    sudo chown $USER:$USER ssl/motorist-ufa.online.*
    echo "✅ Самоподписанный сертификат создан"
}

# Настройка защиты
setup_security() {
    echo "🛡️ Настройка защиты админки..."
    
    # Создание .htpasswd
    if [ ! -f ".htpasswd" ]; then
        echo "🔐 Создание .htpasswd для базовой авторизации..."
        echo "Введите пароль для доступа к админке:"
        htpasswd -c .htpasswd admin
    fi
    
    # Копирование в nginx директорию
    sudo mkdir -p /etc/nginx
    sudo cp .htpasswd /etc/nginx/.htpasswd
    sudo chown root:root /etc/nginx/.htpasswd
    sudo chmod 644 /etc/nginx/.htpasswd
    
    echo "✅ Защита настроена"
}

# Настройка файрвола
setup_firewall() {
    echo "🛡️ Настройка файрвола..."
    
    if command -v ufw &> /dev/null; then
        sudo ufw allow ssh
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        sudo ufw --force enable
        echo "✅ UFW настроен"
    elif command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --permanent --add-service=ssh
        sudo firewall-cmd --permanent --add-service=http
        sudo firewall-cmd --permanent --add-service=https
        sudo firewall-cmd --reload
        echo "✅ Firewalld настроен"
    fi
}

# Запуск продакшн конфигурации
start_production() {
    echo "🚀 Запуск продакшн конфигурации..."
    
    # Остановка текущих контейнеров
    docker-compose down 2>/dev/null || true
    
    # Запуск с Nginx
    docker-compose -f docker-compose.prod.yml up -d
    
    # Проверка статуса
    sleep 15
    if docker-compose -f docker-compose.prod.yml ps | grep -q "Up"; then
        echo "✅ Продакшн конфигурация запущена!"
    else
        echo "❌ Ошибка запуска. Проверьте логи:"
        docker-compose -f docker-compose.prod.yml logs
        exit 1
    fi
}

# Настройка автозапуска SSL
setup_ssl_renewal() {
    echo "🔄 Настройка автопродления SSL..."
    
    # Создание скрипта для обновления сертификатов
    cat > ssl_renew.sh << 'EOF'
#!/bin/bash
# Обновление SSL сертификатов и перезапуск Nginx

certbot renew --quiet
if [ $? -eq 0 ]; then
    # Копирование новых сертификатов
    cp /etc/letsencrypt/live/motorist-ufa.online/fullchain.pem /opt/turner-bot/ssl/motorist-ufa.online.crt
    cp /etc/letsencrypt/live/motorist-ufa.online/privkey.pem /opt/turner-bot/ssl/motorist-ufa.online.key
    
    # Перезапуск Nginx контейнера
    cd /opt/turner-bot
    docker-compose -f docker-compose.prod.yml restart nginx
    
    echo "SSL сертификаты обновлены"
fi
EOF
    
    chmod +x ssl_renew.sh
    
    # Добавление в cron
    (crontab -l 2>/dev/null; echo "0 3 * * * /opt/turner-bot/ssl_renew.sh") | crontab -
    
    echo "✅ Автопродление SSL настроено"
}

# Проверка работы
check_work() {
    echo "🔍 Проверка работы..."
    
    IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "localhost")
    
    echo "🌐 Доступные URL:"
    echo "Админ-панель: https://$DOMAIN/"
    echo "Проверка SSL: https://www.ssllabs.com/ssltest/"
    echo ""
    echo "📊 Статус контейнеров:"
    docker-compose -f docker-compose.prod.yml ps
    echo ""
    echo "🔧 Полезные команды:"
    echo "docker-compose -f docker-compose.prod.yml logs -f nginx"
    echo "docker-compose -f docker-compose.prod.yml logs -f web-admin"
    echo "docker-compose -f docker-compose.prod.yml restart nginx"
}

# Основной процесс
main() {
    check_dependencies
    setup_directories
    setup_dns
    setup_ssl
    setup_security
    setup_firewall
    start_production
    setup_ssl_renewal
    check_work
    
    echo ""
    echo "🎉 Настройка завершена!"
    echo "🔐 Логин: admin"
    echo "🔑 Пароль: тот что ввели при создании .htpasswd"
    echo "🌐 Админ-панель: https://$DOMAIN/"
    echo "📖 Документация: DOMAIN_SETUP.md"
}

# Запуск
main "$@"
