#!/bin/sh
# Прогон правил git-flow на временном bare + working tree.
# Запуск из корня пакета: sh tests/run.sh
# Нужны: git, sh. Без npm/pytest. Exit 1 при любом несовпадении.
set -u

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
PASS=0
FAIL=0
SEQ=0
T=$(mktemp -d)
trap 'cd /; rm -rf "$T"' EXIT INT TERM

ok() { PASS=$((PASS + 1)); printf 'ok   %s\n' "$1"; }
fail() {
  FAIL=$((FAIL + 1))
  printf 'FAIL %s\n' "$1"
  [ -s "$T/err" ] && sed 's/^/     /' "$T/err" | head -5
}

# expect PASS|REJECT, label, command…
expect() {
  exp=$1
  label=$2
  shift 2
  if "$@" >/dev/null 2>"$T/err"; then
    got=PASS
  else
    got=REJECT
  fi
  if [ "$got" = "$exp" ]; then
    ok "$label"
  else
    fail "$label (ожидали $exp, получили $got)"
  fi
}

# Чистый bare + клон с Initial commit на origin/dev и включёнными хуками.
setup() {
  rm -rf "$T/r.git" "$T/w"
  git init -q --bare "$T/r.git"
  git init -q -b dev "$T/w"
  cd "$T/w" || exit 1
  git config user.email 'dev@company.com'
  git config user.name 'Tester'
  git remote add origin "$T/r.git"
  echo seed > README.md
  git add README.md
  git commit -qm 'Initial commit'
  git push -q origin dev
  cp -R "$ROOT/drop-in/.githooks" .
  sh .githooks/install.sh >/dev/null
}

# Новый файл + коммит (без конфликтов при последующих merge).
# SEQ наращиваем в текущем shell: $(…) был бы сабшеллом и сбрасывал счётчик.
commit_msg() {
  SEQ=$((SEQ + 1))
  f="f_${$}_${SEQ}"
  echo "x$SEQ" > "$f"
  git add "$f"
  git commit -q -m "$1"
}

# ---------------------------------------------------------------------------
printf '### local hooks\n'
setup

git checkout -qb feature/PROJ-1
expect PASS 'commit feature/PROJ-1 - Ok' commit_msg 'feature/PROJ-1 - Ok'
expect PASS 'first push over legacy history' git push origin feature/PROJ-1
expect REJECT 'commit with other key on feature/PROJ-1' commit_msg 'feature/PROJ-2 - Wrong key'
expect PASS 'commit hotfix/PROJ-1 on feature/PROJ-1 (type may differ)' commit_msg 'hotfix/PROJ-1 - Type differs'
echo y >> README.md
git add README.md
expect PASS 'commit --fixup' git commit -q --fixup HEAD
commit_msg 'fix: rewritten'
subj=$(git log -1 --format=%s)
if [ "$subj" = 'feature/PROJ-1 - rewritten' ]; then
  ok "prepare-commit-msg rewrote 'fix: rewritten'"
else
  fail "prepare-commit-msg expected 'feature/PROJ-1 - rewritten', got '$subj'"
fi
expect PASS 'push after fixup and rewrite' git push origin feature/PROJ-1

git checkout -q dev
commit_msg 'feature/PROJ-9 - On dev'
git push -q origin dev
git checkout -q feature/PROJ-1
git merge -q --no-edit -m 'Merge branch dev into feature/PROJ-1' dev
expect PASS 'push after merging dev (other-key commits) into feature' git push origin feature/PROJ-1

for b in PROJ-12_login PROJ-12_csv PROJ-12_asana_2; do
  expect REJECT "push feature/$b (import suffix unknown to PanDev)" git push origin origin/dev:refs/heads/feature/$b
done

for key in QA2-15 MY_APP-7 PROJ-12_jira PROJ-12_jira_2 PROJ-12_clickup PROJ-12_yandex_3; do
  git checkout -q -b "feature/$key" origin/dev
  expect PASS "commit+push key $key" sh -c "
    f=f_${key}_\$\$; echo x > \"\$f\"; git add \"\$f\"
    git commit -q -m 'feature/$key - Ok' && git push -q origin \"feature/$key\"
  "
done

git checkout -q -b feature/PROJ-1-login origin/dev
commit_msg 'feature/PROJ-1 - Ok'
expect REJECT 'push feature/PROJ-1-login (suffix off)' git push origin feature/PROJ-1-login

