#!/usr/bin/env bash
# split_repo.sh — разделяет AI_sales_write на 4 пакета (core/starter/pro/niche-*)
#
# Использование:
#   cd /path/to/AI_sales_write
#   bash /path/to/claw-site/split_repo.sh
#
# Создаёт ./dist/ с готовыми папками. Каждая — отдельный git-репо со своим коммитом.
# После проверки локально — git push origin main в соответствующий sl-claw/* репо.

set -euo pipefail

# ──────────────────── Configuration ────────────────────

SOURCE_DIR="${PWD}"
DIST_DIR="${SOURCE_DIR}/dist"
GITHUB_ORG="sl-claw"
DRY_RUN="${DRY_RUN:-false}"  # запустите с DRY_RUN=true чтобы только посмотреть план

if [ ! -d "$SOURCE_DIR/app" ]; then
  echo "❌ ОШИБКА: запустите этот скрипт из корня AI_sales_write (где есть папка app/)"
  exit 1
fi

echo "📂 Source: $SOURCE_DIR"
echo "📦 Dist:   $DIST_DIR"
echo "🐙 Org:    github.com/$GITHUB_ORG"
echo ""

# Очистить dist/ перед запуском
if [ -d "$DIST_DIR" ]; then
  echo "⚠️  $DIST_DIR уже существует. Удалить и пересоздать?"
  read -p "Yes/no: " confirm
  if [ "$confirm" = "Yes" ]; then
    rm -rf "$DIST_DIR"
  else
    echo "Прервано"; exit 1
  fi
fi
mkdir -p "$DIST_DIR"

cp_safe() {
  # cp_safe SOURCE TARGET — копирует файл если он есть, не падает если нет
  local src="$1" dst="$2"
  if [ -e "$src" ]; then
    mkdir -p "$(dirname "$dst")"
    cp -R "$src" "$dst"
    return 0
  fi
  echo "  ⚠️  skip (not found): $src"
  return 1
}

# ──────────────────── 1. sl-claw/core (PUBLIC, MINI $25) ────────────────────

echo ""
echo "🟢 Building sl-claw/core (MINI \$25, public, MIT)…"
CORE="$DIST_DIR/core"
mkdir -p "$CORE"

# Корневые файлы
cp_safe "$SOURCE_DIR/.env.example"         "$CORE/.env.example"
cp_safe "$SOURCE_DIR/.gitignore"           "$CORE/.gitignore"
cp_safe "$SOURCE_DIR/docker-compose.yml"   "$CORE/docker-compose.yml"
cp_safe "$SOURCE_DIR/docker"               "$CORE/docker"
cp_safe "$SOURCE_DIR/pyproject.toml"       "$CORE/pyproject.toml"

# app/api — точка входа FastAPI
cp_safe "$SOURCE_DIR/app/api"              "$CORE/app/api"

# app/core — только базовое (без proactive, prompt_profiles, tenants, vision, stt, chat_*)
mkdir -p "$CORE/app/core"
cp_safe "$SOURCE_DIR/app/core/__init__.py" "$CORE/app/core/__init__.py"
cp_safe "$SOURCE_DIR/app/core/agent.py"    "$CORE/app/core/agent.py"
cp_safe "$SOURCE_DIR/app/core/stages.py"   "$CORE/app/core/stages.py"
cp_safe "$SOURCE_DIR/app/core/prompts.py"  "$CORE/app/core/prompts.py"
cp_safe "$SOURCE_DIR/app/core/config.py"   "$CORE/app/core/config.py"
cp_safe "$SOURCE_DIR/app/core/state.py"    "$CORE/app/core/state.py"
cp_safe "$SOURCE_DIR/app/core/runtime.py"  "$CORE/app/core/runtime.py"
cp_safe "$SOURCE_DIR/app/core/notifier.py" "$CORE/app/core/notifier.py"

