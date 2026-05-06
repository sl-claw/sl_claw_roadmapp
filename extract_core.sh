#!/usr/bin/env bash
# extract_core.sh — извлекает MINI-core из AI_sales_write в dist/core/
# Запускать ИЗ корня AI_sales_write: bash ../claw-site/extract_core.sh
#
# Что делает:
#  1. Создаёт dist/core/ рядом с AI_sales_write/
#  2. Копирует только файлы для MINI (базовый бот: web + telegram + RAG + CRM)
#  3. Патчит app/api/main.py — убирает WhatsApp/Instagram/Voice/heartbeat/digest/group_nudge/proactive_sales
#  4. Пишет stripped app/tools/__init__.py (только rag/crm/unknown)
#  5. Пишет README.md и .env.example
#  6. Проверяет что Python-импорты работают

set -euo pipefail

SRC="$(pwd)"
DIST="$SRC/../dist/core"

# Sanity check
if [ ! -d "$SRC/app/core" ] || [ ! -f "$SRC/pyproject.toml" ]; then
  echo "❌ Запусти из корня AI_sales_write/ (там где app/ и pyproject.toml)"
  exit 1
fi

echo "📂 Source: $SRC"
echo "📦 Target: $DIST"
echo ""

# Очистка предыдущего dist/core
if [ -d "$DIST" ]; then
  echo "🗑  Удаляю старый $DIST"
  rm -rf "$DIST"
fi

mkdir -p "$DIST"

# ============================================================================
# Шаг 1. Копирование файлов
# ============================================================================
echo "📋 Копирую файлы..."

# app/__init__.py
mkdir -p "$DIST/app"
cp "$SRC/app/__init__.py" "$DIST/app/" 2>/dev/null || touch "$DIST/app/__init__.py"

# app/api/
mkdir -p "$DIST/app/api"
cp "$SRC/app/api/__init__.py" "$DIST/app/api/" 2>/dev/null || touch "$DIST/app/api/__init__.py"
cp "$SRC/app/api/main.py" "$DIST/app/api/"

# app/core/ — только базовые модули
mkdir -p "$DIST/app/core"
touch "$DIST/app/core/__init__.py"
for f in agent.py stages.py state.py prompts.py config.py runtime.py tenants.py telegram_ref.py; do
  cp "$SRC/app/core/$f" "$DIST/app/core/$f"
done

# app/channels/ — только web и telegram
mkdir -p "$DIST/app/channels"
touch "$DIST/app/channels/__init__.py"
cp "$SRC/app/channels/base.py" "$DIST/app/channels/"
cp "$SRC/app/channels/web.py" "$DIST/app/channels/"
cp "$SRC/app/channels/telegram.py" "$DIST/app/channels/"

# app/tools/ — только базовые
mkdir -p "$DIST/app/tools"
cp "$SRC/app/tools/rag.py" "$DIST/app/tools/"
cp "$SRC/app/tools/crm.py" "$DIST/app/tools/"
cp "$SRC/app/tools/ingest.py" "$DIST/app/tools/"
cp "$SRC/app/tools/unknown.py" "$DIST/app/tools/"

# app/db/ — целиком
cp -r "$SRC/app/db" "$DIST/app/"

# app/memory/ — целиком
cp -r "$SRC/app/memory" "$DIST/app/"

# docker/, docker-compose.yml
cp -r "$SRC/docker" "$DIST/"
cp "$SRC/docker-compose.yml" "$DIST/"

# scripts/
mkdir -p "$DIST/scripts"
cp "$SRC/scripts/ingest_catalog.py" "$DIST/scripts/"
cp "$SRC/scripts/demo_catalog.json" "$DIST/scripts/"

echo "✅ Файлы скопированы"
echo ""

# ============================================================================
# Шаг 2. Stripped app/tools/__init__.py
# ============================================================================
echo "🔧 Пишу stripped app/tools/__init__.py..."
cat > "$DIST/app/tools/__init__.py" <<'PYEOF'
"""Сборка набора tools для core-агента (MINI tier).

Только базовые tools: RAG-поиск по каталогу, CRM, обработка unknown-запросов.
Для расширенных tools (платежи/календарь/handoff/web-search) — см. extended.
"""
from __future__ import annotations

