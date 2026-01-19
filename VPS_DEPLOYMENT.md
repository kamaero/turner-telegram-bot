# 🚀 Пошаговое развертывание на VPS

## 📋 Требования к VPS:

- **ОС:** Ubuntu 20.04+ / CentOS 8+ / Debian 11+
- **RAM:** Минимум 1GB (рекомендуется 2GB+)
- **Disk:** Минимум 10GB
- **Docker:** Версия 20.10+
- **Git:** Версия 2.25+

---

## 🔧 Шаг 1: Подготовка VPS

### 1.1. Обновление системы
```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade -y

# CentOS
sudo yum update -y
```

### 1.2. Установка Docker
```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# CentOS
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

### 1.3. Установка Docker Compose
```bash
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### 1.4. Перезапуск сессии
```bash
exit  # Выйти и зайти снова
```

---

## 📥 Шаг 2: Загрузка проекта

### 2.1. Клонирование репозитория
```bash
git clone https://github.com/kamaero/turner-telegram-bot.git
cd turner-telegram-bot
```

### 2.2. Создание .env файла
```bash
cp .env.example .env
nano .env
```

**Обязательно заполните:**
```bash
BOT_TOKEN=1234567890:ABCDEF...  # Ваш токен Telegram
ADMIN_PANEL_PASSWORD=your_secure_password
DB_PASS=your_secure_db_password
DB_ROOT_PASSWORD=your_secure_root_password
```

---

## 🛡️ Шаг 3: Настройка безопасности (РЕКОМЕНДУЕТСЯ)

### 3.1. Генерация безопасных паролей
```bash
php generate_passwords.php
```

### 3.2. Настройка HTTPS (через Nginx)
```bash
# Создайте nginx.conf
nano nginx.conf
```

**nginx.conf:**
```nginx
events {
    worker_connections 1024;
}

http {
    upstream web-admin {
        server web-admin:80;
    }

    server {
        listen 80;
        server_name your-domain.com;
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name your-domain.com;

        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;

        location / {
            proxy_pass http://web-admin;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
```

### 3.3. Создание docker-compose.prod.yml
```bash
cp docker-compose.yml docker-compose.prod.yml
nano docker-compose.prod.yml
```

**Добавьте Nginx:**
```yaml
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - web-admin

  # ... остальные сервисы из docker-compose.yml
```

---

## 🚀 Шаг 4: Запуск проекта

### 4.1. Простой запуск (без HTTPS)
```bash
docker-compose up -d
```

### 4.2. Запуск с HTTPS
```bash
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### 4.3. Проверка статуса
```bash
docker-compose ps
```

---

## 🔍 Шаг 5: Проверка работы

### 5.1. Проверка контейнеров
```bash
docker-compose logs -f  # Просмотр логов
docker-compose ps        # Статус контейнеров
```

### 5.2. Проверка доступности
```bash
# Админ-панель
curl http://your-vps-ip:8080/admin/

# Тест токена
curl http://your-vps-ip:8080/admin/test_token.php
```

---

## 📊 Шаг 6: Мониторинг

### 6.1. Автозапуск при загрузке
```bash
# Создайте сервис systemd
sudo nano /etc/systemd/system/turner-bot.service
```

**turner-bot.service:**
```ini
[Unit]
Description=Turner Telegram Bot
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/user/turner-telegram-bot
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable turner-bot.service
sudo systemctl start turner-bot
```

### 6.2. Настройка бэкапов
```bash
# Скрипт бэкапа
nano backup.sh
```

**backup.sh:**
```bash
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
docker-compose exec mysql_db mysqldump -u root -p$DB_ROOT_PASSWORD turner_bot > backup_$DATE.sql
gzip backup_$DATE.sql
```

```bash
chmod +x backup.sh
# Добавьте в cron для ежедневных бэкапов
crontab -e
# 0 2 * * * /path/to/backup.sh
```

---

## 🚨 Шаг 7: Файрвол

### 7.1. Настройка UFW (Ubuntu)
```bash
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

### 7.2. Настройка iptables (CentOS)
```bash
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo service iptables save
```

---

## 📱 Шаг 8: Настройка домена (опционально)

### 8.1. Настройка DNS
- **A запись:** your-domain.com → IP_VPS
- **AAAA запись:** your-domain.com → IPv6_VPS (если есть)

### 8.2. Получение SSL сертификата
```bash
# Через Certbot
sudo apt install certbot
sudo certbot certonly --standalone -d your-domain.com
```

---

## ✅ Проверочный лист

- [ ] Docker и Docker Compose установлены
- [ ] Проект склонирован
- [ ] .env файл настроен
- [ ] Брандмауэр настроен
- [ ] Контейнеры запущены
- [ ] Админ-панель доступна
- [ ] Бот отвечает в Telegram
- [ ] Бэкапы настроены
- [ ] Мониторинг настроен

---

## 🔧 Полезные команды

```bash
# Перезапуск сервисов
docker-compose restart

# Просмотр логов
docker-compose logs -f web-admin
docker-compose logs -f turner-bot

# Обновление проекта
git pull
docker-compose down
docker-compose up -d --build

# Очистка (удаление старых образов)
docker system prune -a
```

---

## 🆘 Частые проблемы

### 1. Контейнеры не запускаются
```bash
# Проверьте логи
docker-compose logs

# Проверьте .env файл
cat .env
```

### 2. Нет доступа к админ-панели
```bash
# Проверьте порты
sudo netstat -tlnp | grep :8080

# Проверьте файрвол
sudo ufw status
```

### 3. Бот не отвечает
```bash
# Проверьте токен
curl https://api.telegram.org/bot$BOT_TOKEN/getMe

# Проверьте логи бота
docker-compose logs turner-bot
```

---

## 📞 Поддержка

Если возникли проблемы:
1. Проверьте логи: `docker-compose logs`
2. Проверьте .env файл
3. Убедитесь что токен бота правильный
4. Проверьте доступность портов

**Готово! Ваш проект должен работать на VPS!** 🎉
