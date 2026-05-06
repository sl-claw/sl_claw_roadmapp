# SPLIT_REPO_GUIDE.md — Как разделить AI_sales_write на 13+ репозиториев

> **Цель:** превратить монорепо `AI_sales_write` в продуктовую структуру под тарифы SL_CLAW.

## Финальная структура GitHub (org `sl-claw`)

```
github.com/sl-claw/
├── core             PUBLIC   — MINI ($25), open-source ядро
├── starter          PRIVATE  — CORE ($300), модули поверх core
├── pro              PRIVATE  — PRO ($600), multi-tenant + heartbeat + аналитика
├── niche-realestate PRIVATE  — PRO niche, входит в $600 на выбор
├── niche-construction PRIVATE
├── niche-ecommerce  PRIVATE
├── niche-services   PRIVATE
├── niche-edu        PRIVATE
├── niche-clinics    PRIVATE  — premium $129 a-la-carte
├── niche-restaurants PRIVATE — premium $79 a-la-carte
├── niche-saas       PRIVATE  — premium $129 a-la-carte
├── niche-b2b        PRIVATE  — premium $99 a-la-carte
├── niche-beauty     PRIVATE  — premium $79 a-la-carte
├── access-service   PRIVATE  — биллинг + GitHub team invite
└── sl_claw_roadmapp PUBLIC   — этот сайт (уже есть)
```

---

## Маппинг файлов: что куда идёт

### `sl-claw/core` (public, MINI $25) — голое ядро

**Цель:** open-source проект-магнит. Запускается из коробки. Намеренно ограничен.

| Откуда | Куда | Зачем в core |
|---|---|---|
| `app/api/main.py` | `app/api/main.py` | FastAPI входная точка |
| `app/core/agent.py` | `app/core/agent.py` | LangGraph граф |
| `app/core/stages.py` | `app/core/stages.py` | 7 стадий воронки |
| `app/core/prompts.py` | `app/core/prompts.py` | базовый системный промпт (без всех запретов) |
| `app/core/config.py` | `app/core/config.py` | минимум переменных env |
| `app/core/state.py` | `app/core/state.py` | TypedDict для LangGraph |
| `app/core/runtime.py` | `app/core/runtime.py` | runtime helpers |
| `app/core/notifier.py` | `app/core/notifier.py` | базовые уведомления |
| `app/channels/base.py` | `app/channels/base.py` | абстракция канала |
| `app/channels/web.py` | `app/channels/web.py` | WebSocket чат |
| `app/channels/telegram.py` | `app/channels/telegram.py` | базовый Telegram (без админ-команд) |
| `app/tools/__init__.py` | `app/tools/__init__.py` | минимальный набор tools |
| `app/tools/rag.py` | `app/tools/rag.py` | **базовый** vector search (без multi-query, без re-rank) |
| `app/tools/crm.py` | `app/tools/crm.py` | только локальная БД (без внешних CRM) |
| `app/tools/unknown.py` | `app/tools/unknown.py` | mark_question_unknown |
| `app/memory/store.py` | `app/memory/store.py` | mem0 self-hosted |
| `app/db/models.py` | `app/db/models.py` | базовый набор: Lead, MessageLog, Niche (минимум) |
| `app/db/session.py` | `app/db/session.py` | async session |
| `scripts/ingest_catalog.py` | `scripts/ingest_catalog.py` | загрузка каталога |
| `scripts/demo_catalog.json` | `scripts/demo_catalog.json` | 5 demo-товаров |
| `docker/Dockerfile` | `docker/Dockerfile` | образ |
| `docker/postgres-init/` | `docker/postgres-init/` | расширение pgvector |
| `docker-compose.yml` | `docker-compose.yml` | postgres + redis + app |
| `pyproject.toml` | `pyproject.toml` | минимум зависимостей |
| `.env.example` | `.env.example` | минимум полей |
| `tests/test_stages.py` | `tests/test_stages.py` | базовый тест |
| `README.md` | `README.md` | переписать по шаблону |

**В core НЕ копируем** (специально):
- WhatsApp / Instagram / Voice каналы → starter
- prompt_profiles / heartbeat / group_nudge / proactive_sales → pro
- Stripe / payments / advanced CRM → starter
- /setdemo / crawler с PDF / Vision → pro
- Ниши/ (knowledge база) → niche-* репо
- chat_llm.py / chat_prompts.py / chat_modality.py / chat_proactive.py — per-chat overrides → pro
- tenants.py (multi-tenant) → pro