from app.core.config import Settings
from app.tools.crm import build_crm_tool
from app.tools.rag import build_rag_tool
from app.tools.unknown import build_unknown_tool


def build_tools(settings: Settings) -> list:
    return [
        build_rag_tool(settings),
        build_crm_tool(settings),
        build_unknown_tool(settings),
    ]
PYEOF
echo "✅ tools/__init__.py готов"
echo ""

# ============================================================================
# Шаг 3. Патч app/api/main.py — убираем расширенные модули
# ============================================================================
echo "🩹 Патчу app/api/main.py..."
python3 <<PYEOF
import re
p = "$DIST/app/api/main.py"
src = open(p).read()

# 1. Удаляем импорты расширенных каналов
for line in [
    "from app.channels.instagram import InstagramChannel",
    "from app.channels.voice import VoiceChannel",
    "from app.channels.whatsapp import WhatsAppChannel",
]:
    src = src.replace(line + "\n", "")

# 2. Удаляем блок static MD bulk-load с hardcoded путями к тенантам
src = re.sub(
    r'\n    # Идемпотентная подгрузка статичных knowledge.*?log\.warning\("Static MD bulk-load failed: %s", e\)\n',
    "\n",
    src, flags=re.DOTALL
)

# 3. (chat_* импорты НЕ удаляем — они работают через stub-модули)

# 4. Удаляем блоки регистрации расширенных каналов
src = re.sub(
    r'\n    if \(\n        settings\.whatsapp_phone_id.*?enabled\.append\("whatsapp.*?\n',
    "\n",
    src, flags=re.DOTALL
)
src = re.sub(
    r'\n    if settings\.instagram_page_token.*?enabled\.append\("instagram.*?\n',
    "\n",
    src, flags=re.DOTALL
)
src = re.sub(
    r'\n    if settings\.deepgram_api_key.*?enabled\.append\("voice.*?\n',
    "\n",
    src, flags=re.DOTALL
)

# 5. Удаляем фоновые задачи heartbeat/digest/group_nudge/proactive_sales
src = re.sub(
    r'\n    # Бэкграунд: proactive heartbeat.*?proactive_task\.cancel\(\)\n',
    "\n",
    src, flags=re.DOTALL
)
src = re.sub(
    r'\n    if heartbeat_task is not None:.*?proactive_task\.cancel\(\)',
    "",
    src, flags=re.DOTALL
)

# 6. Обновляем description приложения
src = src.replace(
    'description="Multi-channel AI sales agent (web/telegram/whatsapp/instagram/voice)",',
    'description="AI sales agent — MINI core (web + telegram + RAG)",'
)

# 7. Чистим тройные пустые строки
src = re.sub(r'\n\n\n+', '\n\n', src)

open(p, "w").write(src)
print("  ✅ main.py патчен (~"+str(len(src.splitlines()))+" строк)")
PYEOF

# Stub-модули для extended-фичей (агент проверяет per-chat override и
# получает None/дефолт — отрабатывает без чатовых надстроек CORE-тарифа)
echo "🩹 Создаю stub-модули для extended-фичей..."
cat > "$DIST/app/core/chat_llm.py" <<'PYEOF'
"""Stub для core (MINI). В extended (CORE) — настоящий per-chat LLM override."""
from __future__ import annotations


def get_chat_llm(chat_id: str | int | None):
    """В core override отсутствует — всегда используем глобальный LLM."""
    return None


async def load_from_db() -> None:
    """В core нечего грузить."""
    return None
PYEOF

cat > "$DIST/app/core/chat_prompts.py" <<'PYEOF'
"""Stub для core (MINI). В extended (CORE) — per-chat prompt-профиль."""
from __future__ import annotations


def get_chat_profile(chat_id: str | int | None):
    """В core override отсутствует — используем дефолтный профиль."""
    return None


async def load_from_db() -> None:
    return None
PYEOF

cat > "$DIST/app/core/prompt_profiles.py" <<'PYEOF'
"""Stub для core (MINI). В extended (CORE) — A/B prompt-профили."""
from __future__ import annotations


class _DefaultProfile:
    """Минимальный профиль: пустой style_block (не модифицирует системный промпт)."""
    style_block: str = ""


