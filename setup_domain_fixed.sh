#!/bin/bash

# 🚀 Настройка домена motorist-ufa.online для админки Turner Bot
# Версия для работы с существующим сайтом на порту 80

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
    echo "✅ DNS проверен"
}

# Остановка существующих сервисов на порту 80
stop_port80() {
    echo "🛑 Остановка сервисов на порту 80..."
    
    # Проверяем что занимает порт 80
    if sudo netstat -tlnp | grep -q ":80 "; then
        echo "⚠️  Порт 80 занят:"
        sudo netstat -tlnp | grep ":80 "
        echo ""
        echo "🔄 Временно останавливаем Apache/Nginx для получения SSL..."
        
        # Останавливаем Apache
        if command -v apache2ctl &> /dev/null; then
            sudo systemctl stop apache2
            echo "✅ Apache остановлен"
        fi
        
        # Останавливаем Nginx
        if command -v nginx &> /dev/null; then
            sudo systemctl stop nginx
            echo "✅ Nginx остановлен"
        fi
        
        # Ждем освобождения порта
        sleep 5
    else
        echo "✅ Порт 80 свободен"
    fi
}

# Запуск сервисов после получения SSL
start_port80() {
    echo "🚀 Запуск веб-сервера основного сайта..."
    
    # Запускаем Apache если был
    if command -v apache2ctl &> /dev/null && sudo systemctl is-enabled apache2 &> /dev/null; then
        sudo systemctl start apache2
        echo "✅ Apache запущен"
    fi
    
    # Запускаем Nginx если был
    if command -v nginx &> /dev/null && sudo systemctl is-enabled nginx &> /dev/null; then
        sudo systemctl start nginx
        echo "✅ Nginx запущен"
    fi
}

# Получение SSL сертификата
setup_ssl() {
    echo "🔒 Настройка SSL..."
    
    # Установка Certbot
    if ! command -v certbot &> /dev/null; then
        echo "📦 Установка Certbot..."
        sudo apt update
        sudo apt install -y certbot
    fi
    
    # Останавливаем сервисы на порту 80
    stop_port80
    
    # Получение сертификата через standalone
    echo "🔑 Получение SSL сертификата для $DOMAIN..."
    if sudo certbot certonly --standalone -d $DOMAIN --email $EMAIL --agree-tos --non-interactive --force-renewal; then
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
    
    # Запускаем сервисы обратно
    start_port80
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
        sudo apt install -y apache2-utils
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
    
    # Запуск с Nginx на порту 8443 (чтобы не конфликтовать)
    sed 's/80:80/8443:80/g' docker-compose.prod.yml > docker-compose.prod.temp.yml
    sed 's/443:443/8443:443/g' docker-compose.prod.temp.yml > docker-compose.prod.final.yml
    
    # Запуск
    docker-compose -f docker-compose.prod.final.yml up -d
    
    # Проверка статуса
    sleep 15
    if docker-compose -f docker-compose.prod.final.yml ps | grep -q "Up"; then
        echo "✅ Продакшн конфигурация запущена на порту 8443!"
    else
        echo "❌ Ошибка запуска. Проверьте логи:"
        docker-compose -f docker-compose.prod.final.yml logs
        exit 1
    fi
    
    # Удаляем временные файлы
    rm -f docker-compose.prod.temp.yml docker-compose.prod.final.yml
}

# Настройка автозапуска SSL
setup_ssl_renewal() {
    echo "🔄 Настройка автопродления SSL..."
    
    # Создание скрипта для обновления сертификатов
    cat > ssl_renew.sh << 'EOF'
#!/bin/bash
# Обновление SSL сертификатов и перезапуск Nginx

# Останавливаем веб-сервер на время обновления
systemctl stop apache2 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true

# Обновляем сертификат
certbot renew --standalone --quiet

if [ $? -eq 0 ]; then
    # Копирование новых сертификатов
    cp /etc/letsencrypt/live/motorist-ufa.online/fullchain.pem /opt/turner-bot/ssl/motorist-ufa.online.crt
    cp /etc/letsencrypt/live/motorist-ufa.online/privkey.pem /opt/turner-bot/ssl/motorist-ufa.online.key
    
    # Перезапуск Nginx контейнера
    cd /opt/turner-bot
    docker-compose down
    docker-compose -f docker-compose.prod.yml up -d
    
    echo "SSL сертификаты обновлены"
fi

# Запускаем веб-сервер обратно
systemctl start apache2 2>/dev/null || true
systemctl start nginx 2>/dev/null || true
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
    docker-compose ps
    echo ""
    echo "🔧 Полезные команды:"
    echo "docker-compose logs -f nginx"
    echo "docker-compose logs -f web-admin"
    echo "docker-compose restart nginx"
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
    echo ""
    echo "⚠️  ВАЖНО: Nginx работает на порту 8443, основной сайт на порту 80 продолжает работать!"
}

# Запуск
main "$@"