---

### `sl-claw/starter` (private, CORE $300)

**Цель:** модули которые накатываются поверх `sl-claw/core`. CORE-студент клонирует core и starter рядом, запускает `installer/install.sh`.

```
sl-claw/starter/
├── README.md
├── installer/
│   └── install.sh                  ← копирует modules/* в core/app/modules/
├── modules/
│   ├── channels/
│   │   ├── whatsapp.py             ← из app/channels/whatsapp.py
│   │   ├── instagram.py            ← из app/channels/instagram.py
│   │   ├── voice.py                ← из app/channels/voice.py
│   │   └── _voice_pipeline.py      ← из app/channels/_voice_pipeline.py
│   ├── rag_pro/
│   │   └── __init__.py             ← переписать app/tools/rag.py с multi-query + re-rank
│   ├── payments/
│   │   ├── liqpay.py               ← новый
│   │   ├── fondy.py                ← новый
│   │   ├── wayforpay.py            ← новый
│   │   ├── monobank.py             ← новый
│   │   ├── paypal.py               ← новый
│   │   ├── stripe.py               ← из app/tools/stripe_tool.py
│   │   └── invoice_pdf.py          ← новый
│   ├── crm/
│   │   ├── hubspot.py              ← из app/tools/crm.py (extract)
│   │   ├── pipedrive.py            ← из app/tools/crm.py (extract)
│   │   └── keycrm.py               ← новый
│   ├── prompts_v2/
│   │   ├── sales_master.py         ← из app/core/prompts.py (расширенная версия с запретами)
│   │   └── deflections.py          ← из app/core/deflections.py
│   ├── stt/
│   │   └── __init__.py             ← из app/core/stt.py
│   ├── vision/
│   │   └── __init__.py             ← из app/core/vision.py
│   └── chat_settings/
│       ├── chat_llm.py             ← из app/core/chat_llm.py
│       └── chat_prompts.py         ← из app/core/chat_prompts.py
└── scripts/
    ├── bulk_train.py               ← из scripts/bulk_train.py
    └── ingest_external.py          ← из scripts/ingest_external.py
```

**Лицензия:** SL-CLAW Commercial v1.0 (header в каждом .py файле).

---

### `sl-claw/pro` (private, PRO $600)

**Цель:** multi-tenant + проактив + аналитика + auto-onboarding. PRO-студент уже имеет core+starter, добавляет pro.

```
sl-claw/pro/
├── README.md
├── installer/install.sh
├── modules/
│   ├── multi_tenant/
│   │   └── tenants.py              ← из app/core/tenants.py
│   ├── proactive/
│   │   ├── heartbeat.py            ← из app/core/heartbeat.py
│   │   ├── group_nudge.py          ← из app/core/group_nudge.py
│   │   ├── proactive_sales.py     ← из app/core/proactive_sales.py
│   │   ├── digest.py               ← из app/core/digest.py
│   │   └── chat_proactive.py       ← из app/core/chat_proactive.py
│   ├── onboarding/
│   │   ├── setdemo.py              ← из app/tools/demo.py
│   │   ├── crawler.py              ← из app/tools/ingest.py (полная версия с PDF/Vision)
│   │   ├── persona_generator.py    ← новый (Sonnet генерит TenantPersona из crawl)
│   │   └── seller_distill.py       ← из app/core/seller_distill.py
│   ├── analytics/
│   │   ├── dashboard.py            ← новый Streamlit
│   │   ├── queries.sql             ← 5 готовых SQL
│   │   └── lead_scoring.py         ← новый
│   ├── handoff/
│   │   ├── escalate_to_human.py    ← из app/tools/handoff.py
│   │   ├── create_task.py          ← из app/tools/handoff.py
│   │   └── notifier.py             ← из app/core/notifier.py (расширенный)
│   ├── prompt_profiles/
│   │   └── __init__.py             ← из app/core/prompt_profiles.py
│   ├── chat_modality/
│   │   └── __init__.py             ← из app/core/chat_modality.py
│   ├── attachments/
│   │   └── __init__.py             ← из app/core/attachments.py
│   ├── media/
│   │   └── __init__.py             ← из app/tools/media.py + media_assets.py
│   ├── kp_generator/
│   │   └── pdf.py                  ← новый (для шаблонов КП)
│   └── web_search/
│       └── __init__.py             ← из app/tools/web_search.py
├── templates/
│   ├── client_presentation.pptx    ← новый (для пресейла)
│   ├── invoice_template.html       ← новый
│   ├── contract_template.docx      ← новый (договор внедрения)
│   └── kp_template.docx            ← новый (КП)
├── docs/
│   └── how-to-sell-ai-agents.md   ← новый, контент модуля 7
└── tests/                          ← тесты multi-tenant и heartbeat
```

