# 🌐 Настройка домена motorist-ufa.online для админки Turner Bot

## 📋 Что будет настроено:

- ✅ **Домен:** `motorist-ufa.online` → админ-панель Turner Bot
- ✅ **HTTPS:** SSL сертификат от Let's Encrypt
- ✅ **Защита:** Базовая HTTP авторизация
- ✅ **Веб-сервер:** Nginx как reverse proxy
- ✅ **Безопасность:** Заголовки безопасности, SSL конфигурация

## 🚀 Быстрая настройка:

### 1. Подготовка DNS
Сначала настройте A запись:
```
motorist-ufa.online → IP_вашего_VPS
```

Проверьте:
```bash
nslookup motorist-ufa.online
```

### 2. Запустите автоматическую настройку:
```bash
cd /opt/turner-bot
./setup_domain.sh
```

### 3. Следуйте инструкциям скрипта:
- Проверит зависимости
- Настроит DNS
- Получит SSL сертификат
- Создаст .htpasswd
- Запустит продакшн конфигурацию

## 📁 Структура после настройки:

```
/opt/turner-bot/
├── docker-compose.prod.yml    # Продакшн конфигурация с Nginx
├── nginx.conf                  # Конфигурация Nginx
├── ssl/                        # SSL сертификаты
│   ├── motorist-ufa.online.crt
│   └── motorist-ufa.online.key
├── .htpasswd                   # Файл с паролем для админки
└── setup_domain.sh             # Скрипт настройки
```

## 🌐 Доступ после настройки:

- **Админ-панель:** `https://motorist-ufa.online/`
- **Логин:** `admin`
- **Пароль:** тот что ввели при настройке

## 🔧 Ручная настройка (если автоматическая не сработала):

### 1. Установка Nginx и Certbot:
```bash
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx
```

### 2. Получение SSL сертификата:
```bash
sudo certbot certonly --standalone -d motorist-ufa.online
```

### 3. Копирование сертификатов:
```bash
sudo cp /etc/letsencrypt/live/motorist-ufa.online/fullchain.pem /opt/turner-bot/ssl/motorist-ufa.online.crt
sudo cp /etc/letsencrypt/live/motorist-ufa.online/privkey.pem /opt/turner-bot/ssl/motorist-ufa.online.key
```

### 4. Создание .htpasswd:
```bash
htpasswd -c .htpasswd admin
sudo cp .htpasswd /etc/nginx/.htpasswd
```

### 5. Запуск продакшн конфигурации:
```bash
docker-compose -f docker-compose.prod.yml up -d
```

## 🛡️ Безопасность:

### 1. Базовая авторизация:
```bash
# Изменение пароля
htpasswd /etc/nginx/.htpasswd admin
```

### 2. SSL конфигурация:
- TLS 1.2 и 1.3
- Сильные шифры
- HSTS (можно добавить)
- Secure headers

### 3. Файрвол:
```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload
```

## 🔄 Обслуживание:

### 1. Проверка статуса:
```bash
docker-compose -f docker-compose.prod.yml ps
docker-compose -f docker-compose.prod.yml logs -f nginx
```

### 2. Перезапуск сервисов:
```bash
docker-compose -f docker-compose.prod.yml restart nginx
docker-compose -f docker-compose.prod.yml restart web-admin
```

### 3. Обновление SSL:
```bash
# Ручное обновление
sudo certbot renew
docker-compose -f docker-compose.prod.yml restart nginx

# Автоматическое (настроено скриптом)
crontab -l | grep ssl_renew
```

## 📊 Мониторинг:

### 1. Health check:
```bash
curl http://localhost:8080/health
```

### 2. Логи:
```bash
# Nginx логи
docker-compose -f docker-compose.prod.yml logs nginx

# Админка логи
docker-compose -f docker-compose.prod.yml logs web-admin
```

### 3. SSL тест:
- https://www.ssllabs.com/ssltest/
- https://www.ssllabs.com/ssltest/analyze.html?d=motorist-ufa.online&hideResults=on

## 🚨 Возможные проблемы:

### 1. SSL сертификат не получается:
```bash
# Проверьте DNS
nslookup motorist-ufa.online

# Проверьте порт 80
sudo netstat -tlnp | grep :80

# Используйте самоподписанный сертификат
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/motorist-ufa.online.key \
  -out ssl/motorist-ufa.online.crt \
  -subj "/C=RU/ST=Ufa/L=Ufa/O=Motorist/CN=motorist-ufa.online"
```

### 2. Nginx не запускается:
```bash
# Проверьте конфигурацию
docker-compose -f docker-compose.prod.yml exec nginx nginx -t

# Проверьте логи
docker-compose -f docker-compose.prod.yml logs nginx
```

### 3. Админка не доступна:
```bash
# Проверьте web-admin
docker-compose -f docker-compose.prod.yml exec web-admin curl localhost

# Проверьте Nginx upstream
docker-compose -f docker-compose.prod.yml exec nginx curl http://web-admin
```

## 🎯 Дополнительные улучшения:

### 1. Rate limiting:
```nginx
# Добавить в nginx.conf
limit_req_zone $binary_remote_addr zone=admin:10m rate=10r/s;

location / {
    limit_req zone=admin burst=20 nodelay;
    # ...
}
```

### 2. Fail2Ban:
```bash
sudo apt install fail2ban
sudo systemctl enable fail2ban
```

### 3. Мониторинг:
```bash
# Добавить в docker-compose.prod.yml
prometheus:
  image: prom/prometheus
  ports:
    - "9090:9090"
```

## 📱 Мобильный доступ:

После настройки админка будет доступна на мобильных устройствах через `https://motorist-ufa.online/` с базовой авторизацией.

## 🔑 Пароли:

- **Админ-панель:** через .htpasswd
- **База данных:** в .env файле
- **Telegram бот:** в .env файле

**Регулярно проверяйте и обновляйте пароли!** 🔐
