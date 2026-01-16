<?php
// Author: Sergey Akulov
// GitHub: https://github.com/serg-akulov

// Подключаем конфигурацию
if (!file_exists('php_config.php')) {
    die('<div style="font-family:sans-serif;padding:20px;color:#721c24;background-color:#f8d7da;border:1px solid #f5c6cb;border-radius:5px;max-width:600px;margin:20px auto;">
        <strong>❌ Ошибка конфигурации:</strong><br>Файл <code>php_config.php</code> не найден.
        </div>');
}
require 'php_config.php';

// Старт сессии и авторизация
session_start();
if (isset($_POST['login_pass'])) {
    if ($_POST['login_pass'] === $admin_pass) $_SESSION['auth'] = true;
}

if (isset($_GET['logout'])) {
    session_destroy();
    header("Location: admin.php");
    exit;
}

if (!isset($_SESSION['auth'])) {
    echo '<!DOCTYPE html><html><head><title>Вход</title><meta name="viewport" content="width=device-width, initial-scale=1"><link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet"></head><body class="bg-light d-flex align-items-center justify-content-center" style="height:100vh;"><div class="card p-4 shadow" style="width:100%;max-width:400px;"><h4 class="mb-3 text-center">🔐 Вход в CRM</h4><form method="POST"><input type="password" name="login_pass" class="form-control mb-3" placeholder="Пароль администратора"><button class="btn btn-primary w-100">Войти</button></form></div></body></html>';
    exit;
}

// Подключение к БД
$mysqli = new mysqli($db_host, $db_user, $db_pass, $db_name);
if ($mysqli->connect_error) {
    die("❌ Ошибка подключения к БД: " . $mysqli->connect_error);
}
$mysqli->set_charset("utf8mb4");

// Получение токена
$stmt = $mysqli->prepare("SELECT cfg_value FROM bot_config WHERE cfg_key = ?");
$stmt->bind_param("s", $token_key);
$token_key = "bot_token";
$stmt->execute();
$result = $stmt->get_result();
$token_row = $result->fetch_assoc();
$BOT_TOKEN = $token_row['cfg_value'] ?? '';
$stmt->close();

// --- Режим просмотра фото ---
if (isset($_GET['view_photos'])) {
    $oid = (int)$_GET['view_photos'];
    $stmt = $mysqli->prepare("SELECT photo_file_id FROM orders WHERE id = ?");
    $stmt->bind_param("i", $oid);
    $stmt->execute();
    $order = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    echo '<!DOCTYPE html><html><head><title>Фото #'.$oid.'</title><link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet"></head><body class="bg-dark text-white p-4">';
    echo '<div class="container"><h3>📸 Фото к заказу #'.$oid.'</h3><a href="admin.php" class="btn btn-outline-light btn-sm mb-3">← Назад</a><hr>';

    if ($order && $order['photo_file_id']) {
        $ids = array_filter(array_map('trim', explode(',', $order['photo_file_id'])));
        echo '<div class="row">';
        foreach ($ids as $file_id) {
            $context = stream_context_create(['http' => ['timeout' => 10]]);
            $json = @file_get_contents("https://api.telegram.org/bot$BOT_TOKEN/getFile?file_id=$file_id", false, $context);
            if ($json === false) continue;
            $data = json_decode($json, true);
            if (isset($data['result']['file_path'])) {
                $url = "https://api.telegram.org/file/bot$BOT_TOKEN/" . $data['result']['file_path'];
                echo '<div class="col-md-4 mb-4"><div class="card bg-secondary"><a href="'.$url.'" target="_blank"><img src="'.$url.'" class="card-img-top" style="height:300px;object-fit:contain;background:#222;"></a></div></div>';
            }
        }
        echo '</div>';
    } else {
        echo '<div class="alert alert-info">Фото не прикреплены.</div>';
    }
    echo '</div></body></html>';
    exit;
}

// --- Статусы ---
$status_map = [
    'filling' => ['text' => '✍️ Заполняет...', 'class' => 'bg-light text-muted border'],
    'new' => ['text' => '🔥 НОВЫЙ', 'class' => 'bg-success text-white'],
    'discussion' => ['text' => '💬 Обсуждение', 'class' => 'bg-info text-dark'],
    'approved' => ['text' => '🛠 В работе', 'class' => 'bg-primary text-white'],
    'done' => ['text' => '✅ ГОТОВ', 'class' => 'bg-dark text-white'],
    'rejected' => ['text' => '❌ Отказ', 'class' => 'bg-danger text-white']
];

// --- Отправка сообщения клиенту ---
function send_telegram_msg($user_id, $text) {
    global $BOT_TOKEN;
    if (!$BOT_TOKEN || !$user_id) return;
    $url = "https://api.telegram.org/bot$BOT_TOKEN/sendMessage";
    $data = ['chat_id' => $user_id, 'text' => $text, 'parse_mode' => 'HTML'];
    $options = ['http' => ['header' => "Content-Type: application/x-www-form-urlencoded\r\n", 'method' => 'POST', 'content' => http_build_query($data), 'timeout' => 10, 'ignore_errors' => true]];
    $context = stream_context_create($options);
    @file_get_contents($url, false, $context);
}

// --- Сохранение настроек ---
if (isset($_POST['save_config'])) {
    foreach ($_POST['cfg'] as $key => $value) {
        $stmt = $mysqli->prepare("INSERT INTO bot_config (cfg_key, cfg_value) VALUES (?, ?) ON DUPLICATE KEY UPDATE cfg_value = ?");
        $stmt->bind_param("sss", $key, $value, $value);
        $stmt->execute();
        $stmt->close();
    }
    $msg = "✅ Настройки сохранены!";
}

// --- Обновление заказа ---
if (isset($_POST['update_order'])) {
    $oid = (int)$_POST['order_id'];
    $new_status = $mysqli->real_escape_string($_POST['status']);
    $note = $mysqli->real_escape_string($_POST['internal_note']);

    $stmt = $mysqli->prepare("SELECT user_id, status FROM orders WHERE id = ?");
    $stmt->bind_param("i", $oid);
    $stmt->execute();
    $order_info = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    $old_status = $order_info['status'];

    $stmt = $mysqli->prepare("UPDATE orders SET status = ?, internal_note = ? WHERE id = ?");
    $stmt->bind_param("ssi", $new_status, $note, $oid);
    $stmt->execute();
    $stmt->close();

    if ($old_status != $new_status) {
        $status_text = $status_map[$new_status]['text'] ?? $new_status;
        $client_msg = "ℹ️ <b>Статус заказа #$oid изменён:</b>\n\n$status_text";
        if ($new_status === 'done') {
            $client_msg .= "\n\n🎉 Ваш заказ готов!";
        } elseif ($new_status === 'rejected') {
            $client_msg .= "\n\n❌ Заказ отменён.";
        }
        send_telegram_msg($order_info['user_id'], $client_msg);
    }
    $msg = "✅ Заказ #$oid обновлён!";
}

// --- Функция извлечения телефона из комментария ---
function extract_phone_from_comment($comment) {
    if (empty($comment)) return '';

    // 1. Ищем 11 цифр подряд (например: 89160856070)
    if (preg_match('/\b(\d{11})\b/', $comment, $matches)) {
        $phone = $matches[1];
        // 89160856070 → +7 (916) 085-60-70
        if ($phone[0] == '8' || $phone[0] == '7') {
            $digits = substr($phone, 1); // Убираем первую цифру
            if (strlen($digits) == 10) {
                return '+7 (' . substr($digits, 0, 3) . ') ' .
                       substr($digits, 3, 3) . '-' .
                       substr($digits, 6, 2) . '-' .
                       substr($digits, 8, 2);
            }
        }
    }

    // 2. Ищем 10 цифр подряд (например: 9160856070)
    if (preg_match('/\b(\d{10})\b/', $comment, $matches)) {
        $phone = $matches[1];
        // 9160856070 → +7 (916) 085-60-70
        if (strlen($phone) == 10) {
            return '+7 (' . substr($phone, 0, 3) . ') ' .
                   substr($phone, 3, 3) . '-' .
                   substr($phone, 6, 2) . '-' .
                   substr($phone, 8, 2);
        }
    }

    // 3. Ищем номер в формате с разделителями
    // Исправленное регулярное выражение: ищем 3-3-2-2 или 3-3-2-3 цифр
    if (preg_match('/(?:\+7|7|8)?[\s\-]?\(?(\d{3})\)?[\s\-]?(\d{3})[\s\-]?(\d{2})[\s\-]?(\d{2,3})/', $comment, $matches)) {
        // $matches[1] = 916, $matches[2] = 085, $matches[3] = 60, $matches[4] = 70 или 070
        $last_digits = $matches[4];
        // Если последняя группа из 3 цифр, берем последние 2
        if (strlen($last_digits) == 3) {
            $last_digits = substr($last_digits, 1);
        }
        return '+7 (' . $matches[1] . ') ' . $matches[2] . '-' . $matches[3] . '-' . $last_digits;
    }

    // 4. Ищем по ключевым словам "тел", "телефон", "номер"
    if (preg_match('/(?:тел[\.]?|телефон|номер)[\s:]*([\+\d\s\-\(\)\.]{7,})/iu', $comment, $matches)) {
        $phone = preg_replace('/[^\d]/', '', $matches[1]);

        if (strlen($phone) == 11 && ($phone[0] == '8' || $phone[0] == '7')) {
            $digits = substr($phone, 1);
            if (strlen($digits) == 10) {
                return '+7 (' . substr($digits, 0, 3) . ') ' .
                       substr($digits, 3, 3) . '-' .
                       substr($digits, 6, 2) . '-' .
                       substr($digits, 8, 2);
            }
        }

        if (strlen($phone) == 10) {
            return '+7 (' . substr($phone, 0, 3) . ') ' .
                   substr($phone, 3, 3) . '-' .
                   substr($phone, 6, 2) . '-' .
                   substr($phone, 8, 2);
        }
    }

    return '';
}

// --- Поиск и фильтрация ---
$search = $_GET['search'] ?? '';
$selected_month = (int)($_GET['m'] ?? date('n'));
$selected_year = (int)($_GET['y'] ?? date('Y'));

// --- SQL-запросы ---
function build_query($type = 'all', $search = '', $month = null, $year = null) {
    global $mysqli;
    $where = ["status != 'filling'"];
    if ($type === 'engine_repair') $where[] = "order_type = 'engine_repair'";
    elseif ($type === 'machining') $where[] = "order_type IN ('standard', 'machining')";
    if ($search) {
        $safe_search = $mysqli->real_escape_string($search);
        $where[] = "(full_name LIKE '%$safe_search%' OR username LIKE '%$safe_search%' OR comment LIKE '%$safe_search%'
                     OR car_brand LIKE '%$safe_search%' OR engine_issue LIKE '%$safe_search%')";
    }
    if ($month && $year) {
        $where[] = "MONTH(created_at) = $month AND YEAR(created_at) = $year";
    }
    return "SELECT * FROM orders WHERE " . implode(' AND ', $where) . " ORDER BY id DESC";
}

