# NICHE_MVP.md — Технический MVP Niche Marketplace

> Спецификация формата `.niche` файла + реализация CLI `sl-claw niche` + backend `marketplace-service`. Готово к разработке командой.
>
> Цель: к **2026-07-06** студент PRO-тарифа может одной командой `sl-claw niche install niche-realestate` загрузить готовую нишу в свой инстанс sl-claw.

---

## 1. Формат файла `.niche`

### 1.1. Что это

`.niche` — это **zip-архив** с фиксированной структурой и манифестом. Используем zip (а не tar.gz) потому что:
- Кросс-платформенно (Windows тоже умеет распаковать)
- Можно посмотреть содержимое не распаковывая
- Поддерживает подписи в comment-секции

Расширение `.niche` — кастомное, чтобы файл-менеджер ассоциировал с CLI `sl-claw`.

### 1.2. Структура

```
niche-realestate-1.2.3.niche/
├── meta.yaml                  ← обязательный манифест
├── persona.py                 ← обязательный TenantPersona
├── catalog.json               ← опц., каталог товаров (JSON-массив)
├── knowledge/                 ← опц., markdown-факты
│   ├── objections.md
│   ├── spin_questions.md
│   ├── meddpicc.md
│   ├── cases.md
│   └── tone.md
├── prompts/                   ← опц., кастомные промпт-фрагменты
│   ├── tone_extension.txt
│   └── system_addon.txt
├── integrations/              ← опц., нишевые интеграции
│   └── bitrix24_realestate.py
├── media/                     ← опц., изображения для preview
│   ├── preview.jpg
│   └── examples/
│       └── demo_dialog.jpg
└── SIGNATURE                  ← обязательный (для marketplace ниш)
```

### 1.3. meta.yaml — спецификация

```yaml
# Версия схемы манифеста — менять только при breaking changes
schema_version: 1.0

# Уникальный идентификатор ниши в Marketplace
slug: realestate-ua

# Человекочитаемое название
name: Real Estate Ukraine

# Семантическая версия ниши
version: 1.2.3

# Автор
author:
  name: COREVIA FLOW
  email: support@coreviaflow.space
  url: https://coreviaflow.space

# Лицензия
license: SL-CLAW Commercial v1.0
# Возможные значения: 
#   - SL-CLAW Commercial v1.0  (платная, нельзя перепродавать)
#   - MIT, Apache-2.0, CC-BY-4.0  (для community ниш)

# Описание (1-3 предложения)
description: |
  Готовая ниша для агентств недвижимости Украины. Включает persona агента,
  каталог из 80 типовых объявлений, 30 объекций про налоги/эскроу/ипотеку,
  готовую интеграцию с Bitrix24 для риэлторов.

# Основной язык контента
language: uk
# Возможные: ru, uk, en, multi

# Категория для фильтрации в Marketplace
category: real-estate
# Возможные: real-estate, construction, ecommerce, services, edu, saas,
#           clinics, restaurants, b2b, beauty, automotive, finance, other

# Версии sl-claw, с которыми совместима ниша
compatible_with:
  min_sl_claw_version: "1.0.0"
  max_sl_claw_version: "1.99.99"

# Какие модули sl-claw нужны для работы ниши
required_modules:
  - rag_pro                   # multi-query + LLM re-rank
  - prompts_v2                # расширенные промпт-профили

# Опциональные модули (улучшают, но не обязательны)
optional_modules:
  - vision                    # для Claude Vision на фото
  - voice                     # для голосовых звонков
  - crm_bitrix24              # если хотите CRM-интеграцию

# Размер контента
size:
  catalog_items: 80
  knowledge_chunks: 200
  total_bytes: 4_500_000

# Превью для витрины
preview_image: media/preview.jpg
preview_dialog_url: https://demo.sl-claw.com/realestate

# Цена в USD (для marketplace; null для бесплатных и tier-included)
price: null  # null = включена в PRO; число = разовая покупка

# Если ниша платная — комиссия marketplace (для UGC-фазы)
marketplace_revenue_share: 0.30  # 30% маркетплейсу, 70% автору

# Подпись HMAC (генерируется автоматически при upload)
signature: "ed25519:abcdef0123456789..."

# Дата создания и обновления
created_at: "2026-05-15T10:00:00Z"
updated_at: "2026-06-12T14:30:00Z"

# Changelog последней версии
changelog: |
  v1.2.3 (2026-06-12)
  - Добавлены 5 новых возражений про эскроу
  - Обновлён tone.md под украинскую ментальность
  - Bitrix24 integration: автозаполнение поля «бюджет»
```

