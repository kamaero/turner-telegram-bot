#!/bin/bash

# 🚀 Скрипт автоматического развертывания Turner Telegram Bot на VPS

set -e  # Остановить при ошибке

echo "🚀 Развертывание Turner Telegram Bot на VPS"
echo "============================================="

# Проверка зависимостей
check_requirements() {
    echo "📋 Проверка зависимостей..."
    
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker не установлен. Установите Docker:"
        echo "curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo "❌ Docker Compose не установлен. Установите Docker Compose:"
        echo "sudo curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose"
        echo "sudo chmod +x /usr/local/bin/docker-compose"
        exit 1
    fi
    
    if ! command -v git &> /dev/null; then
        echo "❌ Git не установлен. Установите Git:"
        echo "sudo apt install git  # Ubuntu/Debian"
        echo "sudo yum install git  # CentOS"
        exit 1
    fi
    
    echo "✅ Все зависимости установлены"
}

# Клонирование проекта
clone_project() {
    echo "📥 Клонирование проекта..."
    
    if [ -d "turner-telegram-bot" ]; then
        echo "⚠️  Папка уже существует. Обновление..."
        cd turner-telegram-bot
        git pull
    else
        git clone https://github.com/kamaero/turner-telegram-bot.git
        cd turner-telegram-bot
    fi
    
    echo "✅ Проект загружен"
}

# Настройка .env
setup_env() {
    echo "⚙️  Настройка конфигурации..."
    
    if [ ! -f ".env" ]; then
        cp .env.example .env
        echo "📝 Создан .env файл. Пожалуйста, отредактируйте его:"
        echo ""
        echo "Обязательно установите:"
        echo "- BOT_TOKEN=ваш_telegram_токен"
        echo "- ADMIN_PANEL_PASSWORD=ваш_пароль_админки"
        echo "- DB_PASS=ваш_пароль_бд"
        echo ""
        read -p "Нажмите Enter чтобы отредактировать .env файл..."
        nano .env
    else
        echo "✅ .env файл уже существует"
    fi
}

# Генерация паролей
generate_passwords() {
    if command -v php &> /dev/null; then
        if [ -f "generate_passwords.php" ]; then
            echo "🔐 Генерация безопасных паролей..."
            php generate_passwords.php
            echo ""
            read -p "Хотите обновить пароли в .env? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                nano .env
            fi
        else
            echo "⚠️  generate_passwords.php не найден. Пропускаем генерацию паролей."
        fi
    else
        echo "⚠️  PHP не установлен. Пропускаем генерацию паролей."
    fi
}

# Настройка файрвола
setup_firewall() {
    echo "🛡️  Настройка файрвола..."

    WEB_PORT_VALUE=${WEB_PORT:-8081}
    
    if command -v ufw &> /dev/null; then
        sudo ufw allow ssh
        sudo ufw allow ${WEB_PORT_VALUE}
        sudo ufw --force enable
        echo "✅ UFW настроен"
    elif command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --permanent --add-service=ssh
        sudo firewall-cmd --permanent --add-port=${WEB_PORT_VALUE}/tcp
        sudo firewall-cmd --reload
        echo "✅ Firewalld настроен"
    else
        echo "⚠️  Файрвол не найден. Настройте вручную порт ${WEB_PORT_VALUE}"
    fi
}

# Запуск проекта
start_project() {
    echo "🚀 Запуск проекта..."
    
    # Остановка старых контейнеров если есть
    docker-compose down 2>/dev/null || true
    
    # Сборка и запуск
    docker-compose up -d --build
    
    echo "✅ Проект запущен"
}

# Проверка статуса
check_status() {
    echo "🔍 Проверка статуса..."
    
    sleep 10  # Даем время на запуск
    
    if docker-compose ps | grep -q "Up"; then
        echo "✅ Контейнеры запущены"
        
        echo ""
        echo "📊 Статус сервисов:"
        docker-compose ps
        
        echo ""
        echo "🌐 Доступные URL:"
        WEB_PORT_VALUE=${WEB_PORT:-8081}
        IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "localhost")
        echo "Админ-панель: http://$IP:${WEB_PORT_VALUE}/admin/"
        echo "Тест токена:  http://$IP:${WEB_PORT_VALUE}/admin/test_token.php"
        
        echo ""
        echo "📝 Полезные команды:"
        echo "docker-compose logs -f              # Просмотр логов"
        echo "docker-compose restart             # Перезапуск"
        echo "docker-compose down                # Остановка"
        
    else
        echo "❌ Контейнеры не запустились. Проверьте логи:"
        docker-compose logs
        exit 1
    fi
}

# Основной процесс
main() {
    check_requirements
    clone_project
    setup_env
    generate_passwords
    setup_firewall
    start_project
    check_status
    
    echo ""
    echo "🎉 Развертывание завершено!"
    echo "📖 Документация: VPS_DEPLOYMENT.md"
    echo "🆘 Поддержка: docker-compose logs"
}

# Запуск
main "$@"