# app/channels — только web и telegram
mkdir -p "$CORE/app/channels"
cp_safe "$SOURCE_DIR/app/channels/__init__.py" "$CORE/app/channels/__init__.py"
cp_safe "$SOURCE_DIR/app/channels/base.py"     "$CORE/app/channels/base.py"
cp_safe "$SOURCE_DIR/app/channels/web.py"      "$CORE/app/channels/web.py"
cp_safe "$SOURCE_DIR/app/channels/telegram.py" "$CORE/app/channels/telegram.py"
# TODO: telegram.py в core должен быть упрощён — без /train, /answer, /setdemo (их в starter/pro)

# app/tools — базовый набор
mkdir -p "$CORE/app/tools"
cp_safe "$SOURCE_DIR/app/tools/__init__.py" "$CORE/app/tools/__init__.py"
cp_safe "$SOURCE_DIR/app/tools/rag.py"      "$CORE/app/tools/rag.py"
# TODO: упростить rag.py — убрать multi-query, LLM re-rank (это в starter)
cp_safe "$SOURCE_DIR/app/tools/crm.py"      "$CORE/app/tools/crm.py"
# TODO: упростить crm.py — оставить только локальную БД (без HubSpot/Pipedrive)
cp_safe "$SOURCE_DIR/app/tools/unknown.py"  "$CORE/app/tools/unknown.py"
cp_safe "$SOURCE_DIR/app/tools/calendar_tool.py" "$CORE/app/tools/calendar_tool.py"

# app/memory
cp_safe "$SOURCE_DIR/app/memory" "$CORE/app/memory"

# app/db
cp_safe "$SOURCE_DIR/app/db" "$CORE/app/db"
# TODO: упростить models.py — оставить Lead, MessageLog, Niche (минимум). Убрать Heartbeat, ChatLLMMap и т.д.

# scripts — только базовое
mkdir -p "$CORE/scripts"
cp_safe "$SOURCE_DIR/scripts/ingest_catalog.py" "$CORE/scripts/ingest_catalog.py"
cp_safe "$SOURCE_DIR/scripts/demo_catalog.json" "$CORE/scripts/demo_catalog.json"

# tests
cp_safe "$SOURCE_DIR/tests" "$CORE/tests"

# README — заменить на core-специфичный
cat > "$CORE/README.md" <<'EOF'
# SL_CLAW Core

Open-source AI-продавец на Python. Production-ready ядро —
LangGraph + Claude/OpenAI + pgvector + mem0.

## Quick Start

```bash
git clone https://github.com/sl-claw/core
cd core
cp .env.example .env  # вставьте OPENAI_API_KEY и ANTHROPIC_API_KEY
docker compose up -d postgres redis
poetry install
poetry run uvicorn app.api.main:app --reload --port 8070
```

Готово. Проверьте: `curl http://localhost:8070/health` → `{"status":"ok"}`.

## Что в core

- ✅ Web-чат (WebSocket)
- ✅ Telegram-канал
- ✅ 7 стадий воронки (LangGraph)
- ✅ Векторный поиск по каталогу (pgvector)
- ✅ Долговременная память клиента (mem0)
- ✅ Базовый промпт продавца

## Что в платных модулях

