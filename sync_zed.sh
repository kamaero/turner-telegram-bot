#!/bin/bash

# ============================================
# Скрипт синхронизации конфигурации Zed Dev
# для проекта Turner Telegram Bot
# ============================================

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Проверки
check_zed() {
    if ! command -v zed &> /dev/null; then
        print_error "Zed Dev не установлен"
        echo "Установите: https://zed.dev/"
        exit 1
    fi
    print_success "Zed Dev установлен"
}

check_project() {
    if [ ! -f "bot.py" ] || [ ! -f "docker-compose.yml" ]; then
        print_error "Не найден проект Turner Telegram Bot"
        echo "Запустите скрипт из корневой директории проекта"
        exit 1
    fi
    print_success "Проект найден"
}

# Основная функция синхронизации
sync_zed_config() {
    print_info "Синхронизация конфигурации Zed Dev..."

    # Создаем директорию .zed
    mkdir -p .zed

    # 1. Создаем settings.json
    cat > .zed/settings.json << 'EOF'
{
  "language_servers": {
    "python": {
      "settings": {
        "python.analysis.typeCheckingMode": "basic",
        "python.analysis.autoImportCompletions": true,
        "python.analysis.diagnosticMode": "workspace"
      }
    }
  },
  "languages": {
    "Python": {
      "code_actions_on_format": {
        "source.organizeImports": true
      },
      "language_servers": ["python"]
    }
  },
  "features": {
    "inline_completion": {
      "enabled": true,
      "provider": "copilot"
    }
  },
  "project": {
    "python_interpreter": "python3"
  },
  "telemetry": {
    "diagnostics": true,
    "metrics": false
  }
}
EOF
    print_success "Создан .zed/settings.json"

    # 2. Создаем tasks.json
    cat > .zed/tasks.json << 'EOF'
{
  "tasks": [
    {
      "label": "Run Bot",
      "command": "python3 bot.py",
      "args": [],
      "cwd": "${workspace}",
      "env": {"PYTHONPATH": "${workspace}"},
      "use_new_terminal": true,
      "allow_concurrent_runs": false,
      "reveal": "always"
    },
    {
      "label": "Install Dependencies",
      "command": "pip",
      "args": ["install", "-r", "requirements.txt"],
      "cwd": "${workspace}",
      "use_new_terminal": true,
      "reveal": "always"
    },
    {
      "label": "Test Python Syntax",
      "command": "python3",
      "args": ["-m", "py_compile", "bot.py", "config.py", "database.py"],
      "cwd": "${workspace}",
      "use_new_terminal": false,
      "reveal": "never"
    },
    {
      "label": "Docker Compose Up",
      "command": "docker-compose",
      "args": ["up", "-d", "--build"],
      "cwd": "${workspace}",
      "use_new_terminal": true,
      "reveal": "always"
    },
    {
      "label": "Docker Compose Down",
      "command": "docker-compose",
      "args": ["down"],
      "cwd": "${workspace}",
      "use_new_terminal": true,
      "reveal": "always"
    },
    {
      "label": "Docker Compose Logs",
      "command": "docker-compose",
      "args": ["logs", "-f"],
      "cwd": "${workspace}",
      "use_new_terminal": true,
      "reveal": "always"
    },
    {
      "label": "Deploy to VPS",
      "command": "./deploy.sh",
      "args": [],
      "cwd": "${workspace}",
      "use_new_terminal": true,
      "reveal": "always"
    },
    {
      "label": "Sync with VPS",
      "command": "rsync",
      "args": ["-avz", "--exclude=.env", "--exclude=.git", "--exclude=.zed", "--exclude=__pycache__", "./", "root@31.31.207.220:/opt/turner-bot/"],
      "cwd": "${workspace}",
      "use_new_terminal": true,
      "reveal": "always"
    },
    {
      "label": "Git Status",
      "command": "git",
      "args": ["status"],
      "cwd": "${workspace}",
      "use_new_terminal": false,
      "reveal": "never"
    },
    {
      "label": "Git Push to Origin",
      "command": "git",
      "args": ["push", "origin", "main"],
      "cwd": "${workspace}",
      "use_new_terminal": true,
      "reveal": "always"
    },
    {
      "label": "Git Pull from Origin",
      "command": "git",
      "args": ["pull", "origin", "main"],
      "cwd": "${workspace}",
      "use_new_terminal": true,
      "reveal": "always"
    }
  ],
  "version": "1.0.0"
}
EOF
    print_success "Создан .zed/tasks.json"

    # 3. Создаем launch.json
    cat > .zed/launch.json << 'EOF'
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Python: Debug Bot",
      "type": "python",
      "request": "launch",
      "program": "${workspaceFolder}/bot.py",
      "console": "integratedTerminal",
      "justMyCode": true,
      "env": {"PYTHONPATH": "${workspaceFolder}"},
      "args": []
    },
    {
      "name": "Python: Debug Current File",
      "type": "python",
      "request": "launch",
      "program": "${file}",
      "console": "integratedTerminal",
      "justMyCode": true,
      "env": {"PYTHONPATH": "${workspaceFolder}"}
    },
    {
      "name": "Python: Run with Docker Environment",
      "type": "python",
      "request": "launch",
      "program": "${workspaceFolder}/bot.py",
      "console": "integratedTerminal",
      "justMyCode": true,
      "envFile": "${workspaceFolder}/.env",
      "env": {
        "PYTHONPATH": "${workspaceFolder}",
        "DB_HOST": "localhost",
        "DB_NAME": "turner_bot",
        "DB_USER": "app_user",
        "DB_PASS": "app_password123"
      },
      "args": []
    }
  ]
}
EOF
    print_success "Создан .zed/launch.json"
}