_DEFAULT = _DefaultProfile()


def get_profile(name: str | None = None) -> _DefaultProfile:
    """В core возвращаем дефолтный профиль независимо от имени."""
    return _DEFAULT
PYEOF

cat > "$DIST/app/core/chat_proactive.py" <<'PYEOF'
"""Stub для core (MINI). В extended (CORE) — per-chat proactive override."""
from __future__ import annotations


async def load_from_db() -> None:
    return None
PYEOF

cat > "$DIST/app/core/chat_modality.py" <<'PYEOF'
"""Stub для core (MINI). В extended (CORE) — per-chat modality (text/voice)."""
from __future__ import annotations


async def load_from_db() -> None:
    return None
PYEOF
echo "✅ 5 stub-модулей созданы"
echo ""
echo ""

# ============================================================================
# Шаг 4. requirements.txt (упрощённая альтернатива poetry)
# ============================================================================
echo "📝 Пишу requirements.txt..."
cat > "$DIST/requirements.txt" <<'REQEOF'
# Core agent stack
langgraph>=0.2.50,<0.3
langgraph-checkpoint-postgres>=2.0.5,<3
langchain-core>=0.3.20,<0.4
langchain-openai>=0.2.10,<0.3
langchain-anthropic>=0.3.0,<0.4
langchain-postgres>=0.0.13,<0.1
openai>=1.55.0
anthropic>=0.39.0

# Memory
mem0ai>=0.1.50

# Web framework
fastapi>=0.115.0
uvicorn[standard]>=0.32.0
pydantic>=2.9.0
pydantic-settings>=2.6.0

# Database
sqlalchemy[asyncio]>=2.0.36
psycopg[binary,pool]>=3.2.0
asyncpg>=0.30.0

# Redis (опционально для кэша)
redis>=5.2.0

# HTTP / Telegram
httpx>=0.27.0
python-telegram-bot>=21.7

# Utils
python-dotenv>=1.0.0

# Site/PDF ingestion (для каталога)
trafilatura>=2.0.0
langchain-text-splitters>=0.3.0
beautifulsoup4>=4.12.0
pypdf>=5.0.0
REQEOF
echo "✅ requirements.txt готов"
echo ""

# ============================================================================
# Шаг 5. .env.example
# ============================================================================
echo "📝 Пишу .env.example..."
cat > "$DIST/.env.example" <<'ENVEOF'
# ============================================================
# SL_CLAW core (MINI) — переменные окружения
# ============================================================

# === Один токен ко всем AI (через token.lux-promo.com) ===
# Зарегистрируйся, пополни баланс ($5 хватит на старте), создай API-ключ.
ANTHROPIC_API_KEY=lux-...
ANTHROPIC_BASE_URL=https://token.lux-promo.com/v1
OPENAI_API_KEY=lux-...
OPENAI_BASE_URL=https://token.lux-promo.com/v1

# Модели (можно менять)
ANTHROPIC_MODEL=claude-sonnet-4-6
OPENAI_MODEL=gpt-4o-mini

# === Persona продавца (можно менять под свой бизнес) ===
SALESPERSON_NAME=Анна
SALESPERSON_ROLE=Менеджер по продажам
COMPANY_NAME=Ваша компания
COMPANY_BUSINESS=Описание вашего бизнеса
COMPANY_VALUES=Качество, скорость, надёжность

# === Telegram (опционально) ===
# Получи токен у @BotFather в Telegram (30 секунд).
# TELEGRAM_BOT_TOKEN=
# Список TG ID админов через запятую (для команды /settings).
# ADMIN_TELEGRAM_IDS=

# === База данных (берётся из docker-compose) ===
DATABASE_URL=postgresql+asyncpg://sales:sales@localhost:5432/sales
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=sales
POSTGRES_USER=sales
POSTGRES_PASSWORD=sales

# === Redis (опц.) ===
REDIS_URL=redis://localhost:6379/0

# === Логи ===
LOG_LEVEL=INFO
ENVEOF
echo "✅ .env.example готов"
echo ""

