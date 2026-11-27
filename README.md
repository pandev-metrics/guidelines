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
│   │   ├── pre-push             ← имена пушащихся веток + новые коммиты
│   │   └── check-range          ← проверка PR/MR в CI: ветка, заголовок, коммиты
│   ├── AGENTS.md                ← правила для AI-агентов
│   └── .cursor/rules/
│       └── git-flow.mdc         ← Cursor always-on rule
├── node/                        ← если в проекте уже husky
│   ├── package.json.snippet
│   └── .husky/                  ← обёртки, вызывают те же скрипты из .githooks
├── github/
│   └── git-flow-check.yml       ← workflow организации для GitHub без Enterprise
└── server/
    └── pre-receive.example      ← серверная проверка (GitLab, GHES)
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
| Task Flow, задачи после импорта с занятым ключом | `feature/PROJ-12_jira`, `feature/PROJ-12_clickup_2`, `feature/PROJ-12_yandex` | по умолчанию |
| Azure Boards | `feature/4521` | `[0-9]+` |
| ClickUp без Custom Task IDs | `feature/CU-869dmarzn`, `feature/869dmarzn` | `(CU-)?[0-9][0-9a-z]{6,11}` |
| ClickUp с Custom Task IDs | `feature/DEV-123` | по умолчанию |
| Notion | `feature/TASK-42` (уникальный ID с номером) | по умолчанию |

Ключ в ветке пишется заглавными буквами, даже если трекер принимает любой регистр. Форма `BX123` (Bitrix24 без дефиса) и Notion-ключи с id страницы пакетом не поддерживаются.

Суффикс импорта — только `_jira`, `_clickup`, `_yandex`: другие PanDev не знает. Task Flow при занятом ключе выдаёт и `PROJ-12_csv`, `PROJ-12_asana`, `PROJ-12_github_projects`, но такую ветку PanDev прочтёт как `PROJ-12` и свяжет с чужой задачей, поэтому хук её не пустит. Для таких задач заведите ветку по ключу другой задачи или переименуйте ключ в Task Flow.

ClickUp-заготовка требует id от 7 символов, начинающийся с цифры: так PanDev разбирает голый id, а `feature/payments` или `feature/refactor` хук не примет за задачу.

## Почему без хвоста после ключа

Запрет хвоста — правило команды, а не требование PanDev. PanDev связывает `feature/PROJ-123-login` с задачей `PROJ-123`. Связь ломается, только если в хвосте окажется ключ другой существующей задачи (`feature/PROJ-123-PROJ-124`): такая ветка неоднозначна и ни к чему не привязывается. Запрет хвоста исключает это полностью.

Цена запрета:

- ветки, которые создают сами трекеры (`PROJ-123-summary` из Jira, `user/eng-123-title` из Linear, `CU-…_title` из ClickUp), придётся переименовывать;
- два агента не могут параллельно работать над одной задачей: git не даёт держать одну ветку в двух worktree, а второе имя с хвостом запрещено.

Если цена выше пользы, поставьте `ALLOW_BRANCH_SUFFIX=1`. Хвост тогда разрешён только в нижнем регистре (`feature/PROJ-123-login`). PanDev читает ключи без учёта регистра, поэтому `feature/PROJ-123-proj-124` для него тоже два ключа. Хуки отклоняют хвост, в котором есть «слово-число» (`-proj-124`, `-fix-2`); `-login`, `-login-v2` проходят.

## Совместимость с PanDev

PanDev связывает работу с задачей по имени ветки: от него зависят время из IDE, AI-токены и коммиты задачи. Ниже — что сверить в настройках PanDev, чтобы хуки и подсчёт совпадали.

### Регулярки атрибуции

**Для формата по умолчанию и обеих заготовок (Azure, ClickUp) регулярки в «Атрибуции задач» не задавайте** — PanDev разбирает эти ключи сам. `KEY_RE` туда не копируйте:

- регулярка отдела (**Интеграции → Атрибуция задач**: Branch, MR Name, Commit Name; `BRANCH_ISSUE_REGEXPS`, `MR_TITLE_ISSUE_REGEXPS`, `COMMIT_MESSAGE_ISSUE_REGEXPS`) **полностью заменяет** встроенный разбор;
- ядро ищет совпадение в любом месте строки и берёт первую группу, если она есть. Копия ClickUp-заготовки вынет из `feature/CU-869dmarzn` слово `feature`, копия ключа по умолчанию превратит `PROJ-12_jira` в `_jira` — не свяжется ни одна ветка;
- регулярка заголовков MR вдобавок сразу включает привязку ветки по заголовку MR.