### 1.4. persona.py — формат

```python
"""niche-realestate-ua persona module.
This file is loaded into TENANTS dict on niche install.
"""
from app.core.tenants import TenantPersona

PERSONA = TenantPersona(
    slug="realestate-ua",  # должен совпадать с meta.yaml
    salesperson_name="Олена",  # дефолтное имя, можно переопределить в .env
    company_name="{COMPANY_NAME}",  # placeholder — заменится при установке
    company_business=(
        "Агентство недвижимости. Подбор квартир в новостройках и вторичке "
        "Киева, Львова, Одессы. Бюджет от $40k до $500k. Помощь с ипотекой "
        "(ОщадБанк, ПриватБанк), оформлением документов, эскроу-договорами."
    ),
    company_values=(
        "Прозрачность всех комиссий, быстрая верификация документов "
        "(до 3 дней), помощь с ипотекой, безопасные сделки через эскроу."
    ),
    conversation_purpose=(
        "Закрыть клиента на просмотр конкретных 3-5 объектов под его запрос "
        "и далее — на бронь под задаток. Каждое сообщение завершается "
        "конкретным CTA: «забронируем просмотр на завтра?»"
    ),
    default_language="uk",
    tone_notes=(
        "Деловой, но дружелюбный. Без эмодзи в тексте. Используй "
        "украинскую ментальность — «домівка», «затишок», «сім'я». "
        "Цены показывай в долларах ($40k), но всегда с альтернативой в "
        "гривнах по курсу НБУ на сегодня."
    ),
)
```

### 1.5. SIGNATURE — подпись пакета

Для marketplace-ниш (которые проходят модерацию) — каждый файл подписывается **Ed25519** ключом маркетплейса:

```
SIGNATURE/
├── manifest.txt        ← список всех файлов и их SHA-256
├── signature.bin       ← Ed25519 подпись manifest.txt
└── public_key.pem      ← публичный ключ автора
```

При установке `sl-claw niche install` проверяется:
1. SHA-256 каждого файла совпадает с манифестом
2. Подпись manifest.txt валидна
3. Публичный ключ — известный (либо marketplace, либо в whitelist пользователя)

---

## 2. CLI `sl-claw niche`

### 2.1. Архитектура

CLI — отдельный Python-пакет `sl-claw-cli`, ставится через pip:

```bash
pip install sl-claw-cli
```

После установки — команда `sl-claw` доступна в PATH. Подкоманда `niche` для работы с нишами:

```bash
sl-claw niche <command> [args]
```

### 2.2. Команды

```bash
# Показать список установленных ниш в текущем инстансе
sl-claw niche list

# Установить из локального файла
sl-claw niche install ~/Downloads/niche-realestate-v1.2.3.niche

# Установить с marketplace (требует lux-token и тариф PRO+)
sl-claw niche install marketplace://realestate-ua@1.2.3

# Установить последнюю версию
sl-claw niche install marketplace://realestate-ua

# Обновить установленную нишу до последней
sl-claw niche update realestate-ua

# Удалить нишу
sl-claw niche uninstall realestate-ua

# Информация о нише (метаданные, размер, статус)
sl-claw niche info realestate-ua

# Экспортировать установленную и настроенную нишу из текущего инстанса
sl-claw niche export my-tuned-realestate --output ~/Desktop/

# Опубликовать нишу в Marketplace (требует PRO+, проходит модерацию)
sl-claw niche publish my-tuned-realestate --price 99 --currency USD

# Поиск ниш в Marketplace
sl-claw niche search realestate

# Авторизация в Marketplace
sl-claw niche login --token lux-...

# Diff между двумя версиями ниши
sl-claw niche diff realestate-ua@1.2.3 realestate-ua@1.3.0
```

### 2.3. Реализация — install (Python код)