git checkout -q -b dependabot/npm/x origin/dev
git commit -q --no-verify --allow-empty -m 'chore(deps): bump x from 1 to 2'
expect PASS 'push dependabot/ with chore(deps) commit' git push origin dependabot/npm/x

git checkout -q origin/dev
git commit -q --allow-empty -m 'chore(deps): bump x from 1 to 2 (#3)'
expect PASS 'squash of bot PR on env branch' git push origin HEAD:dev

git checkout -q -b claude/feature-xyz origin/dev
expect REJECT 'agent worktree branch claude/…' git push origin claude/feature-xyz

for b in production live uat qa preprod stage staging develop; do
  expect PASS "push to env branch $b" git push origin origin/dev:refs/heads/"$b"
done
expect REJECT 'push to sandbox (not in env list)' git push origin origin/dev:refs/heads/sandbox

git checkout -q -b misc origin/dev
expect REJECT 'commit wip on non-feature branch' commit_msg 'wip'
git checkout -q --detach origin/dev
expect PASS 'commit on detached HEAD with format (no key check)' commit_msg 'feature/PROJ-5 - Detached'

# ---------------------------------------------------------------------------
printf '### ALLOW_BRANCH_SUFFIX=1\n'
setup
# portable in-place edit (BSD/GNU sed)
sed 's/^ALLOW_BRANCH_SUFFIX=0/ALLOW_BRANCH_SUFFIX=1/' .githooks/git-flow.conf > "$T/conf" && mv "$T/conf" .githooks/git-flow.conf
git checkout -q -b feature/PROJ-1-login
commit_msg 'fix: login'
subj=$(git log -1 --format=%s)
if [ "$subj" = 'feature/PROJ-1 - login' ]; then
  ok "prepare-commit-msg with suffix branch -> 'feature/PROJ-1 - login'"
else
  fail "prepare-commit-msg with suffix: got '$subj'"
fi
expect PASS 'push feature/PROJ-1-login when suffix allowed' git push origin feature/PROJ-1-login
git checkout -q -b feature/PROJ-1-PROJ-2 origin/dev
expect REJECT 'push feature/PROJ-1-PROJ-2 (second key in tail)' git push origin feature/PROJ-1-PROJ-2
for b in feature/PROJ-1-proj-124 feature/PROJ-1-login-fix-2; do
  expect REJECT "push $b (lowercase second key in tail)" git push origin origin/dev:refs/heads/$b
done
expect PASS 'push feature/PROJ-1-login-v2 (no word-number)' git push origin origin/dev:refs/heads/feature/PROJ-1-login-v2

# ---------------------------------------------------------------------------
printf '### ClickUp preset\n'
setup
sed "s/^KEY_RE=.*/KEY_RE='(CU-)?[0-9][0-9a-z]{6,11}'/" .githooks/git-flow.conf > "$T/conf" && mv "$T/conf" .githooks/git-flow.conf
for b in 869dmarzn CU-869dmarzn; do
  expect PASS "push feature/$b" git push origin origin/dev:refs/heads/feature/$b
done
for b in payments refactor 869dm; do
  expect REJECT "push feature/$b (not a ClickUp id)" git push origin origin/dev:refs/heads/feature/$b
done

# ---------------------------------------------------------------------------
printf '### Azure preset KEY_RE=[0-9]+\n'
setup
sed "s/^KEY_RE=.*/KEY_RE='[0-9]+'/" .githooks/git-flow.conf > "$T/conf" && mv "$T/conf" .githooks/git-flow.conf
git checkout -q -b feature/4521
expect PASS 'commit feature/4521 - Ok' commit_msg 'feature/4521 - Ok'
expect PASS 'push feature/4521' git push origin feature/4521
# Jira-форму имени ветки при Azure-preset отклоняет pre-push (коммит через --no-verify)
git checkout -q -b feature/PROJ-1 origin/dev
git commit -q --no-verify --allow-empty -m 'feature/PROJ-1 - Ok'
expect REJECT 'Azure preset rejects Jira-style branch name' git push origin feature/PROJ-1