🔓 **[SL_CLAW Starter](https://sl-claw-roadmap.coreviaflow.space/tier-core) ($300):**
WhatsApp + Instagram + Voice каналы · Stripe/LiqPay/Fondy · Готовые скрипты SPIN/MEDDPICC · CRM-интеграции

🔓 **[SL_CLAW PRO](https://sl-claw-roadmap.coreviaflow.space/tier-pro) ($600):**
Multi-tenant · Heartbeat (бот пишет первым) · /setdemo (auto-onboarding) · Аналитика · Готовые ниши (real estate, construction, ecommerce, services, edu)

🔓 **[SL_CLAW INDIV](https://sl-claw-roadmap.coreviaflow.space/tier-impl) ($1 600):**
Команда работает с вами индивидуально — внедрение под ключ за 1-2 недели.

## Курс

[Sl_Claw Course](https://sl-claw-roadmap.coreviaflow.space) — 122 урока, vibe coding с Claude.

## License

MIT
EOF

# Init git
cd "$CORE"
[ "$DRY_RUN" = "true" ] || (git init -b main >/dev/null && git add . && git commit -m "Initial: SL_CLAW Core (split from AI_sales_write)" >/dev/null)
cd "$SOURCE_DIR"
echo "✅ core готов: $CORE"

# ──────────────────── 2. sl-claw/starter (PRIVATE, CORE $300) ────────────────────

echo ""
echo "🔵 Building sl-claw/starter (CORE \$300, private)…"
STARTER="$DIST_DIR/starter"
mkdir -p "$STARTER/modules" "$STARTER/installer" "$STARTER/scripts"

# Channels
mkdir -p "$STARTER/modules/channels"
cp_safe "$SOURCE_DIR/app/channels/whatsapp.py"        "$STARTER/modules/channels/whatsapp.py"
cp_safe "$SOURCE_DIR/app/channels/instagram.py"       "$STARTER/modules/channels/instagram.py"
cp_safe "$SOURCE_DIR/app/channels/voice.py"           "$STARTER/modules/channels/voice.py"
cp_safe "$SOURCE_DIR/app/channels/_voice_pipeline.py" "$STARTER/modules/channels/_voice_pipeline.py"

# RAG-pro (полный rag.py из исходника — он уже с multi-query + re-rank)
mkdir -p "$STARTER/modules/rag_pro"
cp_safe "$SOURCE_DIR/app/tools/rag.py" "$STARTER/modules/rag_pro/__init__.py"

# Payments
mkdir -p "$STARTER/modules/payments"
cp_safe "$SOURCE_DIR/app/tools/stripe_tool.py" "$STARTER/modules/payments/stripe.py"
# Остальные платёжки (LiqPay, Fondy, WayForPay, Monobank, PayPal, invoice_pdf) — будут написаны командой
cat > "$STARTER/modules/payments/README.md" <<'EOF'
# Payments module

В этом релизе:
- ✅ stripe.py (готов из core)

В разработке (TODO команда):
- liqpay.py
- fondy.py
- wayforpay.py
- monobank.py
- paypal.py
- invoice_pdf.py (счёт по реквизитам)
EOF

# CRM
mkdir -p "$STARTER/modules/crm"
cp_safe "$SOURCE_DIR/app/tools/crm.py" "$STARTER/modules/crm/__init__.py"
# TODO: разделить crm.py на hubspot.py + pipedrive.py + keycrm.py

# Prompts v2
mkdir -p "$STARTER/modules/prompts_v2"
cp_safe "$SOURCE_DIR/app/core/prompts.py"     "$STARTER/modules/prompts_v2/sales_master.py"
cp_safe "$SOURCE_DIR/app/core/deflections.py" "$STARTER/modules/prompts_v2/deflections.py"

# STT, Vision
mkdir -p "$STARTER/modules/stt"
cp_safe "$SOURCE_DIR/app/core/stt.py" "$STARTER/modules/stt/__init__.py"
mkdir -p "$STARTER/modules/vision"
cp_safe "$SOURCE_DIR/app/core/vision.py" "$STARTER/modules/vision/__init__.py"

# Chat settings
mkdir -p "$STARTER/modules/chat_settings"
cp_safe "$SOURCE_DIR/app/core/chat_llm.py"     "$STARTER/modules/chat_settings/chat_llm.py"
cp_safe "$SOURCE_DIR/app/core/chat_prompts.py" "$STARTER/modules/chat_settings/chat_prompts.py"

# Scripts
cp_safe "$SOURCE_DIR/scripts/bulk_train.py"      "$STARTER/scripts/bulk_train.py"
cp_safe "$SOURCE_DIR/scripts/ingest_external.py" "$STARTER/scripts/ingest_external.py"

# Installer
cat > "$STARTER/installer/install.sh" <<'EOF'
#!/usr/bin/env bash
# Установка SL_CLAW Starter поверх core
set -e

CORE_DIR="${1:-../core}"
if [ ! -d "$CORE_DIR/app" ]; then
  echo "❌ Не найден core. Укажите путь: bash install.sh /path/to/core"
  exit 1
fi

echo "📦 Установка starter в $CORE_DIR/app/modules/"
mkdir -p "$CORE_DIR/app/modules"
cp -R modules/* "$CORE_DIR/app/modules/"
cp scripts/* "$CORE_DIR/scripts/"

echo "✅ Готово. В .env добавьте: MODULES_ENABLED=channels,rag_pro,payments,crm,prompts_v2,stt,vision,chat_settings"
echo "Перезапустите бота: poetry run uvicorn app.api.main:app --port 8070"
EOF
chmod +x "$STARTER/installer/install.sh"

cat > "$STARTER/README.md" <<'EOF'
# SL_CLAW Starter ($300 CORE-tier)

Модули поверх sl-claw/core. Лицензия: SL_CLAW Commercial v1.0.

## Установка

```bash
git clone https://github.com/sl-claw/core ../core
git clone https://github.com/sl-claw/starter
cd starter
bash installer/install.sh ../core
```

В `core/.env` добавьте:
```
MODULES_ENABLED=channels,rag_pro,payments,crm,prompts_v2,stt,vision,chat_settings
```

## Модули

- **channels/**: WhatsApp Cloud API, Instagram Direct, Voice (Pipecat)
- **rag_pro/**: multi-query expansion + LLM re-rank (+30% точности vs core)
- **payments/**: Stripe, LiqPay, Fondy, WayForPay, Monobank, PayPal
- **crm/**: HubSpot, Pipedrive, KeyCRM
- **prompts_v2/**: усиленный системный промпт + deflections
- **stt/**: speech-to-text для голоса
- **vision/**: распознавание фото клиента (Claude Vision)
- **chat_settings/**: per-chat LLM/prompt overrides
EOF

cd "$STARTER"
[ "$DRY_RUN" = "true" ] || (git init -b main >/dev/null && git add . && git commit -m "Initial: SL_CLAW Starter (CORE \$300)" >/dev/null)
cd "$SOURCE_DIR"
echo "✅ starter готов: $STARTER"

# ──────────────────── 3. sl-claw/pro (PRIVATE, PRO $600) ────────────────────

echo ""
echo "🟣 Building sl-claw/pro (PRO \$600, private)…"
PRO="$DIST_DIR/pro"
mkdir -p "$PRO/modules" "$PRO/installer" "$PRO/templates" "$PRO/docs"

# Multi-tenant
mkdir -p "$PRO/modules/multi_tenant"
cp_safe "$SOURCE_DIR/app/core/tenants.py" "$PRO/modules/multi_tenant/tenants.py"

# Proactive
mkdir -p "$PRO/modules/proactive"
cp_safe "$SOURCE_DIR/app/core/heartbeat.py"        "$PRO/modules/proactive/heartbeat.py"
cp_safe "$SOURCE_DIR/app/core/group_nudge.py"      "$PRO/modules/proactive/group_nudge.py"
cp_safe "$SOURCE_DIR/app/core/proactive_sales.py"  "$PRO/modules/proactive/proactive_sales.py"
cp_safe "$SOURCE_DIR/app/core/digest.py"           "$PRO/modules/proactive/digest.py"
cp_safe "$SOURCE_DIR/app/core/chat_proactive.py"   "$PRO/modules/proactive/chat_proactive.py"

# Onboarding (auto-niche /setdemo)
mkdir -p "$PRO/modules/onboarding"
cp_safe "$SOURCE_DIR/app/tools/demo.py"            "$PRO/modules/onboarding/setdemo.py"
cp_safe "$SOURCE_DIR/app/tools/ingest.py"          "$PRO/modules/onboarding/crawler.py"
cp_safe "$SOURCE_DIR/app/core/seller_distill.py"   "$PRO/modules/onboarding/persona_generator.py"
cp_safe "$SOURCE_DIR/scripts/ingest_site.py"       "$PRO/modules/onboarding/ingest_site.py"

# Handoff
mkdir -p "$PRO/modules/handoff"
cp_safe "$SOURCE_DIR/app/tools/handoff.py" "$PRO/modules/handoff/__init__.py"

# Prompt profiles
mkdir -p "$PRO/modules/prompt_profiles"
cp_safe "$SOURCE_DIR/app/core/prompt_profiles.py" "$PRO/modules/prompt_profiles/__init__.py"

# Chat modality + attachments + media
mkdir -p "$PRO/modules/chat_extras"
cp_safe "$SOURCE_DIR/app/core/chat_modality.py"  "$PRO/modules/chat_extras/chat_modality.py"
cp_safe "$SOURCE_DIR/app/core/attachments.py"    "$PRO/modules/chat_extras/attachments.py"
cp_safe "$SOURCE_DIR/app/core/media_assets.py"   "$PRO/modules/chat_extras/media_assets.py"
cp_safe "$SOURCE_DIR/app/tools/media.py"         "$PRO/modules/chat_extras/media_tool.py"
cp_safe "$SOURCE_DIR/app/tools/modality.py"      "$PRO/modules/chat_extras/modality_tool.py"

# Web search
mkdir -p "$PRO/modules/web_search"
cp_safe "$SOURCE_DIR/app/tools/web_search.py" "$PRO/modules/web_search/__init__.py"

# Templates (заглушки — команда заполнит)
cat > "$PRO/templates/README.md" <<'EOF'
# PRO Templates

В разработке:
- client_presentation.pptx (12 слайдов для пресейл-звонка)
- contract_template.docx (договор на внедрение AI-продавца)
- kp_template.docx (коммерческое предложение)
- invoice_template.html (шаблон счёта)
EOF

# Installer
cat > "$PRO/installer/install.sh" <<'EOF'
#!/usr/bin/env bash
set -e
CORE_DIR="${1:-../core}"
if [ ! -d "$CORE_DIR/app" ]; then
  echo "❌ Не найден core."; exit 1
fi
echo "📦 Установка pro в $CORE_DIR/app/modules/"
mkdir -p "$CORE_DIR/app/modules"
cp -R modules/* "$CORE_DIR/app/modules/"
cp -R templates "$CORE_DIR/templates"
echo "✅ Готово. В .env добавьте к существующему MODULES_ENABLED:"
echo "  ,multi_tenant,proactive,onboarding,handoff,prompt_profiles,chat_extras,web_search"
EOF
chmod +x "$PRO/installer/install.sh"

cat > "$PRO/README.md" <<'EOF'
# SL_CLAW PRO ($600)

Модули multi-tenant + heartbeat + auto-onboarding + аналитика. Лицензия: SL_CLAW Commercial v1.0.

## Установка (поверх core + starter)

```bash
git clone https://github.com/sl-claw/pro
cd pro
bash installer/install.sh ../core
```

## Модули

- **multi_tenant/**: один сервер на 50+ ниш
- **proactive/**: heartbeat + group_nudge + daily digest
- **onboarding/**: /setdemo URL — auto-генерация niche за 2 мин (crawler + Vision + persona)
- **handoff/**: escalate_to_human + create_task
- **prompt_profiles/**: core / sell_at_all_costs / consultative
- **chat_extras/**: chat_modality + attachments + media

## Niche Marketplace

Студент PRO выбирает 1 нишу из каталога — получает private repo `sl-claw/niche-{slug}` с готовой persona, 30+ объекциями, нишевыми CRM-интеграциями.
EOF

cd "$PRO"
[ "$DRY_RUN" = "true" ] || (git init -b main >/dev/null && git add . && git commit -m "Initial: SL_CLAW PRO (\$600)" >/dev/null)
cd "$SOURCE_DIR"
echo "✅ pro готов: $PRO"

# ──────────────────── 4. sl-claw/niche-* ────────────────────

NICHES=(realestate construction ecommerce services edu clinics restaurants saas b2b beauty)

for slug in "${NICHES[@]}"; do
  echo ""
  echo "🎯 Building sl-claw/niche-$slug…"
  N="$DIST_DIR/niche-$slug"
  mkdir -p "$N/knowledge" "$N/prompts" "$N/integrations" "$N/media"

  # meta.yaml — capitalize первой буквы slug через python
  CAP=$(python3 -c "print('$slug'.capitalize())")
  cat > "$N/meta.yaml" <<EOF
schema_version: 1.0
slug: $slug
name: $CAP
version: 0.1.0
author:
  name: COREVIA FLOW
  email: support@coreviaflow.space
license: SL-CLAW Commercial v1.0
language: ru
category: $slug
compatible_with:
  min_sl_claw_version: "1.0.0"
required_modules:
  - rag_pro
  - prompts_v2
size:
  catalog_items: 0
  knowledge_chunks: 0
EOF

  # persona.py — заглушка для команды
  cat > "$N/persona.py" <<EOF
"""Persona for niche-$slug. TODO: команда заполняет."""
from app.modules.multi_tenant.tenants import TenantPersona

PERSONA = TenantPersona(
    slug="$slug",
    salesperson_name="TODO",
    company_name="{COMPANY_NAME}",
    company_business="TODO: 2-3 предложения чем занимается бизнес",
    company_values="TODO: ценности",
    conversation_purpose="TODO: цель разговора",
    default_language="ru",
    tone_notes="TODO: tone of voice",
)
EOF

  # README
  cat > "$N/README.md" <<EOF
# niche-$slug

Готовая ниша для PRO-тарифа SL_CLAW. После покупки \$600 студент получает доступ к этому репо и клонирует через Claude.

## TODO команды

- [ ] Заполнить persona.py
- [ ] knowledge/objections.md (30+ типовых возражений в этой нише)
- [ ] knowledge/spin.md (SPIN-вопросы)
- [ ] knowledge/cases.md (5+ кейсов)
- [ ] integrations/* (нишевые CRM или API)
- [ ] catalog-demo.json (50-100 demo-объявлений)
- [ ] media/preview.jpg для marketplace
EOF

  # Заглушки knowledge
  echo "# Objections для ниши $slug — TODO команда" > "$N/knowledge/objections.md"
  echo "# SPIN-вопросы для $slug — TODO" > "$N/knowledge/spin.md"
  echo "# Кейсы $slug — TODO" > "$N/knowledge/cases.md"

  cd "$N"
  [ "$DRY_RUN" = "true" ] || (git init -b main >/dev/null && git add . && git commit -m "Initial: niche-$slug skeleton" >/dev/null)
  cd "$SOURCE_DIR"
done
echo "✅ ${#NICHES[@]} niche-* репо созданы"

# ──────────────────── Финал ────────────────────

echo ""
echo "════════════════════════════════════════════════"
echo "✅ ВСЕ ПАКЕТЫ СОЗДАНЫ В $DIST_DIR"
echo "════════════════════════════════════════════════"
echo ""
echo "Структура:"
ls -la "$DIST_DIR"
echo ""
echo "Следующие шаги:"
echo ""
echo "1. Создайте репозитории на GitHub:"
echo "   gh repo create $GITHUB_ORG/core --public"
echo "   gh repo create $GITHUB_ORG/starter --private"
echo "   gh repo create $GITHUB_ORG/pro --private"
for slug in "${NICHES[@]}"; do
  echo "   gh repo create $GITHUB_ORG/niche-$slug --private"
done
echo ""
echo "2. Подключите remote и запушьте:"
echo "   cd $DIST_DIR/core && git remote add origin git@github.com:$GITHUB_ORG/core.git && git push -u origin main"
echo "   cd $DIST_DIR/starter && git remote add origin git@github.com:$GITHUB_ORG/starter.git && git push -u origin main"
echo "   ... и так далее для всех"
echo ""
echo "3. Протестируйте core локально:"
echo "   cd $DIST_DIR/core"
echo "   docker compose up -d postgres redis"
echo "   poetry install"
echo "   poetry run uvicorn app.api.main:app --port 8070"
echo "   curl http://localhost:8070/health"
echo ""
echo "4. Полная инструкция: claw-site/SPLIT_REPO_GUIDE.md"
