<?php
$php_version = phpversion();
$apache_version = isset($_SERVER['SERVER_SOFTWARE']) ? $_SERVER['SERVER_SOFTWARE'] : 'Apache 2.4';
$db_info = "Disconnected";
$db_connected = false;

// Attempt MariaDB / MySQL connection
$db_users = [
    ['user' => 'root', 'pass' => ''],
    ['user' => 'admin', 'pass' => 'admin'],
    ['user' => 'root', 'pass' => 'root']
];

foreach ($db_users as $cred) {
    try {
        $m = @new mysqli("localhost", $cred['user'], $cred['pass']);
        if (!$m->connect_error) {
            $db_info = "MySQL / MariaDB " . $m->server_info . " (User: " . $cred['user'] . ")";
            $db_connected = true;
            $m->close();
            break;
        }
    } catch (Exception $e) {
        // continue trying
    }
}

if (!$db_connected) {
    $db_info = "Not connected / Offline";
}

// Discover projects in the current directory
$dirs = array_filter(glob('*'), function($f) {
    return is_dir($f) && $f !== '.' && $f !== '..';
});
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Localhost // LAMP Control</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: "Consolas", "Courier New", monospace; }
        body { background: #050505; color: #e5e7eb; padding: 40px 20px; font-size: 13px; line-height: 1.5; }
        .wrapper { max-width: 960px; margin: 0 auto; background: #0a0a0a; border: 1px solid #1a2e22; border-radius: 8px; box-shadow: 0 10px 30px rgba(0, 0, 0, 0.7); overflow: hidden; }
        .header { background: #0d1410; color: #ffffff; padding: 25px 30px; border-bottom: 2px solid #00ff66; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 15px; }
        .header h1 { font-size: 22px; font-weight: bold; color: #00ff66; letter-spacing: 1px; }
        .header .sub { font-size: 12px; color: #889988; margin-top: 4px; }
        .status-badge { display: inline-flex; align-items: center; padding: 6px 14px; border-radius: 4px; font-weight: bold; font-size: 11px; letter-spacing: 0.5px; }
        .status-online { background: #002b11; color: #00ff66; border: 1px solid #00ff66; }
        .content { padding: 30px; }
        .section { margin-bottom: 30px; }
        .section:last-child { margin-bottom: 0; }
        .section-title { font-size: 13px; font-weight: bold; color: #00ff66; border-bottom: 1px solid #1a2e22; padding-bottom: 8px; margin-bottom: 16px; text-transform: uppercase; letter-spacing: 0.75px; display: flex; justify-content: space-between; align-items: center; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 16px; }
        .box { background: #050505; border: 1px solid #16241b; padding: 18px; border-radius: 6px; }
        .box dt { font-weight: bold; color: #718096; font-size: 11px; text-transform: uppercase; margin-top: 10px; }
        .box dt:first-child { margin-top: 0; }
        .box dd { margin-bottom: 4px; color: #f3f4f6; word-break: break-all; }
        .status-ok { color: #00ff66; font-weight: bold; }
        .status-err { color: #ff5555; font-weight: bold; }
        .btn-link { display: inline-flex; align-items: center; justify-content: center; background: #003314; color: #00ff66; border: 1px solid #00ff66; text-decoration: none; padding: 8px 16px; font-size: 12px; font-weight: bold; border-radius: 4px; transition: all 0.2s ease; }
        .btn-link:hover { background: #00ff66; color: #000000; box-shadow: 0 0 12px rgba(0, 255, 102, 0.4); }
        .project-list { list-style: none; display: flex; flex-direction: column; gap: 8px; }
        .project-item { padding: 12px 16px; border: 1px solid #16241b; border-radius: 4px; display: flex; justify-content: space-between; align-items: center; background: #050505; transition: all 0.15s ease; }
        .project-item:hover { background: #0c1811; border-color: #00ff66; }
        .project-item .name { color: #ffffff; font-weight: bold; font-size: 13px; text-decoration: none; display: flex; align-items: center; gap: 8px; }
        .project-item .name:hover { color: #00ff66; }
        .project-actions { display: flex; gap: 8px; }
        .badge { background: #112217; color: #00ff66; padding: 2px 8px; border-radius: 3px; font-size: 11px; border: 1px solid #1a3a25; }
        .footer { background: #060a08; border-top: 1px solid #16241b; padding: 16px 30px; font-size: 11px; color: #64748b; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; }
        code { background: #101c14; color: #00ff66; padding: 2px 6px; border: 1px solid #1a3322; border-radius: 3px; font-size: 12px; }
    </style>
</head>
<body>

<div class="wrapper">
    <div class="header">
        <div>
            <h1>LOCAL SERVER // LAMP CONTROL</h1>
            <div class="sub">Apache2 | MariaDB/MySQL | PHP <?= htmlspecialchars($php_version) ?></div>
        </div>
        <div>
            <span class="status-badge status-online">[ONLINE]</span>
        </div>
    </div>

    <div class="content">
        <!-- Server Config -->
        <div class="section">
            <div class="section-title">
                <span>01. Server Environment</span>
            </div>
            <div class="grid">
                <div class="box">
                    <dl>
                        <dt>Web Server</dt>
                        <dd><?= htmlspecialchars($apache_version) ?></dd>
                        <dt>PHP Engine</dt>
                        <dd>PHP <?= htmlspecialchars($php_version) ?></dd>
                        <dt>Server Time</dt>
                        <dd><?= date('Y-m-d H:i:s T') ?></dd>
                    </dl>
                </div>
                <div class="box">
                    <dl>
                        <dt>Database Status</dt>
                        <dd class="<?= $db_connected ? 'status-ok' : 'status-err' ?>"><?= htmlspecialchars($db_info) ?></dd>
                        <dt>Document Root Directory</dt>
                        <dd><code>/var/www/html</code></dd>
                        <dt>Loaded PHP Extensions</dt>
                        <dd><?= count(get_loaded_extensions()) ?> extensions active</dd>
                    </dl>
                </div>
            </div>
        </div>

        <!-- Quick Access / Tools -->
        <div class="section">
            <div class="section-title">
                <span>02. Management Tools</span>
            </div>
            <div class="grid">
                <div class="box" style="display: flex; flex-direction: column; justify-content: space-between;">
                    <div>
                        <strong style="color: #ffffff; font-size: 14px;">phpMyAdmin</strong>
                        <p style="color: #889988; margin: 8px 0 16px; font-size: 12px;">Web database administration interface for MySQL / MariaDB databases.</p>
                    </div>
                    <a href="/phpmyadmin" class="btn-link" target="_blank">LAUNCH PHPMYADMIN</a>
                </div>
                <div class="box">
                    <strong style="color: #ffffff; font-size: 14px;">Default Database Accounts</strong>
                    <p style="color: #889988; margin: 8px 0 12px; font-size: 12px;">Standard local access credentials:</p>
                    <div style="background: #0d1711; padding: 10px; border-radius: 4px; border: 1px solid #16241b;">
                        <p style="margin-bottom: 4px;">User: <code>root</code> | Pass: <em>(empty or set during install)</em></p>
                        <p>User: <code>admin</code> | Pass: <code>admin</code></p>
                    </div>
                </div>
            </div>
        </div>

        <!-- Projects -->
        <div class="section">
            <div class="section-title">
                <span>03. Your Web Projects (/var/www/html)</span>
                <span class="badge"><?= count($dirs) ?> found</span>
            </div>
            <ul class="project-list">
                <?php if (empty($dirs)): ?>
                    <li class="project-item" style="color: #64748b; justify-content: center; padding: 24px;">
                        [ No project subdirectories found in /var/www/html ]
                    </li>
                <?php else: ?>
                    <?php foreach ($dirs as $dir): ?>
                        <li class="project-item">
                            <a href="/<?= urlencode($dir) ?>/" class="name" target="_blank">
                                <span>[DIR]</span> /<?= htmlspecialchars($dir) ?>
                            </a>
                            <div class="project-actions">
                                <a href="/<?= urlencode($dir) ?>/" class="btn-link" style="padding: 4px 12px; font-size: 11px;" target="_blank">OPEN</a>
                            </div>
                        </li>
                    <?php endforeach; ?>
                <?php endif; ?>
            </ul>
        </div>
    </div>

    <div class="footer">
        <div>LAMP CONTROL PANEL | LINUX</div>
        <div>ROOT: /var/www/html</div>
    </div>
</div>

</body>
</html>