# ---------------------------------------------------------------------------
printf '### ALLOWED_EMAIL_RE\n'
setup
sed "s/^ALLOWED_EMAIL_RE=.*/ALLOWED_EMAIL_RE='@company\\\\.com\$'/" .githooks/git-flow.conf > "$T/conf" && mv "$T/conf" .githooks/git-flow.conf
git checkout -q -b feature/PROJ-1
expect PASS 'work email accepted' commit_msg 'feature/PROJ-1 - Ok'
git config user.email 'me@gmail.com'
expect REJECT 'personal email rejected at commit' commit_msg 'feature/PROJ-1 - Gmail'
git commit -q --no-verify --allow-empty -m 'feature/PROJ-1 - Gmail'
expect REJECT 'personal email rejected at push' git push origin feature/PROJ-1

# ---------------------------------------------------------------------------
printf '### husky wrappers\n'
setup
mkdir .husky
cp "$ROOT"/node/.husky/commit-msg "$ROOT"/node/.husky/prepare-commit-msg "$ROOT"/node/.husky/pre-push .husky/
chmod +x .husky/*
git config core.hooksPath .husky
git checkout -q -b misc origin/dev
expect REJECT 'husky: commit-msg rejects wip' commit_msg 'wip'
git checkout -q -b feature/PROJ-1 origin/dev
expect REJECT 'husky: commit-msg rejects other key' commit_msg 'feature/PROJ-2 - x'
commit_msg 'plain text'
subj=$(git log -1 --format=%s)
if [ "$subj" = 'feature/PROJ-1 - plain text' ]; then
  ok 'husky prepare-commit-msg rewrote bare subject'
else
  fail "husky prepare-commit-msg: got '$subj'"
fi
git checkout -q -b bad origin/dev
expect REJECT 'husky: pre-push rejects bad branch' git push origin bad

# ---------------------------------------------------------------------------
printf '### server pre-receive (local hooks off)\n'
setup
git config core.hooksPath /dev/null
cp "$ROOT/server/pre-receive.example" "$T/r.git/hooks/pre-receive"
chmod +x "$T/r.git/hooks/pre-receive"

git checkout -q -b feature/PROJ-1 origin/dev
commit_msg 'feature/PROJ-1 - Ok'
expect PASS 'server: new feature branch' git push origin feature/PROJ-1

git checkout -q origin/dev
commit_msg 'feature/PROJ-8 - On dev'
expect PASS 'server: push to env branch' git push origin HEAD:dev

git checkout -q feature/PROJ-1
git merge -q --no-edit -m 'Merge branch dev into feature/PROJ-1' origin/dev
expect PASS 'server: feature after merging env' git push origin feature/PROJ-1

commit_msg 'feature/PROJ-2 - Wrong'
expect REJECT 'server: wrong key on feature' git push origin feature/PROJ-1
git reset -q --hard HEAD~1

expect REJECT 'server: suffix branch' git push origin HEAD:refs/heads/feature/PROJ-1-login
expect REJECT 'server: unknown import suffix' git push origin HEAD:refs/heads/feature/PROJ-1_csv
sed 's/^ALLOW_BRANCH_SUFFIX=0/ALLOW_BRANCH_SUFFIX=1/' "$ROOT/server/pre-receive.example" > "$T/r.git/hooks/pre-receive"
expect PASS 'server: suffix allowed, plain tail' git push origin HEAD:refs/heads/feature/PROJ-1-login
expect REJECT 'server: suffix allowed, lowercase second key' git push origin HEAD:refs/heads/feature/PROJ-1-proj-2
cp "$ROOT/server/pre-receive.example" "$T/r.git/hooks/pre-receive"

git checkout -q -b dependabot/x origin/dev
git commit -q --allow-empty -m 'chore(deps): bump'
expect PASS 'server: dependabot' git push origin dependabot/x

git checkout -q origin/dev
git commit -q --allow-empty -m 'Apply 1 suggestion(s) to 1 file(s)'
expect REJECT 'server: GitLab suggestion default message' git push origin HEAD:dev
git reset -q --hard HEAD~1
git commit -q --allow-empty -m 'feature/PROJ-1 - Apply 1 suggestion(s) to 1 file(s)'
expect PASS 'server: suggestion with template' git push origin HEAD:dev

expect PASS 'server: env production' git push origin origin/dev:refs/heads/production

git checkout -q -b misc origin/dev
git commit -q --allow-empty -m 'wip'
expect REJECT 'server: bad branch in covered project' git push origin misc
expect PASS 'server: GL_PROJECT_PATH in PROJECT_EXCLUDE_RE' sh -c "
  sed \"s|^PROJECT_EXCLUDE_RE=.*|PROJECT_EXCLUDE_RE='^infra/'|\" '$ROOT/server/pre-receive.example' > '$T/r.git/hooks/pre-receive'
  GL_PROJECT_PATH=infra/tools git push -q origin misc:refs/heads/misc
"
sed "s|^PROJECT_INCLUDE_RE=.*|PROJECT_INCLUDE_RE='^backend/'|" "$ROOT/server/pre-receive.example" > "$T/r.git/hooks/pre-receive"
expect REJECT 'server: GL_PROJECT_PATH inside PROJECT_INCLUDE_RE' env GL_PROJECT_PATH=backend/api git push origin misc:refs/heads/misc2
expect PASS 'server: GL_PROJECT_PATH outside PROJECT_INCLUDE_RE' env GL_PROJECT_PATH=frontend/app git push origin misc:refs/heads/misc2
expect REJECT 'server: GITHUB_REPO_NAME inside PROJECT_INCLUDE_RE' env GITHUB_REPO_NAME=backend/api git push origin misc:refs/heads/misc3
cp "$ROOT/server/pre-receive.example" "$T/r.git/hooks/pre-receive"
expect PASS 'server: GL_REPOSITORY=snippet-* skipped' env GL_REPOSITORY=snippet-7 git push origin misc:refs/heads/misc3
cp "$ROOT/server/pre-receive.example" "$T/r.git/hooks/pre-receive"

printf '### server pre-receive as global hook\n'
mkdir -p "$T/g/@snippets/ab"
cd "$T/g" || exit 1
git init -q -b main src
cd src || exit 1
git config user.email 'dev@company.com'
git config user.name 'Tester'
git config core.hooksPath /dev/null
git commit -q --allow-empty -m 'Initial commit'
# Служебные репозитории: история есть до установки хука, чтобы не сработал пропуск пустого репо.
for r in empty.git wiki.wiki.git @snippets/ab/s1.git; do
  git init -q --bare "$T/g/$r"
done
git push -q "$T/g/wiki.wiki.git" main
git push -q "$T/g/@snippets/ab/s1.git" main
for r in empty.git wiki.wiki.git @snippets/ab/s1.git; do
  cp "$ROOT/server/pre-receive.example" "$T/g/$r/hooks/pre-receive"
  chmod +x "$T/g/$r/hooks/pre-receive"
done
expect PASS 'server: first push into empty repo' git push "$T/g/empty.git" main
git commit -q --allow-empty -m 'Update README'
expect REJECT 'server: next bad commit after init' git push "$T/g/empty.git" main
expect PASS 'server: wiki repo (.wiki.git) skipped' git push "$T/g/wiki.wiki.git" main
expect PASS 'server: snippet repo (@snippets/) skipped' git push "$T/g/@snippets/ab/s1.git" main

# ---------------------------------------------------------------------------
printf '### check-range (CI на PR)\n'
setup
git config core.hooksPath /dev/null
git checkout -q -b feature/PROJ-1 origin/dev
commit_msg 'feature/PROJ-1 - Ok'
expect PASS 'ci: good branch, title, commits' sh .githooks/check-range feature/PROJ-1 origin/dev HEAD 'feature/PROJ-1 - Login'
expect REJECT 'ci: bad PR title' sh .githooks/check-range feature/PROJ-1 origin/dev HEAD 'feat: login'
expect REJECT 'ci: bad branch name' sh .githooks/check-range misc origin/dev HEAD ''
commit_msg 'feature/PROJ-2 - Wrong'
expect REJECT 'ci: commit with other key' sh .githooks/check-range feature/PROJ-1 origin/dev HEAD ''
expect PASS 'ci: dependabot branch skipped' sh .githooks/check-range dependabot/npm/x origin/dev HEAD 'Bump x'

# ---------------------------------------------------------------------------
printf '### conf vs pre-receive settings\n'
cd "$ROOT" || exit 1
for v in KEY_RE BRANCH_TYPES COMMIT_TYPES ALLOW_BRANCH_SUFFIX ENV_BRANCH_RE SKIP_BRANCH_RE SKIP_SUBJECT_RE ALLOWED_EMAIL_RE; do
  a=$(grep "^$v=" drop-in/.githooks/git-flow.conf)
  b=$(grep "^$v=" server/pre-receive.example)
  if [ "$a" = "$b" ]; then
    ok "setting $v matches"
  else
    fail "setting $v differs: local='$a' server='$b'"
  fi
done

# ---------------------------------------------------------------------------
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
