# Git Flow — drop-in templates

Готовый набор файлов, которые можно положить в репозиторий **как есть**.
Цель — гарантировать соблюдение git flow людьми и агентами: имя ветки с ключом задачи, формат коммита, запрет суффиксов после ключа.

## Канон

| Правило | Формат |
|---------|--------|
| Feature / bugfix / hotfix ветка | `feature/PROJ-123`, `bugfix/PROJ-123`, `hotfix/PROJ-123` |
| Суффикс после номера | **запрещён** (`feature/PROJ-123-login` — нет) |
| Коммит | `feature/PROJ-123 - Краткое описание` |
| База для фич | `dev` (или ваша интеграционная ветка) |
| Env-ветки без ключа | `main` · `master` · `dev` · `test` · `demo` · `prod` · `stable` |

Ключ задачи: `[A-Z]+-[0-9]+` (Jira, YouTrack, Linear, Task Flow и т.п.).

## Что внутри

```
git-flow-templates/
├── README.md                 ← этот файл
├── POLICY.md                 ← одностраничная политика (опционально в репо)
├── drop-in/                  ← универсальный путь (любой стек)
│   ├── .githooks/
│   │   ├── install.sh        ← включает хуки: core.hooksPath=.githooks
│   │   ├── commit-msg        ← формат сообщения
│   │   ├── prepare-commit-msg← подставляет имя ветки в subject
│   │   └── pre-push          ← имя ветки + subject уже запушенных коммитов
│   ├── AGENTS.md             ← правила для AI-агентов
│   └── .cursor/rules/
│       └── git-flow.mdc      ← Cursor always-on rule
├── node/                     ← доп. слой для JS/TS (husky + commitlint)
│   ├── commitlint.config.js
│   ├── package.json.snippet
│   └── .husky/
│       ├── commit-msg
│       └── prepare-commit-msg
└── server/
    └── pre-receive.example   ← server-side отказ пуша (источник истины)
```

## Установка за 2 минуты (универсальный путь)

Из корня **вашего** репозитория:

```bash
# 1. Скопировать хуки и правила для агентов
cp -R path/to/git-flow-templates/drop-in/.githooks .
cp path/to/git-flow-templates/drop-in/AGENTS.md .   # или дописать в существующий
mkdir -p .cursor/rules
cp path/to/git-flow-templates/drop-in/.cursor/rules/git-flow.mdc .cursor/rules/

# 2. Включить хуки (один раз на клон)
sh .githooks/install.sh
```

Проверка:

```bash
git checkout -b feature/PROJ-1
echo "test" >> README.md && git add README.md
git commit -m "плохое сообщение"          # должно упасть
git commit -m "feature/PROJ-1 - Ок"     # должно пройти
```

Для новых клонов добавьте в README проекта:

```bash
sh .githooks/install.sh
```

или в `package.json` / Makefile вызов того же скрипта.

## Node / husky (опционально)

Если уже используете husky, вместо `core.hooksPath=.githooks`:

1. Скопируйте `node/commitlint.config.js` в корень.
2. Скопируйте `node/.husky/commit-msg`, `prepare-commit-msg`, `pre-push`.
3. Добавьте зависимости из `node/package.json.snippet`.
4. `npx husky` (или `npm prepare`).
5. Правила для агентов всё равно возьмите из `drop-in/AGENTS.md` и `drop-in/.cursor/rules/`.

Не включайте одновременно `core.hooksPath=.githooks` и husky — один механизм хуков.

## Server hook (рекомендуется)

Локальные хуки можно обойти (`--no-verify`). Положите `server/pre-receive.example` на Git-сервер (GitLab custom hook / Gitolite / update-hook) и поправьте список защищённых веток под себя. После этого неверный формат не пройдёт пуш.

## Что сознательно не включено

- CI-джобы на lint/test — это качество кода, не git flow.
- Шаблоны MR/PR с чеклистами продукта.
- Скрипты sync env-веток.
- Привязка к конкретному трекеру или префиксу проекта (`PDM`, `PS`…).

Менять префиксы типов (`feature`/`bugfix`/…) и список env-веток можно в одних и тех же regex во всех файлах пакета — они согласованы.