```python
# sl_claw_cli/commands/niche_install.py

import zipfile
import shutil
import subprocess
import sys
import yaml
from pathlib import Path
from typing import Optional
import httpx
import nacl.signing
import hashlib

NICHE_INSTALL_DIR = Path("./app/modules/niches")
SL_CLAW_VERSION = "1.0.0"
MARKETPLACE_API = "https://api.lux-promo.com/v1/marketplace"

class NicheInstallError(Exception):
    pass


def install_niche(source: str, lux_token: Optional[str] = None) -> str:
    """Install a niche from a local file or marketplace URL.

    Returns: slug of installed niche.
    """
    # 1. Resolve source → local path
    if source.startswith("marketplace://"):
        if not lux_token:
            raise NicheInstallError("Marketplace install requires lux-token. "
                                    "Set LUX_TOKEN env or pass --token")
        local_path = _download_from_marketplace(source, lux_token)
    elif Path(source).exists():
        local_path = Path(source)
    else:
        raise NicheInstallError(f"Niche source not found: {source}")

    # 2. Extract to temp dir
    import tempfile
    tmp_dir = Path(tempfile.mkdtemp(prefix="sl_claw_niche_"))
    with zipfile.ZipFile(local_path, "r") as zf:
        zf.extractall(tmp_dir)

    # 3. Validate meta.yaml
    meta_path = tmp_dir / "meta.yaml"
    if not meta_path.exists():
        raise NicheInstallError("meta.yaml not found in archive")

    with open(meta_path) as f:
        meta = yaml.safe_load(f)

    _validate_meta(meta)
    _validate_compatibility(meta, SL_CLAW_VERSION)

    # 4. Validate signature (for marketplace niches)
    if (tmp_dir / "SIGNATURE").exists():
        _verify_signature(tmp_dir, meta)

    # 5. Install: copy files to app/modules/niches/<slug>/
    target = NICHE_INSTALL_DIR / meta["slug"]
    if target.exists():
        # Already installed — backup before overwrite
        backup = NICHE_INSTALL_DIR / f"{meta['slug']}.bak.{int(time.time())}"
        shutil.move(str(target), str(backup))
        print(f"⚠️  Existing niche backed up to {backup}")

    target.mkdir(parents=True, exist_ok=True)
    shutil.copytree(tmp_dir, target, dirs_exist_ok=True)

    # 6. Register persona in TenantPersona registry (DB)
    _register_persona_in_db(meta["slug"], target / "persona.py")

    # 7. Bulk-train markdown facts to RAG (pgvector)
    knowledge_dir = target / "knowledge"
    if knowledge_dir.exists():
        for md in knowledge_dir.glob("*.md"):
            print(f"📚 Indexing {md.name}…")
            subprocess.run(
                ["python", "scripts/bulk_train.py", meta["slug"], str(md)],
                check=True,
            )

    # 8. Ingest catalog to RAG
    catalog = target / "catalog.json"
    if catalog.exists():
        print(f"📦 Indexing catalog ({meta['size']['catalog_items']} items)…")
        subprocess.run(
            ["python", "scripts/ingest_catalog.py", str(catalog)],
            check=True,
        )

    # 9. Hot-reload sl-claw container (если запущен)
    _hot_reload_container()

    # 10. Cleanup
    shutil.rmtree(tmp_dir)

    print(f"✅ Niche '{meta['slug']}' v{meta['version']} installed")
    return meta["slug"]


def _validate_meta(meta: dict) -> None:
    required_fields = ["schema_version", "slug", "name", "version", "license"]
    for field in required_fields:
        if field not in meta:
            raise NicheInstallError(f"meta.yaml missing required field: {field}")
    if meta["schema_version"] not in ("1.0",):
        raise NicheInstallError(f"Unsupported schema version: {meta['schema_version']}")


def _validate_compatibility(meta: dict, current_version: str) -> None:
    from packaging import version as v
    compat = meta.get("compatible_with", {})
    min_v = compat.get("min_sl_claw_version", "0.0.0")
    max_v = compat.get("max_sl_claw_version", "999.999.999")
    cur = v.parse(current_version)
    if not (v.parse(min_v) <= cur <= v.parse(max_v)):
        raise NicheInstallError(
            f"Niche requires sl-claw {min_v}-{max_v}, you have {current_version}"
        )


def _verify_signature(tmp_dir: Path, meta: dict) -> None:
    """Verify Ed25519 signature of the niche package."""
    sig_dir = tmp_dir / "SIGNATURE"

    # Read manifest
    manifest = (sig_dir / "manifest.txt").read_text()

    # Verify each file's hash
    for line in manifest.strip().split("\n"):
        expected_sha, fname = line.split("  ", 1)
        actual = hashlib.sha256((tmp_dir / fname).read_bytes()).hexdigest()
        if actual != expected_sha:
            raise NicheInstallError(f"File hash mismatch: {fname}")

    # Verify signature
    pubkey_pem = (sig_dir / "public_key.pem").read_text()
    signature = (sig_dir / "signature.bin").read_bytes()
    pubkey = nacl.signing.VerifyKey(_parse_pem_pubkey(pubkey_pem))
    try:
        pubkey.verify(manifest.encode(), signature)
    except nacl.exceptions.BadSignatureError:
        raise NicheInstallError("Invalid signature on niche package")


def _download_from_marketplace(url: str, lux_token: str) -> Path:
    # marketplace://realestate-ua@1.2.3 → fetch from API
    parts = url.replace("marketplace://", "").split("@")
    slug = parts[0]
    version = parts[1] if len(parts) > 1 else "latest"

    response = httpx.get(
        f"{MARKETPLACE_API}/niches/{slug}/{version}/download",
        headers={"Authorization": f"Bearer {lux_token}"},
        timeout=60,
    )
    if response.status_code == 402:
        raise NicheInstallError("Niche requires PRO tier. Upgrade at "
                                "https://token.lux-promo.com/upgrade")
    if response.status_code == 404:
        raise NicheInstallError(f"Niche not found: {slug}@{version}")
    response.raise_for_status()

    download_dir = Path.home() / ".sl-claw" / "downloads"
    download_dir.mkdir(parents=True, exist_ok=True)
    local_path = download_dir / f"{slug}-{version}.niche"
    local_path.write_bytes(response.content)
    return local_path


def _register_persona_in_db(slug: str, persona_py: Path) -> None:
    """Load persona from .py file and INSERT into niches table."""
    # Dynamically import the persona module
    spec = importlib.util.spec_from_file_location(f"niche_{slug}", persona_py)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    persona: TenantPersona = module.PERSONA

    # Insert into DB (skip if exists)
    from app.db.session import sync_session
    from app.db.models import Niche
    with sync_session() as session:
        existing = session.get(Niche, slug)
        if existing:
            print(f"⚠️  Niche '{slug}' already in DB, updating…")
            existing.salesperson_name = persona.salesperson_name
            existing.company_business = persona.company_business
            # ... update all fields
        else:
            niche = Niche(
                slug=persona.slug,
                salesperson_name=persona.salesperson_name,
                company_name=persona.company_name,
                company_business=persona.company_business,
                company_values=persona.company_values,
                conversation_purpose=persona.conversation_purpose,
                default_language=persona.default_language,
                tone_notes=persona.tone_notes,
            )
            session.add(niche)
        session.commit()


def _hot_reload_container() -> None:
    """Trigger reload of running sl-claw process."""
    # Touch a sentinel file that uvicorn watches with --reload
    # OR use a HTTP endpoint for explicit reload
    import httpx
    try:
        httpx.post("http://localhost:8070/_admin/reload", timeout=5)
        print("🔄 sl-claw reloaded")
    except Exception:
        print("⚠️  Could not reload running process. Restart manually.")
```