Своя регулярка нужна, только если ключ не разбирается встроенными парсерами. Тогда — с якорями и одной группой вокруг ключа:

```text
^(?:feature|bugfix|hotfix)/([A-Z][A-Z0-9_]*-[0-9]+)$
```

### Общие ветки и прод-ветки

Список `ENV_BRANCH_RE` в `git-flow.conf` должен совпадать с настройками PanDev:

- **Интеграции → Git общее → Основные ветки** (`GENERAL_BRANCH_NAMES`, по умолчанию `dev,prod,test,master,main`, шаблон `release/*` тоже поддерживается). Только из этих веток можно выбрать событие автоперехода Task Flow («влито в develop»), и только они защищены от привязки к задаче по заголовку MR. Разрез «среда» DORA строится по основным веткам **за вычетом прод-веток**: мержи в прод-ветки считаются деплоями (частота деплоев), а не средой.
- **Интеграции → DORA метрики → Прод-ветки** (`DORA_PRODUCTION_BRANCHES`, по умолчанию `prod,production,master,main`). Мерж в эти ветки — деплой в прод.

Если команда работает через `develop`, `stage` или `qa`, добавьте их в «Основные ветки». Если в PanDev есть ветка окружения, которой нет в `ENV_BRANCH_RE`, — добавьте её в конфиг, иначе хук не пустит в неё пуш.

### `bugfix` и `hotfix` в DORA

По умолчанию PanDev считает ветки с префиксами `bugfix`, `hotfix` и `fix` исправлением сбоя. Это одно поле — **Интеграции → DORA метрики → «Ветка хотфиксов»** (`DORA_FAILURE_BRANCH_PREFIXES`, по умолчанию `bugfix,hotfix,fix`):

- мерж такой ветки в прод — сбойный деплой, он входит в долю сбоев (Change Failure Rate) и время восстановления;
- мерж такой ветки в общую ветку (`dev`) тоже записывается как релизное событие для этих метрик.

Поэтому в `POLICY.md` `bugfix/` и `hotfix/` — только для проблем, дошедших до прода. Баг, пойманный до релиза, чинят в ветке фичи или в `feature/<ключ задачи-бага>`. Если команда вкладывает в `bugfix` другой смысл, поправьте префиксы в настройках DORA.

Поле **«Ветка багов»** (`DORA_BUGFIX_BRANCH_PREFIXES`, по умолчанию `bugfix,bug`) — другое: оно задаёт «исправления» в разбивке «фичи / исправления» и на долю сбоев не влияет. `hotfix` в нём по умолчанию нет, поэтому влитый `hotfix` в разбивку не попадает никуда. Добавьте `hotfix` в «Ветку багов», если это важно для отчёта.

### Заголовок MR/PR и squash

PanDev читает заголовок MR: по умолчанию берёт из него ключ только в форме `feat(PROJ-1): …` и использует тип изменения для DORA. Пакет задаёт заголовок в формате коммита — `feature/PROJ-1 - …`. Тогда тип изменения PanDev берёт из префикса ветки.

Заголовок в формате коммита нужен и для squash-мержа: сообщением squash-коммита становится заголовок MR (в GitLab — шаблон `%{title}` по умолчанию, на GitHub — заголовок PR с `(#N)`). Заголовок вида `feat(PROJ-1): Логин` не пройдёт серверную проверку, и MR не вольётся («Prevented by server hooks» в GitLab).

### Почта автора коммита

PanDev засчитывает коммит по подписи автора: алиас, затем почта или логин, затем формы имени. Коммит с личной почтой (`me@gmail.com`) или с почтой облачного агента ничей, пока администратор не заведёт алиас.

- Каждый задаёт `git config user.email` — рабочую почту, как в PanDev.
- Агенты коммитят от имени человека, а не своей учётки.
- Проверку домена включает `ALLOWED_EMAIL_RE` в `git-flow.conf` (например, `'@company\.com$'`): тогда `commit-msg`, `pre-push` и серверный хук не пропустят чужую почту.

