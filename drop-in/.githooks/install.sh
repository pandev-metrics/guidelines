#!/bin/sh
# Включает локальные git-flow хуки для этого клона.
# Запуск из корня репозитория: sh .githooks/install.sh
# С husky не запускать: husky сам владеет core.hooksPath (см. README).
set -eu
root=$(git rev-parse --show-toplevel)
cd "$root"
if [ ! -f .githooks/git-flow.conf ]; then
  echo "Нет .githooks/git-flow.conf — сначала скопируйте содержимое drop-in/ в корень репозитория." >&2
  exit 1
fi
chmod +x .githooks/commit-msg .githooks/prepare-commit-msg .githooks/pre-push .githooks/install.sh
git config core.hooksPath .githooks
echo "OK: core.hooksPath=$(git config --get core.hooksPath)"
if [ -z "$(git config --get user.email || true)" ]; then
  echo "Внимание: не задан user.email. Задайте рабочую почту: git config user.email <почта>" >&2
fi