### 2.4. Реализация — export

```python
# sl_claw_cli/commands/niche_export.py

import zipfile
import yaml
import shutil
from pathlib import Path
from datetime import datetime, timezone

def export_niche(slug: str, output_dir: Path) -> Path:
    """Pack a niche from current sl-claw installation into a .niche file."""
    src = Path(f"./app/modules/niches/{slug}")
    if not src.exists():
        raise FileNotFoundError(f"Niche not installed: {slug}")

    # 1. Read or update meta.yaml with current version
    meta_path = src / "meta.yaml"
    with open(meta_path) as f:
        meta = yaml.safe_load(f)

    # Bump patch version
    major, minor, patch = meta["version"].split(".")
    meta["version"] = f"{major}.{minor}.{int(patch) + 1}"
    meta["updated_at"] = datetime.now(timezone.utc).isoformat()

    # 2. Pull latest persona from DB (in case it was edited via /settings)
    persona = _get_persona_from_db(slug)
    _persist_persona_py(src / "persona.py", persona)

    # 3. Pull RAG chunks (manual + facts) — re-export to knowledge/*.md
    _export_knowledge_to_md(slug, src / "knowledge")

    # 4. Pull catalog (if exists in DB) — export to catalog.json
    _export_catalog_to_json(slug, src / "catalog.json")

    # 5. Update meta.yaml with new size stats
    meta["size"] = _calculate_size(src)
    with open(meta_path, "w") as f:
        yaml.safe_dump(meta, f, allow_unicode=True)

    # 6. Create signature (Ed25519 with user's local key)
    _sign_niche(src)

    # 7. Pack into .niche zip
    output_dir.mkdir(parents=True, exist_ok=True)
    out_file = output_dir / f"{slug}-{meta['version']}.niche"
    with zipfile.ZipFile(out_file, "w", zipfile.ZIP_DEFLATED) as zf:
        for path in src.rglob("*"):
            if path.is_file():
                arcname = path.relative_to(src)
                zf.write(path, arcname)

    print(f"✅ Exported {slug} v{meta['version']} → {out_file}")
    return out_file


def _export_knowledge_to_md(slug: str, target_dir: Path) -> None:
    """Pull all manual+facts chunks for this slug from RAG and re-write as md."""
    target_dir.mkdir(exist_ok=True)
    from app.tools.rag import fetch_chunks_by_source
    for source_type in ("manual", "facts", "pdf_facts"):
        chunks = fetch_chunks_by_source(slug=slug, source=source_type)
        if not chunks:
            continue
        md_path = target_dir / f"{source_type}_dump.md"
        with open(md_path, "w") as f:
            for chunk in chunks:
                f.write(chunk["text"])
                f.write("\n\n---\n\n")


def _export_catalog_to_json(slug: str, target_path: Path) -> None:
    from app.tools.rag import fetch_catalog_by_slug
    catalog = fetch_catalog_by_slug(slug)
    if not catalog:
        return
    import json
    target_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2))
```

