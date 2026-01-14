import pymysql
import config

ALLOWED_FIELDS = {
    'photo_file_id', 'work_type', 'dimensions_info', 'conditions',
    'urgency', 'comment', 'status'
}

def get_connection():
    return pymysql.connect(
        host=config.DB_HOST,
        user=config.DB_USER,
        password=config.DB_PASS,
        database=config.DB_NAME,
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True
    )

def get_bot_config():
    conn = get_connection()
    cfg = {}
    with conn.cursor() as cursor:
        # Исправлено: проверяем обе таблицы
        try:
            cursor.execute("SELECT key_name, value_text FROM settings")
            for row in cursor.fetchall():
                cfg[row['key_name']] = row['value_text']
        except:
            pass  # Таблица может не существовать

        try:
            cursor.execute("SELECT cfg_key, cfg_value FROM bot_config")
            for row in cursor.fetchall():
                cfg[row['cfg_key']] = row['cfg_value']
        except:
            pass  # Таблица может не существовать

        # Также проверяем альтернативные имена столбцов
        try:
            cursor.execute("SHOW COLUMNS FROM bot_config")
            columns = [col['Field'] for col in cursor.fetchall()]

            if 'key' in columns and 'value' in columns:
                cursor.execute("SELECT `key`, `value` FROM bot_config")
                for row in cursor.fetchall():
                    cfg[row['key']] = row['value']
        except:
            pass

    conn.close()
    return cfg

