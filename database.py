import pymysql
import config

ALLOWED_FIELDS = {
    'photo_file_id', 'work_type', 'dimensions_info', 'conditions',
    'urgency', 'comment', 'status', 'order_type',
    'car_brand', 'car_year', 'engine_issue'  # ДОБАВЛЕНО
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
    """Получить все настройки бота из таблицы bot_config"""
    conn = get_connection()
    cfg = {}
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT cfg_key, cfg_value FROM bot_config")
            for row in cursor.fetchall():
                cfg[row['cfg_key']] = row['cfg_value']
    except Exception as e:
        print(f"Ошибка при чтении настроек: {e}")
    finally:
        conn.close()
    return cfg

def update_setting(key: str, value: str):
    """Обновить настройку в базе (простая версия)"""
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            # Используем ON DUPLICATE KEY UPDATE для вставки или обновления
            sql = """
                INSERT INTO bot_config (cfg_key, cfg_value)
                VALUES (%s, %s)
                ON DUPLICATE KEY UPDATE cfg_value = %s
            """
            cursor.execute(sql, (key, value, value))
        conn.commit()
        print(f"Настройка '{key}' сохранена")
    except Exception as e:
        print(f"Ошибка сохранения настройки: {e}")
    finally:
        conn.close()

def create_order(user_id, username, full_name, order_type="standard"):
    conn = get_connection()
    oid = None
    try:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO orders (user_id, username, full_name, order_type, status) VALUES (%s, %s, %s, %s, 'filling')",
                (user_id, username, full_name, order_type)
            )
            oid = cur.lastrowid
    except Exception as e:
        print(f"Ошибка создания заказа: {e}")
    finally:
        conn.close()
    return oid

def update_order_field(oid, field, val):
    if field not in ALLOWED_FIELDS:
        print(f"Предупреждение: попытка обновить недопустимое поле: {field}")
        return
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(f"UPDATE orders SET {field}=%s WHERE id=%s", (val, oid))
    except Exception as e:
        print(f"Ошибка обновления заказа {oid}.{field}: {e}")
    finally:
        conn.close()

def finish_order_creation(oid):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("UPDATE orders SET status='new' WHERE id=%s", (oid,))
    except Exception as e:
        print(f"Ошибка завершения заказа {oid}: {e}")
    finally:
        conn.close()

def get_order(oid):
    conn = get_connection()
    result = None
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM orders WHERE id=%s", (oid,))
            result = cur.fetchone()
    except Exception as e:
        print(f"Ошибка получения заказа {oid}: {e}")
    finally:
        conn.close()
    return result

def get_active_order_id(user_id):
    conn = get_connection()
    result = None
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id FROM orders WHERE user_id=%s AND status='filling' ORDER BY id DESC LIMIT 1", (user_id,))
            res = cur.fetchone()
            if res:
                result = res['id']
    except Exception as e:
        print(f"Ошибка получения активного заказа для user {user_id}: {e}")
    finally:
        conn.close()
    return result

def cancel_old_filling_orders(user_id):
    """Помечает все старые черновики как rejected"""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("UPDATE orders SET status='rejected' WHERE user_id=%s AND status='filling'", (user_id,))
    except Exception as e:
        print(f"Ошибка отмены старых заказов: {e}")
    finally:
        conn.close()

def get_stats():
    """Получить статистику"""
    conn = get_connection()
    stats = {
        'total_orders': 0,
        'machining_orders': 0,
        'engine_orders': 0,
        'active_orders': 0,
        'completed_orders': 0
    }

    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT COUNT(*) as cnt FROM orders")
            stats['total_orders'] = cursor.fetchone()['cnt']

            cursor.execute("SELECT COUNT(*) as cnt FROM orders WHERE order_type = 'machining'")
            stats['machining_orders'] = cursor.fetchone()['cnt']

            cursor.execute("SELECT COUNT(*) as cnt FROM orders WHERE order_type = 'engine_repair'")
            stats['engine_orders'] = cursor.fetchone()['cnt']

            cursor.execute("SELECT COUNT(*) as cnt FROM orders WHERE status = 'new'")
            stats['active_orders'] = cursor.fetchone()['cnt']

            cursor.execute("SELECT COUNT(*) as cnt FROM orders WHERE status = 'completed'")
            stats['completed_orders'] = cursor.fetchone()['cnt']
    except Exception as e:
        print(f"Ошибка получения статистики: {e}")
    finally:
        conn.close()

    return stats