---

## 3. Backend: `marketplace-service`

### 3.1. Архитектура

Отдельный микросервис на FastAPI + Postgres + S3.

```
marketplace-service/
├── app/
│   ├── api/
│   │   ├── niches.py       ← публичный каталог
│   │   ├── upload.py       ← загрузка автором
│   │   ├── download.py     ← скачивание (с проверкой PRO)
│   │   ├── purchase.py     ← покупка отдельной ниши
│   │   └── moderation.py   ← модерация (admin only)
│   ├── core/
│   │   ├── auth.py         ← интеграция с lux-token
│   │   ├── storage.py      ← S3 wrapper для .niche файлов
│   │   ├── signing.py      ← Ed25519 подписи пакетов
│   │   └── tier.py         ← проверка тарифа пользователя
│   └── db/
│       └── models.py       ← Niche, NicheVersion, Purchase
├── docker-compose.yml
└── pyproject.toml
```

### 3.2. Database schema

```sql
-- Каждая ниша в маркетплейсе
CREATE TABLE niches (
    id BIGSERIAL PRIMARY KEY,
    slug VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(50) NOT NULL,
    description TEXT,
    language VARCHAR(10) NOT NULL,
    author_user_id VARCHAR(100) NOT NULL,
    author_name VARCHAR(255),
    license VARCHAR(50) NOT NULL,
    price_usd NUMERIC(10, 2),  -- NULL = включена в тариф
    included_in_tier VARCHAR(20),  -- mini/core/pro/null
    moderation_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    -- Возможные: pending, approved, rejected, deprecated
    moderation_notes TEXT,
    preview_image_url TEXT,
    preview_dialog_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Каждая версия ниши
CREATE TABLE niche_versions (
    id BIGSERIAL PRIMARY KEY,
    niche_id BIGINT NOT NULL REFERENCES niches(id),
    version VARCHAR(20) NOT NULL,  -- semver: 1.2.3
    s3_key VARCHAR(500) NOT NULL,  -- путь к .niche файлу в S3
    file_size_bytes BIGINT NOT NULL,
    sha256 CHAR(64) NOT NULL,
    signature_b64 TEXT,  -- Ed25519 подпись
    changelog TEXT,
    download_count INT DEFAULT 0,
    is_latest BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(niche_id, version)
);

-- Покупки отдельных ниш (для тех что не в тарифе)
CREATE TABLE niche_purchases (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(100) NOT NULL,
    niche_id BIGINT NOT NULL REFERENCES niches(id),
    price_paid_usd NUMERIC(10, 2) NOT NULL,
    payment_id VARCHAR(100),  -- id транзакции в платёжке
    purchased_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, niche_id)
);

-- История скачиваний (для аналитики)
CREATE TABLE niche_downloads (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(100) NOT NULL,
    niche_id BIGINT NOT NULL REFERENCES niches(id),
    version VARCHAR(20) NOT NULL,
    user_tier VARCHAR(20),  -- mini/core/pro/impl
    downloaded_at TIMESTAMPTZ DEFAULT NOW(),
    ip_address INET
);

-- Доходы авторов (для Phase 2 UGC)
CREATE TABLE author_payouts (
    id BIGSERIAL PRIMARY KEY,
    author_user_id VARCHAR(100) NOT NULL,
    niche_id BIGINT NOT NULL REFERENCES niches(id),
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    purchases_count INT NOT NULL,
    gross_revenue_usd NUMERIC(10, 2) NOT NULL,
    marketplace_fee_usd NUMERIC(10, 2) NOT NULL,
    author_share_usd NUMERIC(10, 2) NOT NULL,
    paid_at TIMESTAMPTZ,
    UNIQUE(author_user_id, niche_id, period_start)
);
```