---

### `sl-claw/niche-{slug}` (private, PRO ниши)

**Цель:** готовая ниша под конкретный бизнес. Студент при покупке PRO выбирает ОДНУ нишу из 5 базовых.

Пример: `sl-claw/niche-realestate`

```
sl-claw/niche-realestate/
├── meta.yaml                       ← версия, автор, deps (см. NICHE_MVP.md)
├── README.md
├── persona.py                      ← TenantPersona под недвижимость
├── catalog-demo.json               ← 80 demo-объявлений (студент удалит)
├── knowledge/
│   ├── objections-ua.md            ← 30 объекций про эскроу/налоги/ипотеку
│   ├── spin-realestate.md          ← SPIN-вопросы под недвижимость
│   ├── meddpicc.md                 ← B2B квалификация
│   ├── cases-ua.md                 ← 12 реальных кейсов
│   └── tone-realestate.md          ← стиль риэлтора
├── prompts/
│   ├── system-realestate.txt       ← кастомизация системного промпта
│   └── cta-phrases.md              ← CTA по стадиям
├── integrations/
│   ├── bitrix24_realestate.py      ← интеграция Bitrix24 для риэлторов
│   └── jenseits_mls.py             ← MLS-импорт объектов
└── media/
    └── preview.jpg                  ← превью для Marketplace
```

**Источник контента:** `Ниши/Ниша Продажа спец.техники /` уже содержит objections_core.md, spin_discovery_core.md, meddpicc_core.md — это шаблоны для всех ниш. Расширяете под каждую.

---

### `sl-claw/access-service` (private, новый)

**Цель:** биллинг и автоматизация выдачи доступов.

```
sl-claw/access-service/
├── app/
│   ├── api/
│   │   ├── webhooks/
│   │   │   ├── lemonsqueezy.py    ← обработчик платёжки $25 / $300 / $600 / $1600
│   │   │   ├── liqpay.py
│   │   │   └── stripe.py
│   │   ├── github.py               ← invite в team
│   │   ├── discord.py              ← присвоение role
│   │   └── email.py                ← welcome-email
│   └── core/
│       ├── tier_resolver.py        ← по сумме оплаты определяет tier
│       └── github_api.py
├── docker/
└── README.md
```

---

## Команды для разделения

### Шаг 1. Создать репозитории на GitHub

```bash
# Под org sl-claw создаёте через gh CLI
gh repo create sl-claw/core --public  --description "SL_CLAW core: AI sales agent (MIT)"
gh repo create sl-claw/starter --private --description "SL_CLAW starter modules (CORE \$300)"
gh repo create sl-claw/pro --private --description "SL_CLAW PRO: multi-tenant + heartbeat (\$600)"
gh repo create sl-claw/niche-realestate --private
gh repo create sl-claw/niche-construction --private
gh repo create sl-claw/niche-ecommerce --private
gh repo create sl-claw/niche-services --private
gh repo create sl-claw/niche-edu --private
gh repo create sl-claw/niche-clinics --private
gh repo create sl-claw/niche-restaurants --private
gh repo create sl-claw/niche-saas --private
gh repo create sl-claw/niche-b2b --private
gh repo create sl-claw/niche-beauty --private
gh repo create sl-claw/access-service --private
```

### Шаг 2. Запустить `split_repo.sh`

Скрипт автоматически копирует файлы по маппингу выше, инициализирует git, создаёт первый коммит и пушит в GitHub.

```bash
cd /path/to/AI_sales_write
bash /path/to/split_repo.sh
```

Скрипт лежит рядом с этим документом — `split_repo.sh`.

### Шаг 3. Проверить что в каждом репо

```bash
gh repo clone sl-claw/core /tmp/core-test
cd /tmp/core-test
docker compose up -d postgres redis
poetry install
poetry run uvicorn app.api.main:app --port 8070
curl http://localhost:8070/health  # должен вернуть {"status":"ok"}
```

Если core стартует чисто из коробки — успех. Тоже самое с starter (поверх core), pro (поверх core+starter), niche-* (поверх core+starter).

---

## Стратегия split: subtree vs filter-branch vs cp