## Серверная проверка (рекомендуется)

Локальные хуки можно обойти (`--no-verify`), поэтому финальная проверка должна быть на сервере. Ниже — как включить её **на уровне организации / инстанса**, чтобы не копировать настройки в каждый репозиторий. `drop-in/` в репо по-прежнему нужен людям и агентам (быстрый отказ при коммите); сервер — страховка.

Один раз задайте те же значения, что в `git-flow.conf` (`KEY_RE`, типы веток, env-ветки, исключения). Совпадение ключа коммита с веткой и почту автора почти нигде на стороне хостинга не проверяют — это остаётся на локальных хуках и на `server/pre-receive.example`, где он доступен.

### Что поставить один раз на всю систему

Такой настройкой можно внести общие правила вашей git инсталляции, чтобы не было необходимости добавлять хуки в каждом репозитории. Ниже приведена таблица различных вендоров:

| Система | Уровень «на всю систему» | Что закрывает | Чего нет |
|---------|--------------------------|---------------|----------|
| **GitHub.com Enterprise Cloud** | Organization rulesets → все или выбранные репо | Имя ветки, pattern сообщения коммита, PR before merge, запрет force-push | Совпадение ключа с веткой, почта |
| **GitHub.com Team** | Organization rulesets + обязательный workflow организации | PR before merge, запрет force-push; формат имени и коммитов — workflow с теми же regex на каждом PR | Правил на имя ветки и сообщение коммита в rulesets нет (только Enterprise); пуши без PR workflow не видит |
| **GitHub Enterprise Server** | Org rulesets **или** глобальный pre-receive на инстансе | Rulesets — как в Enterprise Cloud; pre-receive — полный набор из `server/pre-receive.example` | У rulesets — ключ↔ветка, почта; у pre-receive пробелов нет |
| **GitLab Self-Managed** | Global Git server hooks (`pre-receive` на весь инстанс) | Полный набор из `server/pre-receive.example` на **все** репо сразу; вики, дизайны, первый пуш и проекты вне flow хук пропускает | Push rules Admin/группы — только **шаблон для новых** проектов, существующие сами не обновляются |
| **GitLab.com** | Group push rules (Premium+) как шаблон для **новых** проектов группы | Имя ветки, commit message regex | Нет user pre-receive; старые проекты — править по одному или через API |
| **Bitbucket Data Center** | Hooks на уровне **Project** (наследуются репозиториями) | Pre-receive / merge checks (плагин или свой хук по regex) | В коробке может не быть готового regex «как в `git-flow.conf`» — нужен плагин или свой хук |
| **Bitbucket Cloud** | Project branch restrictions + обязательная сборка Pipelines (merge check «passing builds», Premium) | Кто пушит/мержит; формат — `sh .githooks/check-range` в Pipelines на PR | Формат на пуш сервером не задаётся; пуши без PR сборка не видит |
| **Azure DevOps** | Branch policies на Project + required pipeline на protected-ветки | PR before merge; format-check в Build validation на PR в protected | Нет native regex на push; прямые пуши в незащищённые `feature/*` pipeline не видит |

### GitHub.com — organization rulesets

Пользовательских pre-receive на github.com нет. Правила один раз в **Organization → Settings → Rules → Rulesets**, target репозиториев: all или по имени / custom properties.

