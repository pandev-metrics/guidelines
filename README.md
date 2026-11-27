# Git Flow — drop-in templates

Набор файлов, который кладут в репозиторий без правок кода. Он гарантирует, что люди и AI-агенты ведут ветки и коммиты по одним правилам: ключ задачи в имени ветки, формат коммита, тот же ключ в коммитах ветки.

Правила настраиваются в одном файле — `.githooks/git-flow.conf`. Значения по умолчанию подходят командам на Jira, YouTrack, Yandex Tracker, Linear, Task Flow и Bitrix24. Для Azure Boards и ClickUp без Custom Task IDs нужен другой формат ключа — см. «Формат ключа по трекерам».

**`drop-in/` — имя папки только в этом репозитории.** В целевой проект её не кладут целиком: в **корень** репозитория копируют **содержимое** (`.githooks/`, `AGENTS.md`, `.cursor/rules/…`). Вложенный путь вроде `ваш-репо/drop-in/.githooks` хуки и Cursor не подхватят.

## Канон

| Правило | Формат |
|---------|--------|
| Рабочая ветка | `feature/PROJ-123`, `bugfix/PROJ-123`, `hotfix/PROJ-123` — заводится **до начала работы** |
| Хвост после ключа | по умолчанию запрещён (`feature/PROJ-123-login` — нет), см. «Почему без хвоста» |
| Коммит | `feature/PROJ-123 - Краткое описание`, ключ — как у ветки, тип может отличаться |
| Заголовок MR/PR | как у коммита: `feature/PROJ-123 - Краткое описание` |
| Почта автора | рабочая, та же, что у человека в трекере и PanDev |
| База для фич | `dev` (или ваша интеграционная ветка) |
| Общие ветки и окружения | `main` · `master` · `dev` · `develop` · `test` · `qa` · `uat` · `stage` · `staging` · `preprod` · `demo` · `prod` · `production` · `live` · `stable` · `release/*` |
| Не проверяются | ветки `dependabot/*`, `renovate/*`; сообщения `Merge …`, `Revert …`, `Bump …`, `chore(deps): …`, `Update dependency …`; у `fixup!`/`squash!`/`amend!` проверяется исходное сообщение |

## Что внутри

```
git-flow-templates/
├── README.md                    ← этот файл
├── POLICY.md                    ← одностраничная политика для команды
├── .github/workflows/test.yml   ← CI: sh tests/run.sh на PR и на push в main
├── tests/
│   └── run.sh                   ← прогон хуков на временном bare + working tree
├── drop-in/                     ← содержимое → в корень целевого репо (не саму папку)
│   ├── .githooks/
│   │   ├── git-flow.conf        ← все правила: формат ключа, типы, env-ветки, исключения, почта
│   │   ├── lib.sh               ← общие проверки (не править)
│   │   ├── install.sh           ← включает хуки: core.hooksPath=.githooks
│   │   ├── commit-msg           ← формат, ключ ветки, почта
│   │   ├── prepare-commit-msg   ← дописывает «тип/КЛЮЧ - » из имени ветки
│   │   └── pre-push             ← имена пушащихся веток + новые коммиты
│   ├── AGENTS.md                ← правила для AI-агентов
│   └── .cursor/rules/
│       └── git-flow.mdc         ← Cursor always-on rule
├── node/                        ← если в проекте уже husky
│   ├── package.json.snippet
│   └── .husky/                  ← обёртки, вызывают те же скрипты из .githooks
└── server/
    └── pre-receive.example      ← серверная проверка (GitLab, GHES, свой git-сервер)
```

## Установка за 2 минуты

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

# 2. Проверить формат ключа и список env-веток в .githooks/git-flow.conf

