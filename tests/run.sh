#!/bin/sh
# Прогон правил git-flow на временном bare + working tree.
# Запуск из корня пакета: sh tests/run.sh
# Нужны: git, sh. Без npm/pytest. Exit 1 при любом несовпадении.
set -u

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
PASS=0
FAIL=0
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
commit_msg() {
  f="f_$(date +%s)_$RANDOM$$"
  echo x > "$f"
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

for key in QA2-15 MY_APP-7 PROJ-12_jira PROJ-12_jira_2; do
  git checkout -q -b "feature/$key" origin/dev
  expect PASS "commit+push key $key" sh -c "
    f=f_\$\$\$RANDOM; echo x > \"\$f\"; git add \"\$f\"
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
