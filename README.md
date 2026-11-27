# Git Flow — drop-in templates

Готовый набор файлов без правок под конкретный стек.
Цель — гарантировать соблюдение git flow людьми и агентами: имя ветки с ключом задачи, формат коммита, запрет суффиксов после ключа.

**`drop-in/` — имя папки только в этом репозитории-гайдлайне.** В целевой проект её не кладут целиком: в **корень** репозитория копируют **содержимое** (` .githooks/`, `AGENTS.md`, `.cursor/rules/…`). Вложенный путь вроде `ваш-репо/drop-in/.githooks` хуки и Cursor не подхватят.

## Канон

| Правило | Формат |
|---------|--------|
| Feature / bugfix / hotfix ветка | `feature/PROJ-123`, `bugfix/PROJ-123`, `hotfix/PROJ-123` |
| Суффикс после номера | **запрещён** (`feature/PROJ-123-login` — нет) |
| Коммит | `feature/PROJ-123 - Краткое описание` |
| База для фич | `dev` (или ваша интеграционная ветка) |
| Env-ветки без ключа | `main` · `master` · `dev` · `develop` · `test` · `stage` · `staging` · `demo` · `prod` · `stable` · `release/*` |
| Служебные коммиты | `Merge …`, `Revert …`; у `fixup!` / `squash!` / `amend!` проверяется исходный subject |

Ключ задачи: `[A-Z]+-[0-9]+` (Jira, YouTrack, Linear, Task Flow и т.п.).

## Что внутри

```
git-flow-templates/
├── README.md                 ← этот файл
├── POLICY.md                 ← одностраничная политика (опционально в репо)
├── drop-in/                  ← содержимое → в корень целевого репо (не саму папку)
│   ├── .githooks/
│   │   ├── install.sh        ← включает хуки: core.hooksPath=.githooks
│   │   ├── commit-msg        ← формат сообщения
│   │   ├── prepare-commit-msg← подставляет имя ветки в subject
│   │   └── pre-push          ← имена пушащихся веток + subject новых коммитов
│   ├── AGENTS.md             ← правила для AI-агентов
│   └── .cursor/rules/
│       └── git-flow.mdc      ← Cursor always-on rule
├── node/                     ← доп. слой для JS/TS (husky + commitlint)
│   ├── commitlint.config.mjs
│   ├── package.json.snippet
│   └── .husky/
│       ├── commit-msg
│       ├── prepare-commit-msg
│       └── pre-push
└── server/
    └── pre-receive.example   ← server-side отказ пуша (GitLab, GHES, свой git-сервер)
```

## Установка за 2 минуты (универсальный путь)

Из корня **вашего** репозитория скопируйте файлы из `drop-in/`, **не** создавая подпапку `drop-in`:

```bash
# 1. Содержимое drop-in → корень целевого репо
cp -R path/to/git-flow-templates/drop-in/.githooks .
cp path/to/git-flow-templates/drop-in/AGENTS.md .   # или дописать в существующий
mkdir -p .cursor/rules
cp path/to/git-flow-templates/drop-in/.cursor/rules/git-flow.mdc .cursor/rules/

# Итог в вашем репо:
#   .githooks/   AGENTS.md   .cursor/rules/git-flow.mdc
# НЕ: drop-in/.githooks/...

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

1. Скопируйте `node/commitlint.config.mjs` в корень (`.mjs` грузится и в CommonJS-, и в ESM-проектах).
2. Скопируйте `node/.husky/commit-msg`, `prepare-commit-msg`, `pre-push`.
3. Добавьте зависимости из `node/package.json.snippet`.
4. `npx husky` (или `npm prepare`).
5. Правила для агентов всё равно возьмите из `drop-in/AGENTS.md` и `drop-in/.cursor/rules/`.

Не включайте одновременно `core.hooksPath=.githooks` и husky — один механизм хуков.

## Серверная проверка (рекомендуется)

Локальные хуки можно обойти (`--no-verify`), поэтому финальная проверка должна быть на сервере.

### GitLab self-managed, GitHub Enterprise Server, свой git-сервер

Положите `server/pre-receive.example` как `pre-receive` (GitLab server hooks / GHES pre-receive hooks / `hooks/` bare-репозитория) и поправьте список env-веток под себя. Ставьте хук после первого пуша env-веток: их новые коммиты он тоже проверяет, и `Initial commit` в пустой репозиторий не пройдёт.

### GitHub.com

Пользовательских pre-receive хуков на GitHub.com нет. Те же правила задаются rulesets (Settings → Rules → Rulesets):

1. **Branch ruleset на все ветки, кроме env** — правило *Restrict branch names*, шаблон-regex `^(feature|bugfix|hotfix)/[A-Z]+-[0-9]+$`.
2. **Commit message pattern** — regex `^((Merge|Revert).*|((fixup|squash|amend)! )*(feature|bugfix|hotfix|fix|refactor|docs|test|chore|ci|style|release)/[A-Z]+-[0-9]+ - .+)`.
3. **Branch ruleset на `dev` / `prod` / `main`** — *Require a pull request before merging*, запрет force push и удаления.

Ограничения по метаданным (имя ветки, сообщение коммита) доступны не на всех тарифах GitHub — проверьте свой план. Если их нет, оставьте локальные хуки и защиту env-веток через PR.

## Что сознательно не включено

- CI-джобы на lint/test — это качество кода, не git flow.
- Шаблоны MR/PR с чеклистами продукта.
- Скрипты sync env-веток.
- Привязка к конкретному трекеру или префиксу проекта (`PDM`, `PS`…).

Менять префиксы типов (`feature`/`bugfix`/…) и список env-веток можно в одних и тех же regex во всех файлах пакета — они согласованы.
