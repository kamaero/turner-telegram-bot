<?php
// Страница для проверки работы токена Telegram бота
require 'php_config.php';

$mysqli = new mysqli($db_host, $db_user, $db_pass, $db_name);
if ($mysqli->connect_error) {
    die("❌ Ошибка подключения к БД: " . $mysqli->connect_error);
}

// Получаем токен из php_config.php (переменные окружения) или из базы
$BOT_TOKEN = $bot_token;
$token_source = "Переменная окружения (.env)";
if (empty($BOT_TOKEN)) {
    $stmt = $mysqli->prepare("SELECT cfg_value FROM bot_config WHERE cfg_key = 'bot_token'");
    $stmt->execute();
    $result = $stmt->get_result();
    $token_row = $result->fetch_assoc();
    $BOT_TOKEN = $token_row['cfg_value'] ?? '';
    $token_source = "База данных";
    $stmt->close();
}

$test_result = '';
if ($BOT_TOKEN && isset($_POST['test_token'])) {
    $url = "https://api.telegram.org/bot$BOT_TOKEN/getMe";
    $context = stream_context_create(['http' => ['timeout' => 10]]);
    $response = @file_get_contents($url, false, $context);
    
    if ($response === false) {
        $test_result = '<div class="alert alert-danger">❌ Не удалось подключиться к Telegram API. Проверьте токен.</div>';
    } else {
        $data = json_decode($response, true);
        if ($data['ok']) {
            $bot_info = $data['result'];
            $test_result = '<div class="alert alert-success">✅ Токен работает! Бот: <strong>' . htmlspecialchars($bot_info['username']) . '</strong></div>';
        } else {
            $test_result = '<div class="alert alert-danger">❌ Ошибка API: ' . htmlspecialchars($data['description'] ?? 'Unknown error') . '</div>';
        }
    }
}
?>

<!DOCTYPE html>
<html>
<head>
    <title>Проверка токена Telegram</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body class="bg-light">
    <div class="container mt-5">
        <div class="row justify-content-center">
            <div class="col-md-6">
                <div class="card">
                    <div class="card-header">
                        <h4>🔧 Проверка токена Telegram бота</h4>
                    </div>
                    <div class="card-body">
                        <?php if ($test_result) echo $test_result; ?>
                        
                        <form method="POST">
                            <div class="mb-3">
                                <label class="form-label">Текущий токен:</label>
                                <input type="text" class="form-control" value="<?= htmlspecialchars($BOT_TOKEN) ?>" readonly>
                                <small class="text-muted">Источник: <?= $token_source ?></small>
                            </div>
                            
                            <?php if ($BOT_TOKEN): ?>
                                <button type="submit" name="test_token" class="btn btn-primary">🧪 Проверить токен</button>
                            <?php else: ?>
                                <div class="alert alert-warning">
                                    ⚠️ Токен не настроен. Добавьте его в админ-панели → "Конструктор"
                                </div>
                            <?php endif; ?>
                        </form>
                        
                        <hr>
                        <a href="admin.php" class="btn btn-secondary">← Назад в админ-панель</a>
                    </div>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