# 3. Включить хуки (один раз на клон)
sh .githooks/install.sh
```

Проверка:

```bash
git checkout -b feature/PROJ-1
echo "test" >> README.md && git add README.md
git commit -m "feature/PROJ-2 - Чужой ключ"   # упадёт: ключ не совпадает с веткой
git commit -m "Описание"                       # пройдёт как «feature/PROJ-1 - Описание»
```

Для новых клонов добавьте в README проекта `sh .githooks/install.sh` или вызовите его из `package.json` / Makefile.

### Если в проекте husky

husky сам владеет `core.hooksPath`, поэтому `install.sh` не запускайте.

1. Скопируйте содержимое `drop-in/`, как выше.
2. Скопируйте `node/.husky/commit-msg`, `prepare-commit-msg`, `pre-push` в `.husky/` — это обёртки над скриптами из `.githooks`, правила остаются в `git-flow.conf`.
3. Добавьте зависимость из `node/package.json.snippet` и выполните `npm install`.

## Формат ключа по трекерам

Ключ задаётся в `KEY_RE` в `git-flow.conf`. Ветка и коммиты проверяются по нему одинаково.

| Трекер | Ветка | `KEY_RE` |
|---|---|---|
| Jira, YouTrack, Yandex Tracker, Linear, Task Flow, Bitrix24 | `feature/PROJ-123`, `feature/QA2-15`, `feature/MY_APP-7`, `feature/BX-3` | по умолчанию |
| Task Flow, задачи после импорта с занятым ключом | `feature/PROJ-12_jira`, `feature/PROJ-12_jira_2` | по умолчанию |
| Azure Boards | `feature/4521` | `[0-9]+` |
| ClickUp без Custom Task IDs | `feature/CU-869dmarzn`, `feature/869dmarzn` | `(CU-)?[0-9a-z]{6,12}` |
| ClickUp с Custom Task IDs | `feature/DEV-123` | по умолчанию |
| Notion | `feature/TASK-42` (уникальный ID с номером) | по умолчанию |

Ключ в ветке пишется заглавными буквами, даже если трекер принимает любой регистр. Форма `BX123` (Bitrix24 без дефиса) и Notion-ключи с id страницы пакетом не поддерживаются.

## Почему без хвоста после ключа

Запрет хвоста — правило команды, а не требование PanDev. PanDev связывает `feature/PROJ-123-login` с задачей `PROJ-123`. Связь ломается, только если в хвосте окажется ключ другой существующей задачи (`feature/PROJ-123-PROJ-124`): такая ветка неоднозначна и ни к чему не привязывается. Запрет хвоста исключает это полностью.

Цена запрета:

- ветки, которые создают сами трекеры (`PROJ-123-summary` из Jira, `user/eng-123-title` из Linear, `CU-…_title` из ClickUp), придётся переименовывать;
- два агента не могут параллельно работать над одной задачей: git не даёт держать одну ветку в двух worktree, а второе имя с хвостом запрещено.

Если цена выше пользы, поставьте `ALLOW_BRANCH_SUFFIX=1`. Хвост тогда разрешён только в нижнем регистре (`feature/PROJ-123-login`): второй ключ в нём не поместится, и неоднозначности не будет.

## Совместимость с PanDev

PanDev связывает работу с задачей по имени ветки: от него зависят время из IDE, AI-токены и коммиты задачи. Ключи из коммитов MR при мерже двигают задачи Task Flow по автопереходам. Ниже — что сверить в настройках PanDev, чтобы хуки и подсчёт совпадали.

### Регулярки атрибуции

Если вы поменяли `KEY_RE` или трекер не из списка по умолчанию, задайте то же правило в **Интеграции → Атрибуция задач** (Branch, MR Name и Commit Name регулярки; серверные настройки `BRANCH_ISSUE_REGEXPS`, `MR_TITLE_ISSUE_REGEXPS`, `COMMIT_MESSAGE_ISSUE_REGEXPS`). Иначе хуки пропустят ветку, а PanDev её не разберёт.

### Общие ветки и прод-ветки

Список `ENV_BRANCH_RE` в `git-flow.conf` должен совпадать с настройками PanDev:

- **Интеграции → Git общее → Основные ветки** (`GENERAL_BRANCH_NAMES`, по умолчанию `dev,prod,test,master,main`, шаблон `release/*` тоже поддерживается). Только из этих веток можно выбрать событие автоперехода Task Flow («влито в develop»), только мержи в них попадают в разрез «среда» DORA, и только они защищены от привязки к задаче по заголовку MR.
- **Интеграции → DORA метрики → Прод-ветки** (`DORA_PRODUCTION_BRANCHES`, по умолчанию `prod,production,master,main`). Мерж в эти ветки — деплой в прод.

Если команда работает через `develop`, `stage` или `qa`, добавьте их в «Основные ветки». Если в PanDev есть ветка окружения, которой нет в `ENV_BRANCH_RE`, — добавьте её в конфиг, иначе хук не пустит в неё пуш.

### `bugfix` и `hotfix` в DORA

По умолчанию PanDev считает ветки с префиксами `bugfix`, `hotfix` и `fix` исправлением сбоя (**Интеграции → DORA метрики**: «Ветка багов», «Ветка хотфиксов»; `DORA_FAILURE_BRANCH_PREFIXES`):

- мерж такой ветки в прод — сбойный деплой, он входит в долю сбоев (Change Failure Rate) и время восстановления;
- мерж такой ветки в общую ветку (`dev`) тоже записывается как релизное событие для этих метрик.

Поэтому в `POLICY.md` `bugfix/` и `hotfix/` — только для проблем, дошедших до прода. Баг, пойманный до релиза, чинят в ветке фичи или в `feature/<ключ задачи-бага>`. Если команда вкладывает в `bugfix` другой смысл, поправьте префиксы в настройках DORA.

`hotfix` по умолчанию не входит в «исправления» (`DORA_BUGFIX_BRANCH_PREFIXES` = `bugfix,bug`): влитый `hotfix` в разбивке «фичи / исправления» не попадает никуда. Добавьте `hotfix` туда, если это важно для отчёта.

### Заголовок MR/PR и squash

PanDev читает заголовок MR: по умолчанию берёт из него ключ только в форме `feat(PROJ-1): …` и использует тип изменения для DORA. Пакет задаёт заголовок в формате коммита — `feature/PROJ-1 - …`. Тогда тип изменения PanDev берёт из префикса ветки.

Заголовок в формате коммита нужен и для squash-мержа: сообщением squash-коммита становится заголовок MR (в GitLab — шаблон `%{title}` по умолчанию, на GitHub — заголовок PR с `(#N)`). Заголовок вида `feat(PROJ-1): Логин` не пройдёт серверную проверку, и MR не вольётся («Prevented by server hooks» в GitLab).

### Почта автора коммита

PanDev засчитывает коммит по подписи автора: алиас, затем почта или логин, затем формы имени. Коммит с личной почтой (`me@gmail.com`) или с почтой облачного агента ничей, пока администратор не заведёт алиас.

- Каждый задаёт `git config user.email` — рабочую почту, как в PanDev.
- Агенты коммитят от имени человека, а не своей учётки.
- Проверку домена включает `ALLOWED_EMAIL_RE` в `git-flow.conf` (например, `'@company\.com$'`): тогда `commit-msg`, `pre-push` и серверный хук не пропустят чужую почту.

## Серверная проверка (рекомендуется)

Локальные хуки можно обойти (`--no-verify`), поэтому финальная проверка должна быть на сервере.

### GitLab self-managed, GitHub Enterprise Server, свой git-сервер

Положите `server/pre-receive.example` как `pre-receive` (GitLab server hooks / GHES pre-receive hooks / `hooks/` bare-репозитория). Настройки в начале файла держите такими же, как в `git-flow.conf`. Ставьте хук после первого пуша env-веток: их новые коммиты он тоже проверяет, и `Initial commit` в пустой репозиторий не пройдёт.

Коммиты, которые создаёт сам GitLab, тоже проходят проверку. В настройках проекта GitLab (Settings → Merge requests) задайте:

- **Merge suggestions commit message template:** `%{branch_name} - Apply %{suggestions_count} suggestion(s) to %{files_count} file(s)` (без хвоста после ключа это даёт правильный формат);
- **Squash commit message template:** оставьте `%{title}` и пишите заголовок MR в формате коммита.

В Web IDE пишите сообщение коммита в том же формате: подставленное по умолчанию «Update file …» не пройдёт.

### GitHub.com

Пользовательских pre-receive хуков на GitHub.com нет. Те же правила задаются rulesets (Settings → Rules → Rulesets):

1. **Branch ruleset на все ветки, кроме общих и `dependabot/**`, `renovate/**`** — правило *Restrict branch names*, regex `^(feature|bugfix|hotfix)/[A-Z][A-Z0-9_]*-[0-9]+(_[a-z]+(_[0-9]+)?)?$`.
2. **Commit message pattern** — regex `^((Merge |Revert |Bump |chore\(deps(-dev)?\): |Update dependency ).*|((fixup|squash|amend)! )*(feature|bugfix|hotfix|fix|refactor|docs|test|chore|ci|style|release)/[A-Z][A-Z0-9_]*-[0-9]+(_[a-z]+(_[0-9]+)?)? - .+)`. Squash-коммит берёт сообщение из заголовка PR, поэтому заголовок пишите в том же формате.
3. **Branch ruleset на общие ветки** — *Require a pull request before merging*, запрет force push и удаления.
4. В **этом** репозитории (`guidelines`) на `main` дополнительно: required status check `test` (workflow `.github/workflows/test.yml`) — мерж без зелёных тестов закрыт.

Совпадение ключа коммита с веткой и почту rulesets не проверяют — это остаётся на локальных хуках. Ограничения по метаданным (имя ветки, сообщение коммита) доступны не на всех тарифах GitHub; эти правила на реальном репозитории не проверялись — сверьтесь с документацией своего плана.

## Тесты

Из корня этого репозитория (нужны `git` и `sh`):

```bash
sh tests/run.sh
```

Скрипт поднимает временный bare-remote и working tree, копирует `drop-in/.githooks`, включает их и прогоняет сценарии: формат и ключ коммита, первый пуш поверх legacy history, merge env в feature, суффикс ветки, ключи Jira/Task Flow, Azure-preset, dependabot, env-ветки, почта автора, husky-обёртки, `server/pre-receive.example`, совпадение настроек конфига и серверного хука. Exit 1 при любом несовпадении.

В этом репозитории тот же прогон идёт в GitHub Actions (`.github/workflows/test.yml`) на каждый PR и на push в `main`. Ruleset на `main` требует зелёный check `test` и pull request — без прошедших тестов мерж закрыт.

## Что сознательно не включено

- CI-джобы на lint/test **продуктового** кода — это качество приложения, не git flow (свой прогон хуков в `.github/workflows/test.yml` есть).
- Шаблоны MR/PR с чеклистами продукта.
- Скрипты синхронизации env-веток.

Правила меняются только в `git-flow.conf`; после правки повторите значения в `server/pre-receive.example`, в rulesets GitHub и в регулярках атрибуции PanDev.
