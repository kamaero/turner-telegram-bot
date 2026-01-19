# 🚨 Решение проблемы с apt-get в Docker

## ❌ Ошибка:
```
Connection timed out [IP: 199.232.174.132 80]
Failed to fetch http://deb.debian.org/debian/dists/trixie/main/binary-amd64/Packages
```

## 🔍 Причины:
1. **Блокировка репозиториев** на VPS
2. **Проблемы с DNS**
3. **Ограничения сети**
4. **Нестабильный образ Debian Trixie**

## ✅ Решения (от простого к сложному):

### 🎯 Решение 1: Использовать Alpine (РЕКОМЕНДУЕТСЯ)

**Преимущества:**
- ✅ Меньший размер образа
- ✅ Стабильные репозитории
- ✅ Быстрее сборка
- ✅ Меньше проблем с сетью

**Выполнение:**
```bash
# Используйте Alpine версию
docker-compose -f docker-compose.alpine.yml up -d
```

### 🔧 Решение 2: Использовать полный образ Python

Если Alpine не работает:
```bash
# Используйте простой образ без дополнительных пакетов
docker-compose -f docker-compose.simple.yml up -d
```

### 🌐 Решение 3: Настройка DNS

Если проблема в DNS:
```bash
# Временно измените DNS
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf

# Перезапустите Docker
sudo systemctl restart docker

# Попробуйте собрать снова
docker-compose build --no-cache
```

### 🔄 Решение 4: Изменить репозитории Debian

```bash
# Создайте daemon.json для Docker
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "dns": ["8.8.8.8", "1.1.1.1"]
}
EOF

# Перезапустите Docker
sudo systemctl restart docker
```

### 📦 Решение 5: Использовать готовые образы

```yaml
# В docker-compose.yml замените build на image
services:
  turner-bot:
    image: python:3.11-alpine  # Готовый образ
    # ... остальная конфигурация
```

## 🚀 Быстрый запуск:

### Вариант A: Alpine (рекомендуется)
```bash
cd /opt/turner-bot
docker-compose -f docker-compose.alpine.yml up -d
```

### Вариант B: Простой образ
```bash
cd /opt/turner-bot
docker-compose -f docker-compose.simple.yml up -d
```

### Вариант C: С настройкой DNS
```bash
# Настройте DNS
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
sudo systemctl restart docker

# Попробуйте сборку
docker-compose build --no-cache
docker-compose up -d
```

## 🔍 Проверка:

### 1. Проверьте доступ к репозиториям:
```bash
docker run --rm python:3.11-slim apt-get update
```

### 2. Проверьте DNS:
```bash
docker run --rm python:3.11-slim nslookup deb.debian.org
```

### 3. Проверьте сеть:
```bash
docker run --rm python:3.11-slim ping -c 3 8.8.8.8
```

## 📋 Созданные файлы:

- `Dockerfile.alpine` - на базе Alpine Linux
- `Dockerfile.simple` - без дополнительных пакетов
- `docker-compose.alpine.yml` - конфигурация с Alpine

## 🎯 Что выбрать:

| Ситуация | Решение |
|----------|---------|
| Быстрый старт | `docker-compose.alpine.yml` |
| Проблемы с сетью | `docker-compose.simple.yml` |
| Нужен полный контроль | Настройка DNS + основной образ |

## ⚡ Самый быстрый способ:

```bash
# 1. Остановите текущие контейнеры
docker-compose down

# 2. Используйте Alpine версию
docker-compose -f docker-compose.alpine.yml up -d

# 3. Проверьте статус
docker-compose ps
```

**Alpine обычно работает стабильнее и быстрее!** 🚀
