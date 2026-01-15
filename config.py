# Author: Sergey Akulov
# GitHub: https://github.com/serg-akulov

import os
from dotenv import load_dotenv

# Загружаем переменные из .env файла
load_dotenv()

BOT_TOKEN = os.getenv("BOT_TOKEN")
DB_HOST = os.getenv("DB_HOST")
DB_USER = os.getenv("DB_USER")
DB_PASS = os.getenv("DB_PASS")
DB_NAME = os.getenv("DB_NAME")

ADMIN_PANEL_PASSWORD = os.getenv("ADMIN_PANEL_PASSWORD")
BOT_ADMIN_PASSWORD = os.getenv("BOT_ADMIN_PASSWORD")

GOOGLE_SHEET_CREDENTIALS = "path/to/your/service_account.json"
GOOGLE_SHEET_URL = "https://docs.google.com/spreadsheets/d/1XXXXX/edit"

CREATE TABLE IF NOT EXISTS `bot_config` (
  `key` varchar(100) NOT NULL,
  `value` text NOT NULL,
  `description` varchar(255) DEFAULT '',
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;