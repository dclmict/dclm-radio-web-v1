<?php
header("Content-Type: text/html");
header("Expires: 0");
header("Last-Modified: " . gmdate("D, d M Y H:i:s") . " GMT");
header("Cache-Control: no-store, no-cache, must-revalidate");
header("Cache-Control: post-check=0, pre-check=0", false);
header("Pragma: no-cache");

$languages = include 'assets/libs/languages.php';

$slug = trim(parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH), '/');
$slug = strtolower($slug);
$slug = preg_replace('/\.php$/', '', $slug);
$slug = preg_replace('/[^a-z]/', '', $slug);

if (!isset($languages[$slug])) {
    header('Location: /');
    exit;
}

$lang = $languages[$slug];

include 'assets/libs/player.php';