# ============================================================================
# Шаг 6. README.md
# ============================================================================
echo "📝 Пишу README.md..."
cat > "$DIST/README.md" <<'MDEOF'
# SL_CLAW core (MINI tier)

Базовый AI-продавец: LangGraph агент + RAG (pgvector) + Postgres + локальный CRM.
Каналы: Web-виджет (WebSocket) + Telegram. Один API-ключ ко всем AI через `lux-token`.

## Что внутри

```
app/
├── api/         FastAPI (точка входа)
├── core/        LangGraph агент, стадии воронки, промпты
├── channels/    web (WebSocket) + telegram
├── tools/       rag, crm, ingest, unknown
├── db/          SQLAlchemy модели + миграции
└── memory/      короткая память (сессия)

docker/          Dockerfile + postgres-init
scripts/         ingest_catalog.py + demo_catalog.json
```

## Быстрый старт (1 день до прода)

### 1. Получи lux-token
```
https://token.lux-promo.com → регистрация → пополни $5 → API Keys → Create
```

### 2. Клонируй + .env
```bash
git clone git@github.com:sl-claw/sl_claw_core.git core
cd core
cp .env.example .env
# вставь lux-token и persona в .env
```

### 3. Подними Postgres + Redis локально
```bash
docker compose up -d postgres redis
```

### 4. Установи зависимости
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 5. Запусти бота
```bash
uvicorn app.api.main:app --reload --port 8000
```

### 6. Проверь
```bash
curl http://localhost:8000/health
# {"status":"ok"}

curl http://localhost:8000/
# {"service":"sales-agent","salesperson":"Анна",...}
```

### 7. Загрузи свой каталог
```bash
python scripts/ingest_catalog.py scripts/demo_catalog.json
```

### 8. Тест в браузере (Web-виджет)
Открой `http://localhost:8000/web/chat` → пиши «Привет» → AI отвечает.

### 9. Подключи Telegram
В `.env` добавь `TELEGRAM_BOT_TOKEN=...` (получи у `@BotFather`) → перезапусти.
В Telegram пиши боту → AI отвечает.

## Что дальше

- **MINI** ($25): этот репо + 9 видео-уроков как развернуть на VPS 24/7
- **CORE** ($300, доплата $275): WhatsApp + Instagram + голос + платежи + Vision
- **PRO** ($600, доплата $300): готовый нишевой репо под твой бизнес (10 ниш)
- **INDIV** ($1600): команда настраивает за тебя + личное сопровождение

Подробности: https://sl-claw-roadmap.coreviaflow.space

## Лицензия

Закрытая. Коммерческое использование — только при покупке тарифа на token.lux-promo.com.
MDEOF
echo "✅ README.md готов"
echo ""

# ============================================================================
# Шаг 7. Проверка структуры
# ============================================================================
echo "🔍 Проверка структуры:"
echo ""
cd "$DIST"
find . -type f -not -path "./.git/*" | sort | head -40
echo "..."
echo ""
echo "📊 Итого файлов: $(find . -type f -not -path "./.git/*" | wc -l | xargs)"
echo "📊 Размер: $(du -sh . | cut -f1)"
echo ""

# ============================================================================
# Шаг 8. Проверка Python-синтаксиса главных файлов
# ============================================================================
echo "🐍 Проверка Python-синтаксиса:"
for f in app/api/main.py app/core/agent.py app/tools/__init__.py; do
  if python3 -m py_compile "$f" 2>&1; then
    echo "  ✅ $f"
  else
    echo "  ❌ $f"
  fi
done
echo ""

echo "✨ Готово! Core извлечён в $DIST"
echo ""
echo "📌 Следующие шаги:"
echo "  1. Smoke-test локально:"
echo "     cd $DIST"
echo "     docker compose up -d postgres redis"
echo "     pip install -r requirements.txt"
echo "     uvicorn app.api.main:app --port 8000"
echo "     curl http://localhost:8000/health"
echo ""
echo "  2. Push в sl-claw/sl_claw_core:"
echo "     cd $DIST"
echo "     git init -b main"
echo "     git add ."
echo "     git commit -m 'Initial: MINI core extracted from AI_sales_write'"
echo "     git remote add origin git@github.com:sl-claw/sl_claw_core.git"
echo "     git push -u origin main"