// --- Статистика ---
function get_stats($mysqli) {
    $now = new DateTime();
    $periods = [
        'week' => (clone $now)->modify('last monday')->format('Y-m-d'),
        'month' => $now->format('Y-m-01'),
        'quarter' => date('Y-m-01', strtotime('first day of january this year') + 3 * 30 * 86400 * (ceil($now->format('n') / 3) - 1)),
        'year' => $now->format('Y-01-01')
    ];
    $stats = [];
    foreach ($periods as $period => $start) {
        $stmt = $mysqli->prepare("SELECT COUNT(*) as cnt FROM orders WHERE created_at >= ? AND status != 'filling'");
        $stmt->bind_param("s", $start);
        $stmt->execute();
        $res = $stmt->get_result()->fetch_assoc();
        $stats[$period] = (int)$res['cnt'];
        $stmt->close();
    }
    return $stats;
}

$stats = get_stats($mysqli);
$orders = $mysqli->query(build_query('all', $search, $selected_month, $selected_year));
$engines = $mysqli->query(build_query('engine_repair', $search));

// --- Загрузка конфигурации бота ---
$config_result = $mysqli->query("SELECT * FROM bot_config");
$cfg = [];
while ($row = $config_result->fetch_assoc()) {
    $cfg[$row['cfg_key']] = $row['cfg_value'];
}

