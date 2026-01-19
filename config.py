import os
from dotenv import load_dotenv

load_dotenv()

BOT_TOKEN = os.getenv("BOT_TOKEN")
DB_HOST = os.getenv("DB_HOST")
DB_USER = os.getenv("DB_USER")
DB_PASS = os.getenv("DB_PASS")
DB_NAME = os.getenv("DB_NAME")

ADMIN_PANEL_PASSWORD = os.getenv("ADMIN_PANEL_PASSWORD")
BOT_ADMIN_PASSWORD = os.getenv("BOT_ADMIN_PASSWORD")