### 3.3. API endpoints

```python
# app/api/niches.py

from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Optional

router = APIRouter(prefix="/api/v1/marketplace")


@router.get("/niches")
async def list_niches(
    category: Optional[str] = None,
    language: Optional[str] = None,
    search: Optional[str] = None,
    skip: int = 0,
    limit: int = 50,
):
    """Public catalog of approved niches."""
    # Returns: list of niches with preview info, no download URLs
    ...


@router.get("/niches/{slug}")
async def get_niche(slug: str):
    """Public details of one niche."""
    # Returns: full meta, all versions, preview, NOT download URL
    ...


@router.get("/niches/{slug}/{version}/download")
async def download_niche(
    slug: str,
    version: str,
    user = Depends(get_user_from_lux_token),  # decode lux-token from Bearer
):
    """Generate signed S3 URL for downloading a niche.
    
    Authorization checks:
    1. user has PRO+ tier OR
    2. user has explicit purchase of this niche
    
    Returns: signed S3 URL valid for 5 minutes.
    """
    niche = await get_niche_or_404(slug)
    niche_version = await get_version_or_404(niche.id, version)

    # Authorization
    has_access = (
        user.tier in ("pro", "impl")  # included in tier
        and (niche.included_in_tier in ("pro", None) or
             niche.included_in_tier == "core" and user.tier in ("core", "pro", "impl"))
    ) or await has_purchased(user.id, niche.id)

    if not has_access:
        raise HTTPException(
            status_code=402,
            detail=f"Niche requires PRO tier or explicit purchase. "
                   f"Buy at https://token.lux-promo.com/marketplace/{slug}",
        )

    # Generate signed S3 URL
    download_url = await s3_client.generate_signed_url(
        niche_version.s3_key,
        expires_in=300,
    )

    # Log download
    await log_download(user.id, niche.id, version, user.tier)

    return {
        "download_url": download_url,
        "sha256": niche_version.sha256,
        "size_bytes": niche_version.file_size_bytes,
    }


@router.post("/niches/{slug}/{version}/upload")
async def upload_niche(
    slug: str,
    version: str,
    file: UploadFile,
    user = Depends(get_user_from_lux_token),
):
    """Upload new version of niche (author only)."""
    if user.tier not in ("pro", "impl"):
        raise HTTPException(status_code=402, detail="Publishing requires PRO+")

    # Validate file
    if not file.filename.endswith(".niche"):
        raise HTTPException(400, "File must be .niche format")

    # Read and validate
    content = await file.read()
    if len(content) > 100 * 1024 * 1024:  # 100MB limit
        raise HTTPException(413, "Niche too large")

    # Extract meta.yaml from zip
    import io, zipfile, yaml
    zf = zipfile.ZipFile(io.BytesIO(content))
    meta = yaml.safe_load(zf.read("meta.yaml").decode())

    # Authorization: only author can upload new versions of their niche
    niche = await get_niche_by_slug(slug)
    if niche and niche.author_user_id != user.id:
        raise HTTPException(403, "You are not the author of this niche")

    # Compute hash and sign
    sha256 = hashlib.sha256(content).hexdigest()
    signature = sign_with_marketplace_key(content)

    # Upload to S3
    s3_key = f"niches/{slug}/{version}.niche"
    await s3_client.put_object(s3_key, content)

    # Insert/update DB
    if not niche:
        niche = await create_niche(slug, meta, user.id, status="pending")
    await create_version(niche.id, version, s3_key, sha256, signature, meta)

    return {"slug": slug, "version": version, "moderation_status": "pending"}


@router.post("/niches/{slug}/purchase")
async def purchase_niche(
    slug: str,
    payment_provider: str,  # liqpay/fondy/paypal/stripe
    user = Depends(get_user_from_lux_token),
):
    """Initiate purchase of an a-la-carte niche."""
    niche = await get_niche_or_404(slug)
    if niche.included_in_tier and user.tier in ("pro", "impl"):
        raise HTTPException(409, "Niche already included in your tier")

    # Generate payment link
    payment = await create_payment(
        provider=payment_provider,
        amount=niche.price_usd,
        currency="USD",
        description=f"Niche: {niche.name}",
        user_id=user.id,
        metadata={"niche_id": niche.id, "slug": slug},
    )
    return {"payment_url": payment.url, "payment_id": payment.id}


@router.post("/webhook/payment")
async def payment_webhook(payload: dict):
    """Triggered by payment provider on successful payment."""
    if payload["status"] != "success":
        return {"ok": True}

    metadata = payload["metadata"]
    user_id = metadata["user_id"]
    niche_id = metadata["niche_id"]

    await create_purchase(user_id, niche_id, payload["amount_usd"], payload["payment_id"])

    # Phase 2: компенсация автору
    niche = await get_niche_by_id(niche_id)
    if niche.author_user_id != "corevia-flow":  # not platform-owned
        author_share = payload["amount_usd"] * (1 - niche.marketplace_revenue_share)
        await accumulate_author_payout(niche.author_user_id, niche_id, author_share)

    return {"ok": True}
```