def update_setting(key: str, value: str):
    """Обновить настройку в базе"""
    conn = get_connection()
    cursor = conn.cursor()

    print(f"DEBUG update_setting: key={key}, value={value}")

    try:
        # Проверяем структуру таблицы
        cursor.execute("SHOW COLUMNS FROM bot_config")
        columns = [col['Field'] for col in cursor.fetchall()]

        if 'key' in columns and 'value' in columns:
            # Проверяем существует ли запись
            cursor.execute("SELECT * FROM bot_config WHERE `key` = %s", (key,))
            if cursor.fetchone():
                # Обновляем существующую запись
                cursor.execute("UPDATE bot_config SET `value` = %s WHERE `key` = %s", (value, key))
                print(f"DEBUG: Запись обновлена")
            else:
                # Создаем новую запись
                cursor.execute("INSERT INTO bot_config (`key`, `value`) VALUES (%s, %s)", (key, value))
                print(f"DEBUG: Запись создана")
        elif 'cfg_key' in columns and 'cfg_value' in columns:
            # Альтернативная структура таблицы
            cursor.execute("SELECT * FROM bot_config WHERE cfg_key = %s", (key,))
            if cursor.fetchone():
                cursor.execute("UPDATE bot_config SET cfg_value = %s WHERE cfg_key = %s", (value, key))
                print(f"DEBUG: Запись обновлена (альтернативная структура)")
            else:
                cursor.execute("INSERT INTO bot_config (cfg_key, cfg_value) VALUES (%s, %s)", (key, value))
                print(f"DEBUG: Запись создана (альтернативная структура)")
        else:
            print(f"ERROR: Неизвестная структура таблицы bot_config")

        conn.commit()

        # Проверяем что сохранилось
        cursor.execute("SELECT * FROM bot_config")
        all_rows = cursor.fetchall()
        print(f"DEBUG: Все записи в bot_config: {all_rows}")

    except Exception as e:
        print(f"ERROR in update_setting: {e}")
        # Если таблицы нет, создаем ее
        try:
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS bot_config (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    `key` VARCHAR(255) UNIQUE,
                    `value` TEXT
                )
            """)
            cursor.execute("INSERT INTO bot_config (`key`, `value`) VALUES (%s, %s)", (key, value))
            conn.commit()
            print(f"DEBUG: Таблица создана и запись добавлена")
        except Exception as e2:
            print(f"ERROR creating table: {e2}")

    conn.close()

def create_order(user_id, username, full_name, order_type="standard"):
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO orders (user_id, username, full_name, order_type, status) VALUES (%s, %s, %s, %s, 'filling')",
            (user_id, username, full_name, order_type)
        )
        oid = cur.lastrowid
    conn.close()
    return oid

def update_order_field(oid, field, val):
    if field not in ALLOWED_FIELDS:
        raise ValueError(f"Недопустимое поле для обновления: {field}")
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute(f"UPDATE orders SET {field}=%s WHERE id=%s", (val, oid))
    conn.close()

def finish_order_creation(oid):
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("UPDATE orders SET status='new' WHERE id=%s", (oid,))
    conn.close()

def get_order(oid):
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("SELECT * FROM orders WHERE id=%s", (oid,))
        res = cur.fetchone()
    conn.close()
    return res

def get_active_order_id(user_id):
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("SELECT id FROM orders WHERE user_id=%s AND status='filling' ORDER BY id DESC LIMIT 1", (user_id,))
        res = cur.fetchone()
    conn.close()
    return res['id'] if res else None

def get_user_last_active_order(user_id):
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("SELECT id FROM orders WHERE user_id=%s AND status IN ('new','discussion','approved','work') ORDER BY id DESC LIMIT 1", (user_id,))
        res = cur.fetchone()
    conn.close()
    return res['id'] if res else None

def cancel_old_filling_orders(user_id):
    """Помечает все старые черновики как rejected"""
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("UPDATE orders SET status='rejected' WHERE user_id=%s AND status='filling'", (user_id,))
    conn.close()

# --- НОВЫЕ ФУНКЦИИ ДЛЯ АДМИНКИ ---
# ВЫНЕСЕНЫ ИЗ cancel_old_filling_orders!

def get_stats():
    """Получить статистику"""
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT COUNT(*) as cnt FROM orders")
    total_orders = cursor.fetchone()['cnt']

    cursor.execute("SELECT COUNT(*) as cnt FROM orders WHERE order_type = 'machining'")
    machining_orders = cursor.fetchone()['cnt']

    cursor.execute("SELECT COUNT(*) as cnt FROM orders WHERE order_type = 'engine_repair'")
    engine_orders = cursor.fetchone()['cnt']

    cursor.execute("SELECT COUNT(*) as cnt FROM orders WHERE status = 'new'")
    active_orders = cursor.fetchone()['cnt']

    cursor.execute("SELECT COUNT(*) as cnt FROM orders WHERE status = 'completed'")
    completed_orders = cursor.fetchone()['cnt']

    conn.close()

    return {
        'total_orders': total_orders,
        'machining_orders': machining_orders,
        'engine_orders': engine_orders,
        'active_orders': active_orders,
        'completed_orders': completed_orders
    }

def get_active_orders():
    """Получить активные заказы"""
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT id, order_type, created_at
        FROM orders
        WHERE status = 'new'
        ORDER BY created_at DESC
        LIMIT 20
    """)
    orders = cursor.fetchall()
    conn.close()

    return [{'id': o['id'], 'order_type': o['order_type'], 'created_at': o['created_at']} for o in orders]

def get_recent_clients():
    """Получить последних клиентов"""
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT
            user_id,
            username,
            full_name,
            COUNT(*) as order_count,
            MAX(created_at) as last_order
        FROM orders
        GROUP BY user_id, username, full_name
        ORDER BY last_order DESC
        LIMIT 10
    """)
    clients = cursor.fetchall()
    conn.close()

    return [
        {
            'user_id': c['user_id'],
            'username': c['username'],
            'full_name': c['full_name'],
            'order_count': c['order_count'],
            'last_order': c['last_order']
        } for c in clients
    ]

def get_recent_orders(limit=10):
    """Получить последние заказы"""
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(f"""
        SELECT id, order_type, user_id, username, full_name, status, comment, created_at
        FROM orders
        ORDER BY created_at DESC
        LIMIT {limit}
    """)
    orders = cursor.fetchall()
    conn.close()

    return [
        {
            'id': o['id'],
            'order_type': o['order_type'],
            'user_id': o['user_id'],
            'username': o['username'],
            'full_name': o['full_name'],
            'status': o['status'],
            'comment': o['comment'],
            'created_at': o['created_at']
        } for o in orders
    ]

def get_admin_chat_id():
    """Получить chat_id админа"""
    cfg = get_bot_config()
    return cfg.get("admin_chat_id", "0")