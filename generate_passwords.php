<?php
/**
 * Генератор безопасных паролей для продакшена
 * Запуск: php generate_passwords.php
 */

echo "🔐 Генератор безопасных паролей для продакшена\n\n";

// Функция генерации случайного пароля
function generate_password($length = 16) {
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*';
    return substr(str_shuffle($chars), 0, $length);
}

// Генерация паролей
$admin_password = generate_password(16);
$db_password = generate_password(20);
$db_root_password = generate_password(24);
$bot_admin_password = generate_password(12);

// Хеширование
$admin_hash = password_hash($admin_password, PASSWORD_BCRYPT);
$db_hash = password_hash($db_password, PASSWORD_BCRYPT);
$db_root_hash = password_hash($db_root_password, PASSWORD_BCRYPT);
$bot_admin_hash = password_hash($bot_admin_password, PASSWORD_BCRYPT);

// Вывод для .env.production
echo "📝 Добавьте это в .env.production:\n\n";
echo "ADMIN_PANEL_PASSWORD={$admin_hash}\n";
echo "DB_PASS={$db_hash}\n";
echo "DB_ROOT_PASSWORD={$db_root_hash}\n";
echo "BOT_ADMIN_PASSWORD={$bot_admin_hash}\n\n";

// Вывод для справки
echo "🔑 Сохраните эти пароли в надежном месте:\n\n";
echo "Пароль админ-панели: {$admin_password}\n";
echo "Пароль БД: {$db_password}\n";
echo "Пароль root БД: {$db_root_password}\n";
echo "Пароль админа бота: {$bot_admin_password}\n\n";

echo "⚠️  ВАЖНО:\n";
echo "1. Сохраните эти пароли в менеджере паролей\n";
echo "2. Используйте только хеши в .env файле\n";
echo "3. Никогда не храните пароли в открытом виде\n";
echo "4. Регулярно меняйте пароли\n\n";

echo "✅ Готово! Теперь система готова к безопасному развертыванию.\n";
?>
