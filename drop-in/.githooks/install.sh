#!/bin/sh
# Включает локальные git-flow хуки для этого клона.
# Запуск из корня репозитория: sh .githooks/install.sh
set -eu
root=$(git rev-parse --show-toplevel)
cd "$root"
if [ ! -f .githooks/commit-msg ]; then
  echo "Нет .githooks/commit-msg — сначала скопируйте drop-in/.githooks в корень репо." >&2
  exit 1
fi
chmod +x .githooks/commit-msg .githooks/prepare-commit-msg .githooks/pre-push .githooks/install.sh
git config core.hooksPath .githooks
echo "OK: core.hooksPath=.githooks"
git config --get core.hooksPath