---

## 4. Web UI на token.lux-promo.com

### 4.1. Страницы

```
token.lux-promo.com/
├── /cabinet/niches            ← мои установленные + доступные по тарифу
├── /marketplace               ← публичный каталог всех ниш
├── /marketplace/<slug>        ← страница ниши с описанием, кейсами, ценой
├── /marketplace/upload        ← форма загрузки (для авторов)
└── /marketplace/payouts       ← дашборд автора с заработком
```

### 4.2. /cabinet/niches — структура UI

```
┌─────────────────────────────────────────────────────────────────────┐
│ 📦 Niches in your tier (PRO)                                         │
├─────────────────────────────────────────────────────────────────────┤
│  🏘 Real Estate UA  v1.2.3   ✅ installed   [Update] [Export] [Info] │
│  🚧 Construction    v2.1.0   ⚪ available   [Install] [Info]         │
│  🛒 E-commerce      v1.5.2   ⚪ available   [Install] [Info]         │
│  🛠 Services        v1.0.1   ⚪ available   [Install] [Info]         │
│  📚 Education       v1.3.0   ⚪ available   [Install] [Info]         │
├─────────────────────────────────────────────────────────────────────┤
│ 🛒 Available a-la-carte                                              │
├─────────────────────────────────────────────────────────────────────┤
│  🏥 Clinics         v1.0.0   $99    [Buy] [Preview]                  │
│  🍽 Restaurants     v1.0.0   $79    [Buy] [Preview]                  │
│  💼 SaaS            v1.0.0   $129   [Buy] [Preview]                  │
└─────────────────────────────────────────────────────────────────────┘
```

При клике [Install]:
- Окно с командой для копирования: `sl-claw niche install marketplace://realestate-ua@1.2.3`
- Кнопка [Copy command]
- Кнопка [Run on my server] — выполнит install через SSH (если у пользователя сохранён SSH-доступ к его серверу)

При клике [Export]:
- Окно с командой: `sl-claw niche export realestate-ua --output ~/Desktop/`
- Кнопка [Download .niche from server] — backend скачает через SSH

---

## 5. Безопасность

### 5.1. Защита от кражи кода

`.niche` файл — это zip с Python-кодом. Любой кто получил файл может его распаковать и читать. Защита:

1. **Watermark в коде** — каждая ниша при выдаче подписывается уникальным `INSTALL_ID` (UUID4) пользователя. INSTALL_ID встраивается в `meta.yaml` и в комментарий внутри `persona.py`. Если ниша утечёт публично — мы можем восстановить кто слил.

2. **DMCA-friendly лицензия** — `SL-CLAW Commercial v1.0` запрещает перепродажу и публикацию. Это дает нам право на DMCA takedown с GitHub/Reddit/etc.

3. **Auto-revoke** — если в логах backend замечаем массовое скачивание одной ниши с разных IP за короткий период (> 5 IP за 1 час) — автоматически блокируем lux-token до выяснения.

### 5.2. Защита от вредоносных ниш

`.niche` содержит Python код (`persona.py` + опц. `integrations/*.py`). Это потенциальная RCE.

Защита:

1. **Модерация** — все ниши в Marketplace проходят ручную модерацию перед публикацией. Команда модераторов проверяет:
   - persona.py содержит ТОЛЬКО `TenantPersona` — никаких import os, subprocess, eval, exec
   - integrations/ — только httpx-вызовы к whitelisted доменам (CRM API)
   - meta.yaml — без подозрительных полей