def get_active_orders():
    """Получить активные заказы"""
    conn = get_connection()
    orders = []
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT id, order_type, created_at
                FROM orders
                WHERE status = 'new'
                ORDER BY created_at DESC
                LIMIT 20
            """)
            for row in cursor.fetchall():
                orders.append({
                    'id': row['id'],
                    'order_type': row['order_type'],
                    'created_at': str(row['created_at'])
                })
    except Exception as e:
        print(f"Ошибка получения активных заказов: {e}")
    finally:
        conn.close()

    return orders

def get_recent_clients():
    """Получить последних клиентов"""
    conn = get_connection()
    clients = []
    try:
        with conn.cursor() as cursor:
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
            for row in cursor.fetchall():
                clients.append({
                    'user_id': row['user_id'],
                    'username': row['username'] or 'нет',
                    'full_name': row['full_name'] or 'нет',
                    'order_count': row['order_count'],
                    'last_order': str(row['last_order'])
                })
    except Exception as e:
        print(f"Ошибка получения клиентов: {e}")
    finally:
        conn.close()

    return clients

def get_recent_orders(limit=10):
    """Получить последние заказы"""
    conn = get_connection()
    orders = []
    try:
        with conn.cursor() as cursor:
            cursor.execute(f"""
                SELECT id, order_type, user_id, username, full_name, status, comment, created_at
                FROM orders
                ORDER BY created_at DESC
                LIMIT {limit}
            """)
            for row in cursor.fetchall():
                orders.append({
                    'id': row['id'],
                    'order_type': row['order_type'],
                    'user_id': row['user_id'],
                    'username': row['username'] or 'нет',
                    'full_name': row['full_name'] or 'нет',
                    'status': row['status'],
                    'comment': row['comment'] or '',
                    'created_at': str(row['created_at'])
                })
    except Exception as e:
        print(f"Ошибка получения заказов: {e}")
    finally:
        conn.close()

    return orders

def get_admin_chat_id():
    """Получить chat_id админа"""
    cfg = get_bot_config()
    return cfg.get("admin_chat_id", "0")

def ensure_admins_table():
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS admins (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    chat_id BIGINT NULL UNIQUE,
                    username VARCHAR(100) UNIQUE NULL,
                    phone VARCHAR(20) UNIQUE NULL,
                    full_name VARCHAR(255) NULL,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
            """)
            cur.execute("ALTER TABLE admins ADD COLUMN IF NOT EXISTS phone VARCHAR(20) UNIQUE NULL")
    except Exception as e:
        print(f"Ошибка создания таблицы admins: {e}")
    finally:
        conn.close()

def get_admin_chat_ids():
    ensure_admins_table()
    conn = get_connection()
    ids = []
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT chat_id FROM admins WHERE chat_id IS NOT NULL AND chat_id > 0")
            ids = [row['chat_id'] for row in cur.fetchall()]
    except Exception as e:
        print(f"Ошибка получения админов: {e}")
    finally:
        conn.close()
    if not ids:
        legacy = get_admin_chat_id()
        try:
            if legacy and legacy != "0":
                ids = [int(legacy)]
        except Exception:
            pass
    return ids

def is_admin(chat_id, username=None):
    ensure_admins_table()
    conn = get_connection()
    ok = False
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT 1 FROM admins WHERE chat_id=%s", (chat_id,))
            ok = cur.fetchone() is not None
            if not ok and username:
                cur.execute("SELECT 1 FROM admins WHERE username=%s", (username,))
                ok = cur.fetchone() is not None
    except Exception as e:
        print(f"Ошибка проверки админа: {e}")
    finally:
        conn.close()
    return ok

def admin_count():
    ensure_admins_table()
    conn = get_connection()
    cnt = 0
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) AS cnt FROM admins")
            cnt = cur.fetchone()['cnt']
    except Exception as e:
        print(f"Ошибка подсчета админов: {e}")
    finally:
        conn.close()
    return cnt

def add_admin(chat_id, username, full_name):
    ensure_admins_table()
    if admin_count() >= 10:
        return False
    conn = get_connection()
    ok = False
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO admins (chat_id, username, full_name)
                VALUES (%s, %s, %s)
                ON DUPLICATE KEY UPDATE username=VALUES(username), full_name=VALUES(full_name)
            """, (chat_id, username, full_name))
            ok = True
    except Exception as e:
        print(f"Ошибка добавления админа: {e}")
    finally:
        conn.close()
    return ok

def add_admin_by_username(username):
    ensure_admins_table()
    if not username:
        return False
    username = username.lstrip('@')
    if admin_count() >= 10:
        return False
    conn = get_connection()
    ok = False
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO admins (username)
                VALUES (%s)
                ON DUPLICATE KEY UPDATE username=%s
            """, (username, username))
            ok = True
    except Exception as e:
        print(f"Ошибка добавления админа по нику: {e}")
    finally:
        conn.close()
    return ok

def remove_admin_by_username(username):
    ensure_admins_table()
    if not username:
        return 0
    username = username.lstrip('@')
    conn = get_connection()
    affected = 0
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM admins WHERE username=%s", (username,))
            affected = cur.rowcount
    except Exception as e:
        print(f"Ошибка удаления админа: {e}")
    finally:
        conn.close()
    return affected

def list_admins():
    ensure_admins_table()
    conn = get_connection()
    rows = []
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT chat_id, username, full_name, created_at FROM admins ORDER BY created_at DESC")
            rows = cur.fetchall()
    except Exception as e:
        print(f"Ошибка списка админов: {e}")
    finally:
        conn.close()
    return rows

def bind_admin_chat_id(username, chat_id, full_name=None):
    ensure_admins_table()
    if not username or not chat_id:
        return False
    username = username.lstrip('@')
    conn = get_connection()
    ok = False
    try:
        with conn.cursor() as cur:
            cur.execute("UPDATE admins SET chat_id=%s, full_name=%s WHERE username=%s", (chat_id, full_name, username))
            ok = cur.rowcount > 0
    except Exception as e:
        print(f"Ошибка привязки chat_id админа: {e}")
    finally:
        conn.close()
    return ok

def add_admin_by_phone(phone):
    ensure_admins_table()
    if not phone:
        return False
    if admin_count() >= 10:
        return False
    conn = get_connection()
    ok = False
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO admins (phone)
                VALUES (%s)
                ON DUPLICATE KEY UPDATE phone=%s
            """, (phone, phone))
            ok = True
    except Exception as e:
        print(f"Ошибка добавления админа по телефону: {e}")
    finally:
        conn.close()
    return ok