**Не рекомендую** `git filter-branch` и `git subtree` для первичного разделения — они сохраняют историю коммитов, но создают много шума при первом split'е.

**Рекомендую** простой `cp` + новый `git init`:

1. История остаётся в `vimana-tcg/AI_sales_write` (приватный backup)
2. В `sl-claw/core`, `starter`, `pro` начинаем с чистого первого коммита
3. Дальше развитие — через нормальные PRs

**Потом** (если захотите) можно через `git subtree split` мигрировать историю — но это после первого запуска.

---

## Что трогать в коде при копировании

### Имена импортов остаются те же

`from app.core.agent import build_sales_agent` — работает в core.  
`from app.modules.heartbeat import heartbeat_loop` — работает в pro (после установки installer'ом).

### `app/api/main.py` — lifespan-хук читает MODULES_ENABLED

```python
# в core/app/api/main.py
async def lifespan(app):
    settings = get_settings()
    # ...

    # Загружаем модули из app/modules/ (если есть после установки starter/pro)
    modules_dir = Path("app/modules")
    if modules_dir.exists():
        from app.core.module_loader import load_modules
        loaded = load_modules(settings.modules_enabled)
        log.info(f"Loaded modules: {list(loaded.keys())}")
```

`module_loader.py` нужно добавить в core (см. ARCHITECTURE.md §6.2).

### `pyproject.toml` — разделить зависимости

- core: минимум (langgraph, fastapi, pgvector, anthropic, openai, mem0)
- starter: + httpx (для WA/IG), pipecat-ai, pypdf, trafilatura
- pro: + streamlit, alembic
- niche-*: только meta.yaml + декларативные файлы (без Python зависимостей)

### Webhooks: Telegram-каналы и платежи

`app/channels/telegram.py` — 1488 строк сейчас. Большая часть это **админ-команды** (`/settings`, `/train`, `/answer`, `/setdemo`). Их вынести в pro.

**В core** оставить только базовый Telegram: receive message → агент → reply.

В starter добавить `/train` и `/answer` (обучение).  
В pro добавить `/setdemo` и админ-панель.

---

## Что делать с папкой `Ниши/` из текущего AI_sales_write

Она содержит реальные niche-данные (Хенкель Україна, Спец.техника). Это:
- НЕ переносится в core/starter/pro
- Каждая ниша становится либо **базой для шаблона** (например, niche-construction), либо отдельным private репо для конкретного клиента

Текущие 2 ниши в папке:
1. `Ниша Продажа спец.техники` → шаблон для `sl-claw/niche-construction`
2. `Хенкель Україна Adhesive B2B` → → шаблон для `sl-claw/niche-b2b`

Знание (`objections_core.md`, `spin_discovery_core.md`, `meddpicc_core.md`) — общее, копируется как `knowledge/_core/` в каждый niche-репо.

---

## Roadmap разделения (для команды)

| День | Задача | Owner |
|---|---|---|
| 1 | Создать 14 репо в `sl-claw` org через `gh CLI` | CTO |
| 1 | Запустить `split_repo.sh` (создаёт `dist/` с готовыми пакетами) | CTO |
| 2 | Локально протестировать core: docker compose up + uvicorn → /health=ok | CTO |
| 2 | Push core в GitHub, написать чистый README | CTO |
| 3 | Тест starter: clone core + clone starter + ./install.sh + полный набор каналов | CTO |
| 3 | Push starter | CTO |
| 4 | Тест pro: + multi-tenant + heartbeat | CTO |
| 4 | Push pro | CTO |
| 5 | Создать 5 базовых niche-* репо (realestate, construction, ecommerce, services, edu) | CTO + контент-команда |
| 6 | Создать 5 premium niche-* (clinics, restaurants, saas, b2b, beauty) | контент-команда |
| 7 | access-service skeleton | CTO |
| 7 | Финальная проверка: новый студент клонит → MINI flow до конца работает | QA |

**Дедлайн:** 2026-06-15 — все 13 репо в проде, MINI можно продавать.

---

## Что ещё в этой папке

- **`split_repo.sh`** — рабочий скрипт. Запускается из корня AI_sales_write. Создаёт `dist/core`, `dist/starter`, `dist/pro` и все `dist/niche-*`.
- **`split_repo_mapping.yaml`** (опц.) — маппинг файлов в формате yaml, можно править без изменения скрипта.

---

> Last updated: 2026-05-06  
> Owner: COREVIA FLOW · CTO  
> Status: ready to execute · ETA первого split: 2026-05-13
