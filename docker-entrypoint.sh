#!/bin/bash
set -e

echo "=== ТОКАРНЫЙ БОТ DOCKER-ВЕРСИЯ ==="

if [ -z "$BOT_TOKEN" ]; then
    echo "ОШИБКА: Переменная BOT_TOKEN не установлена!"
    exit 1
fi

if [ -z "$DB_HOST" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ]; then
    echo "ОШИБКА: Не все переменные БД установлены (DB_HOST, DB_NAME, DB_USER, DB_PASS)!"
    exit 1
fi

cat > .env <<EOL
BOT_TOKEN=$BOT_TOKEN
DB_HOST=$DB_HOST
DB_USER=$DB_USER
DB_PASS=$DB_PASS
DB_NAME=$DB_NAME
ADMIN_PANEL_PASSWORD=${ADMIN_PANEL_PASSWORD:-admin123}
BOT_ADMIN_PASSWORD=${BOT_ADMIN_PASSWORD:-botadmin123}
EOL

cat > php_config.php <<EOL
<?php
\$db_host = '$DB_HOST';
\$db_user = '$DB_USER';
\$db_pass = '$DB_PASS';
\$db_name = '$DB_NAME';
\$admin_pass = '${ADMIN_PANEL_PASSWORD:-admin123}';
?>
EOL

if [ "$WAIT_FOR_DB" = "true" ]; then
    echo "Ожидание доступности БД..."
    until python3 -c "
import pymysql, os, time
from dotenv import load_dotenv
load_dotenv()

for i in range(30):
    try:
        conn = pymysql.connect(
            host=os.getenv('DB_HOST'),
            user=os.getenv('DB_USER'),
            password=os.getenv('DB_PASS'),
            database=os.getenv('DB_NAME'),
            cursorclass=pymysql.cursors.DictCursor
        )
        conn.close()
        print('БД доступна!')
        break
    except Exception:
        if i == 29:
            raise
        time.sleep(2)
" 2>/dev/null; do
        sleep 2
    done
fi

echo "Проверка/инициализация таблиц БД..."
python3 -c "
import pymysql
import os
from dotenv import load_dotenv

load_dotenv()

try:
    conn = pymysql.connect(
        host=os.getenv('DB_HOST'),
        user=os.getenv('DB_USER'),
        password=os.getenv('DB_PASS'),
        database=os.getenv('DB_NAME'),
        cursorclass=pymysql.cursors.DictCursor
    )
    
    with conn.cursor() as cursor:
        # Проверяем существование таблиц
        cursor.execute(\"SHOW TABLES LIKE 'users'\")
        if not cursor.fetchone():
            print('Создаем таблицы из schema.sql...')
            with open('schema.sql', 'r', encoding='utf-8') as f:
                sql_script = f.read()
                statements = sql_script.split(';')
                for statement in statements:
                    if statement.strip():
                        cursor.execute(statement)
            conn.commit()
            print('✅ Таблицы успешно созданы!')
        else:
            print('✅ Таблицы уже существуют, пропускаем создание.')
    
    conn.close()
except Exception as e:
    print(f'⚠️  Ошибка БД: {e}')
    print('Продолжаем запуск...')
"

echo "Запуск бота..."
exec "$@"
