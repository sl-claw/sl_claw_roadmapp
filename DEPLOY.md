# Деплой sclaw.coreviaflow.space через Coolify

Сайт раздаётся на subdomain: `https://sclaw.coreviaflow.space`. Coolify уже стоит на `deploy-pro.coreviaflow.space`. Деплой = 5 шагов, ~10 минут.

## 1. Запушить в Git

```bash
cd "/Users/mac/Desktop/Разработки /AI Робот Продажник/claw-site"

git init
git add .
git commit -m "Initial claw site"
git branch -M main

# Репо: github.com/sl-claw/sl_claw_roadmapp (создан заранее)
git remote add origin git@github.com:sl-claw/sl_claw_roadmapp.git
git push -u origin main
```

## 2. Настроить DNS

В DNS-провайдере домена `coreviaflow.space` добавьте A-запись:

```
Type:   A
Name:   sclaw
Value:  <IP вашего Coolify-сервера>
TTL:    Auto (или 3600)
```

Узнать IP сервера:
```bash
dig deploy-pro.coreviaflow.space +short
```

Подождать 1–10 минут пока DNS обновится:
```bash
dig sclaw.coreviaflow.space +short
# должен вернуть тот же IP
```

## 3. Создать ресурс в Coolify

Откройте `https://deploy-pro.coreviaflow.space`.

В нужном проекте: **+ New → Resource**:

- **Public Repository** (если репо публичный)
- **Private Repository (with GitHub App)** (если приватный — потребуется одноразовая авторизация Coolify в GitHub)

Параметры:

| Поле | Значение |
|---|---|
| Repository URL | `https://github.com/sl-claw/sl_claw_roadmapp` |
| Branch | `main` |
| Build Pack | **Docker Compose** |
| Base Directory | `/` (пусто) |
| Docker Compose Location | `/docker-compose.yml` |

**Continue / Save**.

## 4. Настроить домен в Coolify

В созданном ресурсе → **Configuration → Domains**.

Для сервиса `claw-site` в поле **Domains**:
```
https://sclaw.coreviaflow.space
```

Порт `80` подтянется автоматически из `EXPOSE 80` в Dockerfile.

**Save**.

## 5. Deploy

Большая зелёная кнопка **Deploy** справа сверху.

Coolify:
1. Склонирует репо
2. Соберёт Docker-образ
3. Запустит контейнер
4. Traefik подцепит домен `sclaw.coreviaflow.space`
5. Let's Encrypt выпишет TLS-сертификат
6. Healthcheck позеленеет

Логи — вкладка **Logs**. ~1–2 минуты.

## Проверка

```bash
curl -I https://sclaw.coreviaflow.space
# HTTP/2 200, server: nginx
```

В браузере:
- `https://sclaw.coreviaflow.space` → главная
- `https://sclaw.coreviaflow.space/step-1-clone`
- `https://sclaw.coreviaflow.space/step-2-environment`
- `https://sclaw.coreviaflow.space/step-3-keys`
- `https://sclaw.coreviaflow.space/step-4-config`
- `https://sclaw.coreviaflow.space/step-5-launch`
- `https://sclaw.coreviaflow.space/step-6-niche`
- `https://sclaw.coreviaflow.space/step-7-deploy`

(Без `.html` — благодаря `try_files` в nginx.conf.)

## Обновление контента

```bash
cd claw-site
# правите файлы
git add .
git commit -m "Update step 3"
git push
```

Auto Deploy on push to `main` включён по умолчанию. Через 30–60 сек после `git push` — новая версия в проде.

## Локальная проверка перед деплоем

```bash
cd claw-site
docker compose up -d --build
open http://localhost:8080
```

## Если что-то пошло не так

| Симптом | Решение |
|---|---|
| `dig sclaw.coreviaflow.space` ничего не возвращает | DNS не пропагировался — подождите ещё 5–10 мин или проверьте, что A-запись точно сохранилась в DNS-провайдере |
| `SSL certificate problem` | Подождите 2–3 мин после первого запроса. Если 10+ мин — Let's Encrypt не может достучаться до сервера. Проверьте, что 80/443 открыты в firewall |
| `502 Bad Gateway` | Контейнер не запустился. Logs в Coolify → ищите ошибку nginx |
| `404 Not Found` на главной | Файлы не пушнулись. `git ls-files` должен показать все *.html и styles.css |
| Healthcheck красный | В Coolify → Terminal: `wget -qO- http://localhost/`. Если пусто — проблема с nginx-конфигом |

## Структура

```
claw-site/
├── index.html              ← главная
├── step-1-clone.html       ← клонирование репо
├── step-2-environment.html ← окружение
├── step-3-keys.html        ← API ключи
├── step-4-config.html      ← .env
├── step-5-launch.html      ← первый запуск
├── step-6-niche.html       ← настройка ниши
├── step-7-deploy.html      ← деплой в прод
├── styles.css              ← стили
├── Dockerfile              ← nginx:alpine + статика
├── nginx.conf              ← конфиг nginx
├── docker-compose.yml      ← один сервис claw-site
└── DEPLOY.md               ← этот файл
```