function render_input($key, $label, $rows = 2) {
    global $cfg;
    $val = htmlspecialchars($cfg[$key] ?? '', ENT_QUOTES, 'UTF-8');
    echo "<div class='mb-2'><label class='form-label small text-muted fw-bold text-uppercase'>$label</label><textarea name='cfg[$key]' class='form-control' rows='$rows'>$val</textarea></div>";
}

function render_switch($key, $label) {
    global $cfg;
    $val = $cfg[$key] ?? '0';
    $checked = $val == '1' ? 'checked' : '';
    echo "<div class='form-check form-switch mb-3'><input type='hidden' name='cfg[$key]' value='0'><input class='form-check-input' type='checkbox' name='cfg[$key]' value='1' id='$key' $checked><label class='form-check-label fw-bold' for='$key'>$label</label></div>";
}
?>
<!DOCTYPE html>
<html>
<head>
    <title>Моторист УФА - CRM</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        .step-card { border-left: 5px solid #0d6efd; margin-bottom: 20px; }
        .step-header { background: #f8f9fa; padding: 10px; font-weight: bold; border-bottom: 1px solid #eee; }
        .order-row { cursor: pointer; transition: 0.2s; }
        .order-row:hover { background-color: #f1f1f1; }
        .filter-bar { background: #e9ecef; padding: 10px; border-radius: 8px; margin-bottom: 20px; }
        .stat-card { text-align: center; }
        .badge { padding: 0.5em 0.8em; font-size: 0.85em; }
        .camera-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 20px; }
        .camera-card { background: #1a1a1a; border-radius: 8px; overflow: hidden; }
        .camera-header { background: #333; color: white; padding: 10px; font-weight: bold; }
        .camera-feed { width: 100%; height: 200px; object-fit: cover; background: #000; }
        .phone-link { color: #198754; text-decoration: none; }
        .phone-link:hover { color: #0d6efd; text-decoration: underline; }
    </style>
</head>
<body class="bg-light pb-5">
<nav class="navbar navbar-dark bg-dark sticky-top mb-4">
    <div class="container">
        <span class="navbar-brand mb-0 h1">🛠 Моторист УФА - CRM</span>
        <a href="?logout=1" class="btn btn-outline-danger btn-sm">Выход</a>
    </div>
</nav>

<div class="container">
    <?php if (isset($msg)) echo "<div class='alert alert-success'>$msg</div>"; ?>

    <ul class="nav nav-pills mb-4" id="pills-tab" role="tablist">
        <li class="nav-item"><button class="nav-link active" data-bs-toggle="pill" data-bs-target="#orders">📋 Все заказы</button></li>
        <li class="nav-item"><button class="nav-link" data-bs-toggle="pill" data-bs-target="#engines">🔧 Ремонт двигателей</button></li>
        <li class="nav-item"><button class="nav-link" data-bs-toggle="pill" data-bs-target="#cameras">📹 Камеры</button></li>
        <li class="nav-item"><button class="nav-link" data-bs-toggle="pill" data-bs-target="#stats">📊 Статистика</button></li>
        <li class="nav-item"><button class="nav-link" data-bs-toggle="pill" data-bs-target="#settings">⚙️ Конструктор</button></li>
    </ul>

    <div class="tab-content">
        <!-- Все заказы -->
            <div class="tab-pane fade show active" id="orders">
                <div class="filter-bar d-flex align-items-center gap-2 shadow-sm mb-3">
                    <input type="text" name="search" class="form-control form-control-sm" placeholder="Поиск по клиенту, комментарию..." value="<?= htmlspecialchars($search) ?>" style="width:300px;">
                    <select name="m" class="form-select form-select-sm" style="width:auto;" onchange="updateFilters()">
                        <?php
                        $russian_months = [
                            1 => 'Январь',
                            2 => 'Февраль',
                            3 => 'Март',
                            4 => 'Апрель',
                            5 => 'Май',
                            6 => 'Июнь',
                            7 => 'Июль',
                            8 => 'Август',
                            9 => 'Сентябрь',
                            10 => 'Октябрь',
                            11 => 'Ноябрь',
                            12 => 'Декабрь'
                        ];
                        for ($i = 1; $i <= 12; $i++): ?>
                            <option value="<?= $i ?>" <?= $i == $selected_month ? 'selected' : '' ?>><?= $russian_months[$i] ?></option>
                        <?php endfor; ?>
                    </select>
                    <select name="y" class="form-select form-select-sm" style="width:auto;" onchange="updateFilters()">
                        <?php for ($y = 2024; $y <= 2030; $y++): ?>
                            <option value="<?= $y ?>" <?= $y == $selected_year ? 'selected' : '' ?>><?= $y ?></option>
                        <?php endfor; ?>
                    </select>
                    <button type="button" class="btn btn-sm btn-primary" onclick="updateFilters()">🔍 Применить</button>
                </div>

            <div class="table-responsive bg-white shadow rounded p-3">
                <table class="table table-hover align-middle">
                    <thead class="table-light">
                        <tr><th>ID</th><th>Дата</th><th>Тип</th><th>Статус</th><th>Клиент</th><th>Контакт</th><th>Детали</th><th></th></tr>
                    </thead>
                    <tbody>
                        <?php if ($orders->num_rows == 0): ?>
                            <tr><td colspan="8" class="text-center text-muted">📭 Нет заказов</td></tr>
                        <?php else: while ($row = $orders->fetch_assoc()):
                            $phone = extract_phone_from_comment($row['comment'] ?? '');
                        ?>
                            <tr class="order-row">
                                <td>#<?= $row['id'] ?></td>
                                <td><small><?= date('d.m H:i', strtotime($row['created_at'])) ?></small></td>
                                <td><span class="badge bg-primary"><?= $row['order_type'] === 'engine_repair' ? '🔧 Двигатель' : '⚙️ Станок' ?></span></td>
                                <td><span class="badge <?= $status_map[$row['status']]['class'] ?>"><?= $status_map[$row['status']]['text'] ?></span></td>
                                <td><b><?= htmlspecialchars($row['full_name'], ENT_QUOTES, 'UTF-8') ?></b><br>@<?= htmlspecialchars($row['username'] ?? '-', ENT_QUOTES, 'UTF-8') ?></td>
                                <td>
                                    <?php if (!empty($phone)): ?>
                                        <a href="tel:<?= htmlspecialchars($phone, ENT_QUOTES, 'UTF-8') ?>" class="phone-link">
                                            📞 <?= htmlspecialchars($phone, ENT_QUOTES, 'UTF-8') ?>
                                        </a>
                                    <?php else: ?>
                                        <span class="text-muted">–</span>
                                    <?php endif; ?>
                                </td>
                                <td>
                                    <?php
                                    if ($row['order_type'] === 'engine_repair') {
                                        $car_info = ($row['car_brand'] ?? '') . ' ' . ($row['car_year'] ?? '');
                                        echo htmlspecialchars(mb_strimwidth($car_info, 0, 60, '...'), ENT_QUOTES, 'UTF-8');
                                    } else {
                                        echo htmlspecialchars(mb_strimwidth($row['work_type'] ?? $row['comment'] ?? '', 0, 60, '...'), ENT_QUOTES, 'UTF-8');
                                    }
                                    ?>
                                </td>
                                <td class="text-end"><button class="btn btn-sm btn-outline-secondary" data-bs-toggle="modal" data-bs-target="#orderModal" data-id="<?= $row['id'] ?>" data-json='<?= json_encode($row, JSON_UNESCAPED_UNICODE) ?>'>👁</button></td>
                            </tr>
                        <?php endwhile; endif; ?>
                    </tbody>
                </table>
            </div>
        </div>

        <!-- Ремонт двигателей -->
        <div class="tab-pane fade" id="engines">
            <h5>🔧 Заказы: Ремонт двигателей</h5>
            <div class="filter-bar d-flex align-items-center gap-2 shadow-sm mb-3">
                <input type="text" id="engine-search" class="form-control form-control-sm" placeholder="Поиск по марке или проблеме..." style="width:300px;">
                <button type="button" class="btn btn-sm btn-outline-primary" onclick="filterEngineTable()">🔍 Поиск</button>
            </div>
            <div class="table-responsive mt-3">
                <table class="table table-striped" id="engine-table">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Клиент</th>
                            <th>Контакт</th>
                            <th>Автомобиль</th>
                            <th>Проблема</th>
                            <th>Срочность</th>
                            <th>Статус</th>
                            <th>Действия</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php
                        $engines->data_seek(0);
                        while ($e = $engines->fetch_assoc()):
                            $car_brand = htmlspecialchars($e['car_brand'] ?? 'Не указано', ENT_QUOTES, 'UTF-8');
                            $car_year = htmlspecialchars($e['car_year'] ?? 'Не указано', ENT_QUOTES, 'UTF-8');
                            $engine_issue = htmlspecialchars($e['engine_issue'] ?? ($e['comment'] ?? 'Не указано'), ENT_QUOTES, 'UTF-8');
                            $phone = extract_phone_from_comment($e['comment'] ?? '');
                        ?>
                            <tr class="engine-row" data-brand="<?= $car_brand ?>" data-issue="<?= $engine_issue ?>">
                                <td>#<?= $e['id'] ?></td>
                                <td>
                                    <strong><?= htmlspecialchars($e['full_name'] ?? '', ENT_QUOTES, 'UTF-8') ?></strong><br>
                                    <small class="text-muted">@<?= htmlspecialchars($e['username'] ?? '—', ENT_QUOTES, 'UTF-8') ?></small>
                                </td>
                                <td>
                                    <?php if (!empty($phone)): ?>
                                        <a href="tel:<?= htmlspecialchars($phone, ENT_QUOTES, 'UTF-8') ?>" class="phone-link">
                                            📞 <?= htmlspecialchars($phone, ENT_QUOTES, 'UTF-8') ?>
                                        </a>
                                    <?php else: ?>
                                        <span class="text-muted">–</span>
                                    <?php endif; ?>
                                </td>
                                <td>
                                    <strong>Марка:</strong> <?= $car_brand ?><br>
                                    <strong>Год:</strong> <?= $car_year ?>
                                </td>
                                <td><?= $engine_issue ?></td>
                                <td>
                                    <?php
                                    $urgency = $e['urgency'] ?? '';
                                    $urgency_class = 'bg-secondary';
                                    if ($urgency === 'Высокая') $urgency_class = 'bg-danger';
                                    elseif ($urgency === 'Средняя') $urgency_class = 'bg-warning text-dark';
                                    elseif ($urgency === 'Низкая') $urgency_class = 'bg-success';
                                    ?>
                                    <span class="badge <?= $urgency_class ?>"><?= htmlspecialchars($urgency, ENT_QUOTES, 'UTF-8') ?></span>
                                </td>
                                <td>
                                    <span class="badge <?= $status_map[$e['status']]['class'] ?>">
                                        <?= $status_map[$e['status']]['text'] ?>
                                    </span>
                                </td>
                                <td>
                                    <button class="btn btn-sm btn-outline-secondary"
                                            data-bs-toggle="modal"
                                            data-bs-target="#orderModal"
                                            data-id="<?= $e['id'] ?>"
                                            data-json='<?= json_encode($e, JSON_UNESCAPED_UNICODE) ?>'>
                                        👁 Просмотр
                                    </button>
                                </td>
                            </tr>
                        <?php endwhile; ?>
                    </tbody>
                </table>
            </div>
        </div>

        <!-- Камеры наблюдения -->
        <div class="tab-pane fade" id="cameras">
            <h5>📹 Видеонаблюдение</h5>
            <div class="alert alert-info mb-3">
                <strong>ℹ️ Информация:</strong> Подключите IP-камеры через RTSP или MJPEG потоки.
                Обновите настройки в конфигурации для добавления камер.
            </div>

            <div class="camera-grid">
                <!-- Камера 1 -->
                <div class="camera-card shadow">
                    <div class="camera-header">
                        📹 Главный цех
                    </div>
                    <img src="<?= htmlspecialchars($cfg['camera_url_1'] ?? 'https://via.placeholder.com/300x200/1a1a1a/ffffff?text=Камера+1+не+настроена', ENT_QUOTES, 'UTF-8') ?>"
                         class="camera-feed"
                         alt="Камера 1"
                         onerror="this.src='https://via.placeholder.com/300x200/ff0000/ffffff?text=Ошибка+загрузки'">
                    <div class="p-2 text-white small">
                        <div class="d-flex justify-content-between">
                            <span><?= htmlspecialchars($cfg['camera_name_1'] ?? 'Камера не настроена', ENT_QUOTES, 'UTF-8') ?></span>
                            <span class="badge bg-success">● ONLINE</span>
                        </div>
                    </div>
                </div>

                <!-- Камера 2 -->
                <div class="camera-card shadow">
                    <div class="camera-header">
                        📹 Склад запчастей
                    </div>
                    <img src="<?= htmlspecialchars($cfg['camera_url_2'] ?? 'https://via.placeholder.com/300x200/1a1a1a/ffffff?text=Камера+2+не+настроена', ENT_QUOTES, 'UTF-8') ?>"
                         class="camera-feed"
                         alt="Камера 2"
                         onerror="this.src='https://via.placeholder.com/300x200/ff0000/ffffff?text=Ошибка+загрузки'">
                    <div class="p-2 text-white small">
                        <div class="d-flex justify-content-between">
                            <span><?= htmlspecialchars($cfg['camera_name_2'] ?? 'Камера не настроена', ENT_QUOTES, 'UTF-8') ?></span>
                            <span class="badge bg-success">● ONLINE</span>
                        </div>
                    </div>
                </div>

                <!-- Камера 3 -->
                <div class="camera-card shadow">
                    <div class="camera-header">
                        📹 Входная группа
                    </div>
                    <img src="<?= htmlspecialchars($cfg['camera_url_3'] ?? 'https://via.placeholder.com/300x200/1a1a1a/ffffff?text=Камера+3+не+настроена', ENT_QUOTES, 'UTF-8') ?>"
                         class="camera-feed"
                         alt="Камера 3"
                         onerror="this.src='https://via.placeholder.com/300x200/ff0000/ffffff?text=Ошибка+загрузки'">
                    <div class="p-2 text-white small">
                        <div class="d-flex justify-content-between">
                            <span><?= htmlspecialchars($cfg['camera_name_3'] ?? 'Камера не настроена', ENT_QUOTES, 'UTF-8') ?></span>
                            <span class="badge bg-success">● ONLINE</span>
                        </div>
                    </div>
                </div>

                <!-- Камера 4 -->
                <div class="camera-card shadow">
                    <div class="camera-header">
                        📹 Зона погрузки
                    </div>
                    <img src="<?= htmlspecialchars($cfg['camera_url_4'] ?? 'https://via.placeholder.com/300x200/1a1a1a/ffffff?text=Камера+4+не+настроена', ENT_QUOTES, 'UTF-8') ?>"
                         class="camera-feed"
                         alt="Камера 4"
                         onerror="this.src='https://via.placeholder.com/300x200/ff0000/ffffff?text=Ошибка+загрузки'">
                    <div class="p-2 text-white small">
                        <div class="d-flex justify-content-between">
                            <span><?= htmlspecialchars($cfg['camera_name_4'] ?? 'Камера не настроена', ENT_QUOTES, 'UTF-8') ?></span>
                            <span class="badge bg-success">● ONLINE</span>
                        </div>
                    </div>
                </div>
            </div>

            <div class="mt-4 p-3 bg-white rounded shadow">
                <h6>⚙️ Настройка камер</h6>
                <form method="POST" class="row g-3">
                    <div class="col-md-6">
                        <label class="form-label">Название камеры 1</label>
                        <input type="text" name="cfg[camera_name_1]" class="form-control" value="<?= htmlspecialchars($cfg['camera_name_1'] ?? '', ENT_QUOTES, 'UTF-8') ?>" placeholder="Например: Главный цех">
                    </div>
                    <div class="col-md-6">
                        <label class="form-label">URL потока 1</label>
                        <input type="text" name="cfg[camera_url_1]" class="form-control" value="<?= htmlspecialchars($cfg['camera_url_1'] ?? '', ENT_QUOTES, 'UTF-8') ?>" placeholder="http://ip-address/video">
                    </div>
                    <div class="col-md-6">
                        <label class="form-label">Название камеры 2</label>
                        <input type="text" name="cfg[camera_name_2]" class="form-control" value="<?= htmlspecialchars($cfg['camera_name_2'] ?? '', ENT_QUOTES, 'UTF-8') ?>" placeholder="Например: Склад запчастей">
                    </div>
                    <div class="col-md-6">
                        <label class="form-label">URL потока 2</label>
                        <input type="text" name="cfg[camera_url_2]" class="form-control" value="<?= htmlspecialchars($cfg['camera_url_2'] ?? '', ENT_QUOTES, 'UTF-8') ?>" placeholder="http://ip-address/video">
                    </div>
                    <div class="col-12">
                        <button type="submit" name="save_config" class="btn btn-primary">💾 Сохранить настройки камер</button>
                        <button type="button" onclick="refreshCameraFeeds()" class="btn btn-secondary">🔄 Обновить потоки</button>
                    </div>
                </form>
            </div>
        </div>

        <!-- Статистика -->
        <div class="tab-pane fade" id="stats">
            <h5>📊 Статистика заказов</h5>
            <div class="row mt-4">
                <div class="col-md-3"><div class="card stat-card"><div class="card-body"><h5><?= $stats['week'] ?></h5><p>За неделю</p></div></div></div>
                <div class="col-md-3"><div class="card stat-card"><div class="card-body"><h5><?= $stats['month'] ?></h5><p>За месяц</p></div></div></div>
                <div class="col-md-3"><div class="card stat-card"><div class="card-body"><h5><?= $stats['quarter'] ?></h5><p>За квартал</p></div></div></div>
                <div class="col-md-3"><div class="card stat-card"><div class="card-body"><h5><?= $stats['year'] ?></h5><p>За год</p></div></div></div>
            </div>
        </div>

        <!-- Конструктор -->
        <div class="tab-pane fade" id="settings">
            <form method="POST">
                <?php render_input('welcome_msg', 'Приветствие'); ?>
                <div class="sticky-bottom bg-white p-3 shadow-lg border-top">
                    <button type="submit" name="save_config" class="btn btn-success btn-lg">💾 Сохранить</button>
                </div>
            </form>
        </div>
    </div>
</div>

<!-- Модальное окно -->
<div class="modal fade" id="orderModal">
    <div class="modal-dialog modal-lg">
        <form method="POST" class="modal-content">
            <div class="modal-header"><h5 class="modal-title">Заказ #<span id="m_id"></span></h5><button type="button" class="btn-close" data-bs-dismiss="modal"></button></div>
            <div class="modal-body">
                <input type="hidden" name="order_id" id="input_id">
                <input type="hidden" name="update_order" value="1">
                <div class="row">
                    <div class="col-md-6">
                        <p><strong>👤</strong> <span id="m_client"></span></p>
                        <p><strong>📞 Контакт:</strong> <span id="m_phone"></span></p>
                        <p><strong>🔧 Тип:</strong> <span id="m_type"></span></p>
                        <p><strong>🚗 Авто:</strong> <span id="m_car"></span></p>
                    </div>
                    <div class="col-md-6">
                        <p><strong>⏳</strong> <span id="m_urgency"></span></p>
                        <p><strong>📸 Фото:</strong> <span id="m_photo_status"></span></p>
                        <div id="btn_photo_container" class="d-none">
                            <a href="#" id="link_photos" target="_blank" class="btn btn-warning btn-sm w-100">📂 Фото</a>
                        </div>
                    </div>
                </div>
                <div class="alert alert-secondary">
                    <strong>📝 Комментарий:</strong><br><span id="m_comment"></span>
                </div>
                <hr>
                <div class="row g-3">
                    <div class="col-md-6">
                        <label>Статус:</label>
                        <select name="status" id="select_status" class="form-select">
                            <?php foreach ($status_map as $k => $v): ?>
                                <option value="<?= $k ?>"><?= $v['text'] ?></option>
                            <?php endforeach; ?>
                        </select>
                    </div>
                    <div class="col-md-6">
                        <label>Заметка:</label>
                        <textarea name="internal_note" id="m_note" class="form-control" rows="2"></textarea>
                    </div>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Закрыть</button>
                <button type="submit" class="btn btn-primary">Сохранить</button>
            </div>
        </form>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
<script>
function updateFilters() {
    const search = document.querySelector("[name='search']").value;
    const m = document.querySelector("[name='m']").value;
    const y = document.querySelector("[name='y']").value;
    const params = new URLSearchParams();
    if (search) params.append('search', search);
    if (m) params.append('m', m);
    if (y) params.append('y', y);
    window.location.href = 'admin.php?' + params.toString();
}

function filterEngineTable() {
    const searchText = document.getElementById('engine-search').value.toLowerCase();
    const rows = document.querySelectorAll('#engine-table .engine-row');

    rows.forEach(row => {
        const brand = row.getAttribute('data-brand').toLowerCase();
        const issue = row.getAttribute('data-issue').toLowerCase();

        if (brand.includes(searchText) || issue.includes(searchText)) {
            row.style.display = '';
        } else {
            row.style.display = 'none';
        }
    });
}

function refreshCameraFeeds() {
    const feeds = document.querySelectorAll('.camera-feed');
    feeds.forEach(feed => {
        const currentSrc = feed.src;
        feed.src = currentSrc.split('?')[0] + '?t=' + new Date().getTime();
    });
}

// Автообновление камер каждые 30 секунд
setInterval(refreshCameraFeeds, 30000);

// Добавьте обработчик нажатия Enter в поле поиска
document.getElementById('engine-search').addEventListener('keypress', function(e) {
    if (e.key === 'Enter') {
        filterEngineTable();
    }
});

const modal = document.getElementById('orderModal');
modal.addEventListener('show.bs.modal', function (event) {
    const button = event.relatedTarget;
    const data = JSON.parse(button.dataset.json);
    document.getElementById('m_id').innerText = data.id;
    document.getElementById('input_id').value = data.id;
    document.getElementById('m_client').innerText = data.full_name + ' (@' + (data.username || '-') + ')';
    document.getElementById('m_type').innerText = data.order_type === 'engine_repair' ? '🔧 Ремонт двигателя' : (data.work_type || '–');

    // Извлекаем телефон из комментария для модального окна
    const comment = data.comment || '';
    let phone = '';

    if (comment) {
        // Ищем 11 цифр подряд
        const phoneMatch11 = comment.match(/\b(\d{11})\b/);
        if (phoneMatch11) {
            const phone11 = phoneMatch11[1];
            if (phone11[0] === '8' || phone11[0] === '7') {
                const digits = phone11.substring(1);
                if (digits.length === 10) {
                    phone = '+7 (' + digits.substring(0, 3) + ') ' +
                            digits.substring(3, 6) + '-' +
                            digits.substring(6, 8) + '-' +
                            digits.substring(8, 10);
                }
            }
        } else {
            // Ищем 10 цифр подряд
            const phoneMatch10 = comment.match(/\b(\d{10})\b/);
            if (phoneMatch10) {
                const phone10 = phoneMatch10[1];
                if (phone10.length === 10) {
                    phone = '+7 (' + phone10.substring(0, 3) + ') ' +
                            phone10.substring(3, 6) + '-' +
                            phone10.substring(6, 8) + '-' +
                            phone10.substring(8, 10);
                }
            }
        }
    }

    document.getElementById('m_phone').innerHTML = phone ?
        '<a href="tel:' + phone + '" class="phone-link">📞 ' + phone + '</a>' :
        '<span class="text-muted">–</span>';

    if (data.order_type === 'engine_repair') {
        let html = '';
        if (data.car_brand) html += '<strong>Марка:</strong> ' + data.car_brand + '<br>';
        if (data.car_year) html += '<strong>Год:</strong> ' + data.car_year + '<br>';
        if (data.engine_issue) html += '<strong>Проблема:</strong> ' + data.engine_issue;
        document.getElementById('m_car').innerHTML = html || '–';
    } else {
        let html = '';
        if (data.dimensions_info) html += '<strong>Размеры:</strong> ' + data.dimensions_info + '<br>';
        if (data.conditions) html += '<strong>Условия:</strong> ' + data.conditions;
        document.getElementById('m_car').innerHTML = html || '–';
    }

    document.getElementById('m_urgency').innerText = data.urgency || '–';
    document.getElementById('m_comment').innerText = data.comment || '–';
    document.getElementById('m_note').value = data.internal_note || '';
    document.getElementById('select_status').value = data.status;

    const photoContainer = document.getElementById('btn_photo_container');
    const photoStatus = document.getElementById('m_photo_status');
    const photoLink = document.getElementById('link_photos');

    if (data.photo_file_id && data.photo_file_id.length > 5) {
        photoStatus.innerText = 'Есть';
        photoStatus.className = 'text-success fw-bold';
        photoContainer.classList.remove('d-none');
        photoLink.href = 'admin.php?view_photos=' + data.id;
    } else {
        photoStatus.innerText = 'Нет';
        photoStatus.className = 'text-muted';
        photoContainer.classList.add('d-none');
    }
});
</script>
</body>
</html>