2. **AST sandbox** — на стороне CLI при install — парсим persona.py через `ast` и проверяем что там нет:
   - `import os`, `import sys`, `import subprocess`
   - `eval`, `exec`, `compile`
   - Доступа к файловой системе вне `app/modules/niches/<slug>/media/`

3. **Подпись marketplace-ключом** — даже если кто-то модифицировал `.niche` после скачивания, при следующем `install` подпись не сойдётся → CLI откажет установить.

4. **Whitelist для UGC** — для Phase 2 (когда PRO-юзеры публикуют ниши) — разрешены только определённые типы интеграций (без выполнения произвольного кода).

---

## 6. Roadmap разработки

### Phase 1: MVP для запуска PRO (ETA: 2026-07-06)

| Этап | Дата | Задача |
|---|---|---|
| 1 | 2026-06-01 | Спецификация формата `.niche` (этот документ) |
| 2 | 2026-06-03 | Реализация core классов: `NicheLoader`, `NicheValidator`, `NicheSigner` |
| 3 | 2026-06-08 | CLI `sl-claw-cli` с командами install/export/list/info |
| 4 | 2026-06-10 | Backend `marketplace-service` skeleton (FastAPI + Postgres) |
| 5 | 2026-06-12 | S3-storage для .niche файлов |
| 6 | 2026-06-15 | API endpoints: list, get, download (с auth по lux-token) |
| 7 | 2026-06-18 | Упаковка 5 базовых ниш (realestate, construction, ecommerce, services, edu) в .niche |
| 8 | 2026-06-22 | Web UI: /cabinet/niches с витриной |
| 9 | 2026-06-25 | Web UI: /marketplace public catalog |
| 10 | 2026-06-29 | Тестирование install/export pipeline на 10 пользователях бета-теста |
| 11 | 2026-07-03 | Багфиксы по результатам беты |
| 12 | 2026-07-06 | 🚀 **Запуск PRO с включённым Niche Marketplace** |

### Phase 2: A-la-carte (ETA: 2026-08-01)

- Интеграция с LiqPay / Fondy / Stripe для покупки отдельных ниш ($79-129)
- Эндпоинт `/niches/{slug}/purchase`
- Создание 3 отдельных ниш: clinics ($99), restaurants ($79), saas ($129)

### Phase 3: UGC Marketplace (ETA: 2026-09-01)

- Эндпоинт `/niches/upload` для PRO-юзеров
- Модерация (Discord-бот для уведомления модератора, ручное review в течение 24-48 ч)
- `/marketplace/payouts` — дашборд автора
- Автоматические выплаты раз в месяц через Stripe Connect или вручную через Wise
- Marketing campaign среди PRO-студентов: «Заработайте на ваших нишах»

---

## 7. Метрики успеха

### Технические

- **Время install** — от команды до working niche: **<60 секунд** (включая bulk_train)
- **Размер .niche файла** — медиана **<5 MB**, P99 **<30 MB**
- **Backend latency** — list <100ms, download <200ms (без передачи файла)
- **Reload time** sl-claw после install — **<10 секунд**

### Бизнес

- **Phase 1 (первые 30 дней после запуска):**
  - 100% PRO-студентов установили хотя бы 1 нишу
  - В среднем 2.5 ниш на студента
  - 0 жалоб на потерю данных при install/export

- **Phase 2 (a-la-carte, через 3 мес):**
  - 30% PRO-студентов купили хотя бы 1 a-la-carte нишу
  - $50/мес средняя выручка с одного PRO-студента сверх тарифа

- **Phase 3 (UGC, через 6 мес):**
  - 10 авторов опубликовали свои ниши
  - $5000/мес в Marketplace UGC-секции
  - 70/30 split = $3500 авторам, $1500 нам

---

## 8. Open questions для команды

1. **Хранилище:** AWS S3 vs Cloudflare R2 vs Backblaze B2? R2 без egress fees — но нужна интеграция с подписанными URL.
2. **Подпись:** Ed25519 (быстро, маленькая подпись) vs RSA-4096 (классика, поддержка везде)?
3. **Versioning:** semver или date-based (2026.07.06)? Semver лучше для UGC.
4. **Hot-reload:** auto через uvicorn --reload или явный POST /_admin/reload? Второе безопаснее.
5. **Кэш на стороне CLI:** где хранить downloaded .niche файлы? `~/.sl-claw/cache/`?

---

> Last updated: 2026-05-04  
> Owner: COREVIA FLOW  
> Status: Phase 1 spec ready · CLI implementation pending · Backend skeleton pending
