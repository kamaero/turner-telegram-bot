<?php
// Безопасная конфигурация для продакшена
session_start();

// Rate limiting: 5 попыток за 15 минут
function check_rate_limit($ip) {
    $attempts_file = __DIR__ . '/login_attempts.json';
    $attempts = file_exists($attempts_file) ? json_decode(file_get_contents($attempts_file), true) : [];
    
    $now = time();
    $attempts = array_filter($attempts, function($attempt) use ($now) {
        return $now - $attempt['time'] < 900; // 15 минут
    });
    
    $ip_attempts = array_filter($attempts, function($attempt) use ($ip) {
        return $attempt['ip'] === $ip;
    });
    
    if (count($ip_attempts) >= 5) {
        return false; // Блокировка
    }
    
    return true;
}

// Логирование попыток входа
function log_login_attempt($ip, $success) {
    $log_file = __DIR__ . '/admin_access.log';
    $timestamp = date('Y-m-d H:i:s');
    $status = $success ? 'SUCCESS' : 'FAILED';
    file_put_contents($log_file, "[$timestamp] $ip - $status\n", FILE_APPEND | LOCK_EX);
}

// Генерация CSRF токена
function generate_csrf_token() {
    if (empty($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf_token'];
}

// Проверка CSRF токена
function verify_csrf_token($token) {
    return isset($_SESSION['csrf_token']) && hash_equals($_SESSION['csrf_token'], $token);
}

// Безопасная авторизация
if (isset($_POST['login_pass'])) {
    $ip = $_SERVER['REMOTE_ADDR'];
    
    if (!check_rate_limit($ip)) {
        $error = "🚫 Слишком много попыток. Попробуйте через 15 минут.";
    } elseif (verify_csrf_token($_POST['csrf_token'] ?? '')) {
        if (password_verify($_POST['login_pass'], $admin_pass)) {
            $_SESSION['auth'] = true;
            $_SESSION['csrf_token'] = bin2hex(random_bytes(32)); // Новый токен после входа
            log_login_attempt($ip, true);
            header("Location: admin.php");
            exit;
        } else {
            log_login_attempt($ip, false);
            $error = "❌ Неверный пароль";
        }
    } else {
        $error = "❌ Ошибка безопасности. Попробуйте еще раз.";
    }
}

if (isset($_GET['logout'])) {
    session_destroy();
    header("Location: admin.php");
    exit;
}

if (!isset($_SESSION['auth'])) {
    $csrf_token = generate_csrf_token();
    echo '<!DOCTYPE html>
<html>
<head>
    <title>Вход - Админ панель</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        .login-container { min-height: 100vh; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }
        .login-card { border: none; box-shadow: 0 15px 35px rgba(0,0,0,0.1); }
    </style>
</head>
<body class="login-container d-flex align-items-center justify-content-center">
    <div class="container">
        <div class="row justify-content-center">
            <div class="col-md-5">
                <div class="card login-card">
                    <div class="card-body p-5">
                        <h4 class="text-center mb-4">🔐 Вход в CRM</h4>
                        
                        <?php if (isset($error)): ?>
                            <div class="alert alert-danger"><?= htmlspecialchars($error) ?></div>
                        <?php endif; ?>
                        
                        <form method="POST">
                            <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($csrf_token) ?>">
                            <div class="mb-3">
                                <label class="form-label">Пароль администратора</label>
                                <input type="password" name="login_pass" class="form-control" required autocomplete="current-password">
                            </div>
                            <button type="submit" class="btn btn-primary w-100">Войти</button>
                        </form>
                        
                        <div class="text-center mt-3">
                            <small class="text-muted">
                                🔒 Защищенное соединение
                            </small>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</body>
</html>';
    exit;
}
?>