# Обновление .gitignore
update_gitignore() {
    print_info "Обновление .gitignore..."

    if [ ! -f ".gitignore" ]; then
        print_warning ".gitignore не найден, создаем новый"
        cat > .gitignore << 'EOF'
# Python
__pycache__/
*.pyc
*.pyo
*.pyd
.Python
venv/
env/

# Environment
.env
.env.local
.env.production

# Database
*.db
*.sqlite
*.sqlite3

# OS
.DS_Store
Thumbs.db

# IDE
.idea/
.vscode/
*.swp
*.swo
.gigaide/
.zed/

# Logs
*.log
logs/

# Docker
.dockerignore

# Backup
*.bak
*.backup

# Secrets - НЕ ЗАГРУЖАТЬ В GIT!
*.json
!package.json
!composer.json

# Deploy instructions with sensitive data
deploy.md

sync_config.jsonc

# Test files
test_db.py
EOF
    else
        # Добавляем .zed если нет
        if ! grep -q "\.zed/" .gitignore; then
            echo ".zed/" >> .gitignore
            print_success "Добавлен .zed/ в .gitignore"
        fi

        # Добавляем test_db.py если нет
        if ! grep -q "test_db.py" .gitignore; then
            echo "test_db.py" >> .gitignore
            print_success "Добавлен test_db.py в .gitignore"
        fi
    fi

    print_success ".gitignore обновлен"
}

# Создание test_db.py
create_test_db() {
    if [ ! -f "test_db.py" ]; then
        print_info "Создание test_db.py..."
        curl -s https://raw.githubusercontent.com/kamaero/turner-telegram-bot/main/test_db.py -o test_db.py
        chmod +x test_db.py
        print_success "Создан test_db.py"
    else
        print_info "test_db.py уже существует"
    fi
}

# Создание README_ZED.md
create_readme_zed() {
    if [ ! -f "README_ZED.md" ]; then
        print_info "Создание README_ZED.md..."
        curl -s https://raw.githubusercontent.com/kamaero/turner-telegram-bot/main/README_ZED.md -o README_ZED.md
        print_success "Создан README_ZED.md"
    else
        print_info "README_ZED.md уже существует"
    fi
}

# Основная функция
main() {
    echo "==========================================="
    echo "   СИНХРОНИЗАЦИЯ КОНФИГУРАЦИИ ZED DEV"
    echo "==========================================="

    # Проверки
    check_zed
    check_project

    # Синхронизация
    sync_zed_config
    update_gitignore
    create_test_db
    create_readme_zed

    echo ""
    echo "==========================================="
    print_success "Синхронизация завершена успешно!"
    echo ""
    echo "Созданы/обновлены файлы:"
    echo "  ✓ .zed/settings.json"
    echo "  ✓ .zed/tasks.json"
    echo "  ✓ .zed/launch.json"
    echo "  ✓ .gitignore (обновлен)"
    echo "  ✓ test_db.py (если не было)"
    echo "  ✓ README_ZED.md (если не было)"
    echo ""
    echo "Следующие шаги:"
    echo "  1. Откройте проект в Zed: zed ."
    echo "  2. Настройте .env файл: cp .env.example .env"
    echo "  3. Установите зависимости: pip install -r requirements.txt"
    echo "  4. Используйте задачи: Cmd+Shift+P → 'Tasks: Run Task'"
    echo "==========================================="
}

# Запуск
main "$@"
