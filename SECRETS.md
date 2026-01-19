# 🔒 Работа с секретами в Git

## ❌ Чего НЕЛЬЗЯ загружать в Git:

- API ключи и токены
- Пароли и хеши паролей  
- SSL сертификаты
- Файлы конфигурации с секретами

## ✅ Как безопасно работать с секретами:

### 1. Используйте .env файлы
```bash
# .env (в .gitignore)
BOT_TOKEN=your_token_here
DB_PASSWORD=your_password
```

### 2. Шаблоны вместо реальных данных
```bash
# .env.example (в Git)
BOT_TOKEN=your_telegram_bot_token_here
DB_PASSWORD=your_secure_password
```

### 3. Переменные окружения в Docker
```yaml
# docker-compose.yml
environment:
  - BOT_TOKEN=${BOT_TOKEN}
  - DB_PASSWORD=${DB_PASSWORD}
```

### 4. Секреты в CI/CD
```yaml
# GitHub Actions
- name: Deploy
  env:
    BOT_TOKEN: ${{ secrets.BOT_TOKEN }}
```

## 🚨 Если случайно загрузили секрет в Git:

### 1. Удалите файл из индекса:
```bash
git rm --cached secret_file.json
```

### 2. Добавьте в .gitignore:
```bash
echo "secret_file.json" >> .gitignore
git add .gitignore
```

### 3. Удалите из истории:
```bash
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch secret_file.json" \
  --prune-empty --tag-name-filter cat -- --all
```

### 4. Принудительный push:
```bash
git push origin main --force
```

### 5. Отозвите скомпрометированные ключи:
- Зайдите в соответствующий сервис (Google Cloud, AWS, и т.д.)
- Удалите скомпрометированные ключи/аккаунты
- Создайте новые с другими данными

## 📋 Чек-лист безопасности:

- [ ] Все секреты в .gitignore
- [ ] Используются шаблоны (.env.example)
- [ ] Нет реальных ключей в коде
- [ ] Настроены secrets в CI/CD
- [ ] Регулярная проверка репозитория

## 🔗 Полезные ссылки:

- [GitHub Secret Scanning](https://docs.github.com/code-security/secret-scanning)
- [GitGuardian](https://www.gitguardian.com/)
- [TruffleHog](https://github.com/trufflesecurity/trufflehog)

## ⚠️ Запомните:

**Если секрет попал в Git - считайте его скомпрометированным!** Всегда отзываем и создаем новые ключи.