Rulesets организации есть на Team и Enterprise, но правила на имя ветки и сообщение коммита (*Restrict branch names*, *Restrict commit metadata*) — [только в Enterprise](https://docs.github.com/en/enterprise-cloud@latest/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets). На Team см. «Без Enterprise» ниже.

**1. Рабочие и прочие не-env ветки** (Enterprise) — отсекает и `feature/…` не по формату, и левые имена (`wip`, `misc`, `claude/…`).

- Include: все ветки. Exclude: общие/env из `ENV_BRANCH_RE` (`main`, `master`, `dev`, `develop`, `test`, `qa`, `uat`, `stage`, `staging`, `preprod`, `demo`, `prod`, `production`, `live`, `stable`, `release/**`) и боты (`dependabot/**`, `renovate/**`).
- *Restrict branch names* — только имена вида `тип/КЛЮЧ` (при `ALLOW_BRANCH_SUFFIX=0`):

```text
^(feature|bugfix|hotfix)/[A-Z][A-Z0-9_]*-[0-9]+(_(jira|clickup|yandex)(_[0-9]+)?)?$
```

- *Restrict commit metadata → Commit message*, «Must match a given regex pattern»:

```text
^((Merge |Revert |Bump |chore\(deps(-dev)?\): |Update dependency ).*|((fixup|squash|amend)! )*(feature|bugfix|hotfix|fix|refactor|docs|test|chore|ci|style|release)/[A-Z][A-Z0-9_]*-[0-9]+(_(jira|clickup|yandex)(_[0-9]+)?)? - .+)
```

Правило на имя отклонит и ветки, которые создаёт сам GitHub: `revert-123-…` (кнопка Revert), `<user>-patch-1` (правка файла в вебе), `copilot/…` (Copilot coding agent). Либо называйте такие ветки по формату вручную, либо добавьте их в Exclude, как ботов.

**2. Общие / env-ветки** (`main`, `master`, `dev`, … из списка выше) — *Require a pull request before merging*, запрет force push и удаления. В Enterprise сюда же — тот же commit message pattern:

- GitHub не применяет его к уже существующей истории ветки, только к новым коммитам;
- при squash- и rebase-мерже проверяется итоговый коммит прямо на странице PR, до мержа — так закрывается формат squash-коммита;
- `Merge pull request …` и `Revert "…"` проходят по исключениям в начале regex.

Цена: первый коммит в **новом** репозитории (`Initial commit`, README из мастера создания) не пройдёт. Создавайте репозиторий пустым и первым пушем отправляйте коммит в формате, либо исключите новые репозитории из ruleset, пока не появится `main`.

**Проверьте на одном репозитории.** Эти rulesets на реальном репозитории не проверялись. Неизвестно, например, как GitHub оценит коммиты `dev`, влитые в feature-ветку: локальный хук и `server/pre-receive.example` пропускают коммиты, уже лежащие в других ветках, а rulesets могут проверить их как новые для этой ветки. Документация GitHub про squash противоречит сама себе: в одном месте проверяется только итоговый коммит, в другом — все коммиты ветки по правилам базовой. Включите ruleset сначала в режиме **Evaluate** (Enterprise) и посмотрите Rule Insights, потом — Active.

#### Без Enterprise (Team)

Rulesets организации: обязательный PR, запрет force push и удаления на общих ветках, и правило *Require workflows to pass before merging* с workflow [`github/git-flow-check.yml`](github/git-flow-check.yml):

1. Положите его в центральный репозиторий организации как `.github/workflows/git-flow-check.yml`.
2. В ruleset организации на общие ветки добавьте *Require workflows to pass before merging* с этим файлом.

Workflow запускается на открытие PR, новые коммиты и правку заголовка. Он вызывает `.githooks/check-range` проверяемого репозитория — те же правила из его `git-flow.conf`: имя ветки, заголовок PR (станет сообщением squash-коммита) и все коммиты PR, включая ключ и почту. Репозиторий без `drop-in/` проверку не пройдёт. Пуши в ветки без PR workflow не видит — их ловят только локальные хуки.

Репозиторные rulesets могут только **ужесточить** org-правила, не ослабить. В **этом** репозитории (`guidelines`) на `main` дополнительно: required status check `test` (`.github/workflows/test.yml`).

### GitLab Self-Managed — global server hooks

Чтобы не настраивать каждый проект: положите `server/pre-receive.example` в глобальный каталог хуков как `pre-receive.d/git-flow` ([Git server hooks](https://docs.gitlab.com/administration/server_hooks/), `custom_hooks_dir` в настройках Gitaly), исполняемым и с владельцем `git`. Настройки в начале файла = `git-flow.conf`.

Глобальный хук срабатывает на **каждом** репозитории инстанса, поэтому в нём есть серверные настройки:

- `SKIP_REPO_DIR_RE` — вики (`.wiki.git`), дизайны (`.design.git`) и сниппеты (`@snippets/…`, а также `GL_REPOSITORY=snippet-…`) пропускаются: иначе правка вики или сниппета через интерфейс отклонялась бы;
- `PROJECT_INCLUDE_RE` / `PROJECT_EXCLUDE_RE` — по `GL_PROJECT_PATH` (`group/project`): подключите только группы, которые приняли flow, или исключите инфраструктуру и зеркала;
- **весь** первый пуш в пустой репозиторий хук не проверяет: `Initial commit`, README при создании проекта, а также импорт существующей истории (`git push --all` / `--mirror`) с любыми ветками и коммитами. Со второго пуша — обычные правила.

Сначала поставьте хук с узким `PROJECT_INCLUDE_RE` (одна группа), проверьте и только потом расширяйте охват.

Хук отклонит и ветки, которые создаёт сам GitLab: `revert-<sha>` (кнопка Revert), `cherry-pick-<sha>` (Cherry-pick), `123-issue-title` (Create merge request из задачи), `<user>-main-patch-NNNNN` (Web IDE). При создании задайте имя по формату (`hotfix/PROJ-123`) или добавьте эти шаблоны в `SKIP_BRANCH_RE` — тогда их имя и коммиты проверяться не будут.

**Push rules** (Admin → Push rules / Settings группы) — удобный UI с regex имени ветки и сообщения коммита, но это **шаблон при создании** проекта: смена глобальных/групповых push rules **не обновляет** уже существующие проекты. Для «сразу на все репо» используйте global server hook, а не push rules.

Коммиты, которые создаёт сам GitLab, тоже проходят проверку. В шаблоне группы или в каждом проекте задайте:

- **Merge suggestions commit message template:** `%{branch_name} - Apply %{suggestions_count} suggestion(s) to %{files_count} file(s)`;
- **Squash commit message template:** `%{title}` и заголовок MR в формате коммита.

В Web IDE пишите сообщение в том же формате: «Update file …» не пройдёт.

### GitHub Enterprise Server

Два варианта на весь инстанс/орг:

1. Organization rulesets — как на GitHub.com.
2. Pre-receive hooks на уровне GHES — тот же `server/pre-receive.example` (полный контроль, включая ключ и почту). Охват — через включение хука на org/repo в настройках GHES или `PROJECT_INCLUDE_RE` / `PROJECT_EXCLUDE_RE` по `GITHUB_REPO_NAME` (`owner/repo`).

### Bitbucket Data Center

Включите pre-receive / merge check на уровне **Project**: репозитории наследуют настройки, override можно запретить. Готового regex «как в `git-flow.conf`» в коробке может не быть — ставят плагин (например, commit message checker) или свой hook с теми же выражениями, что в `server/pre-receive.example`.

### Azure DevOps

На уровне **Project** (или через шаблон политик): branch policies — обязательный PR на `main`/`dev`, запрет прямого пуша. Формат ветки и сообщения коммита встроенной политикой не проверяются: добавьте pipeline, который вызывает `sh .githooks/check-range "$SOURCE" "origin/$TARGET" HEAD "$PR_TITLE"` (ветки из `System.PullRequest.SourceBranch` / `TargetBranch` без `refs/heads/`), и назначьте его **Build validation** на защищённые ветки. Pipeline видит только PR в эти ветки — прямые пуши в незащищённые `feature/*` он не проверяет (это не замена pre-receive на каждый push).

## Тесты

Из корня этого репозитория (нужны `git` и `sh`):

```bash
sh tests/run.sh
```

Скрипт поднимает временный bare-remote и working tree, копирует `drop-in/.githooks`, включает их и прогоняет сценарии: формат и ключ коммита, первый пуш поверх legacy history, merge env в feature, суффикс ветки, ключи Jira/Task Flow, Azure-preset, dependabot, env-ветки, почта автора, husky-обёртки, `server/pre-receive.example` (в том числе как глобальный хук: первый пуш в пустой репозиторий, вики, сниппеты, охват по `GL_PROJECT_PATH` и по каталогу), `.githooks/check-range` для CI, совпадение настроек конфига и серверного хука. Exit 1 при любом несовпадении.

В этом репозитории тот же прогон идёт в GitHub Actions (`.github/workflows/test.yml`) на каждый PR и на push в `main`. Ruleset на `main` требует зелёный check `test` и pull request — без прошедших тестов мерж закрыт.

## Комментарии

Правила меняются только в `git-flow.conf`; после правки повторите значения в `server/pre-receive.example`, в org/instance rulesets или push rules вашей git-системы. Регулярки атрибуции PanDev трогайте, только если ключ перестал разбираться встроенными парсерами (см. «Регулярки атрибуции»).
