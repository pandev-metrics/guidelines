# Общие проверки git flow. Подключается хуками: . "$(dirname "$0")/lib.sh"
# Правила задаются в git-flow.conf рядом с этим файлом; здесь их не меняют.

. "$(dirname "$0")/git-flow.conf"

if [ "$ALLOW_BRANCH_SUFFIX" = 1 ]; then
  BRANCH_RE="^($BRANCH_TYPES)/($KEY_RE)(-[a-z0-9][a-z0-9-]*)?\$"
else
  BRANCH_RE="^($BRANCH_TYPES)/($KEY_RE)\$"
fi
COMMIT_RE="^($COMMIT_TYPES)/($KEY_RE) - .+"
# «слово-число» в хвосте: PanDev без учёта регистра прочтёт его как второй ключ.
TAIL_KEY_RE='(^|-)[a-z][a-z0-9]*-[0-9]'

matches() { printf '%s' "$1" | grep -qE "$2"; }

is_zero_sha() {
  case "$1" in
    *[!0]*) return 1 ;;
    *) return 0 ;;
  esac
}

is_env_branch() { matches "$1" "$ENV_BRANCH_RE"; }
is_skip_branch() { [ -n "$SKIP_BRANCH_RE" ] && matches "$1" "$SKIP_BRANCH_RE"; }
is_skip_subject() { [ -n "$SKIP_SUBJECT_RE" ] && matches "$1" "$SKIP_SUBJECT_RE"; }

# Ключ задачи из имени рабочей ветки; пусто, если ветка не рабочая.
branch_key() {
  matches "$1" "$BRANCH_RE" || return 0
  printf '%s' "$1" | sed -E "s#^($BRANCH_TYPES)/($KEY_RE).*#\\2#"
}

# «тип/КЛЮЧ» из имени рабочей ветки, без хвоста.
branch_prefix() {
  matches "$1" "$BRANCH_RE" || return 0
  printf '%s' "$1" | sed -E "s#^(($BRANCH_TYPES)/($KEY_RE)).*#\\1#"
}

strip_fixup() { printf '%s' "$1" | sed -E 's/^((fixup|squash|amend)! )+//'; }

branch_tail() { printf '%s' "$1" | sed -E "s#^($BRANCH_TYPES)/($KEY_RE)##"; }

check_branch_name() {
  is_env_branch "$1" && return 0
  is_skip_branch "$1" && return 0
  if matches "$1" "$BRANCH_RE"; then
    matches "$(branch_tail "$1")" "$TAIL_KEY_RE" || return 0
    echo "git-flow: в хвосте ветки «${1}» есть «слово-число» — PanDev прочтёт его как второй ключ задачи." >&2
    echo "  Уберите число из хвоста или замените дефис: feature/PROJ-123-login, а не feature/PROJ-123-proj-124." >&2
    return 1
  fi
  echo "git-flow: ветка «${1}» должна называться «feature/PROJ-123» (префиксы: ${BRANCH_TYPES})." >&2
  if [ "$ALLOW_BRANCH_SUFFIX" != 1 ]; then
    echo "  Хвост после ключа запрещён (ALLOW_BRANCH_SUFFIX=0 в git-flow.conf)." >&2
  fi
  return 1
}

# $1 — subject, $2 — ветка (может быть пустой), $3 — что показать в ошибке (sha или пусто).
check_subject() {
  is_skip_subject "$1" && return 0
  subj=$(strip_fixup "$1")
  where=${3:+коммит ${3}: }
  if ! matches "$subj" "$COMMIT_RE"; then
    echo "git-flow: ${where}сообщение должно быть вида «feature/PROJ-123 - Описание»." >&2
    echo "  Дано: ${1}" >&2
    return 1
  fi
  bkey=$(branch_key "$2")
  [ -n "$bkey" ] || return 0
  ckey=$(printf '%s' "$subj" | sed -E "s#^($COMMIT_TYPES)/($KEY_RE) - .*#\\2#")
  if [ "$ckey" != "$bkey" ]; then
    echo "git-flow: ${where}ключ ${ckey} не совпадает с ключом ветки ${bkey}." >&2
    echo "  При мерже ключи из коммитов двигают задачи по статусам — чужой ключ сдвинет чужую задачу." >&2
    return 1
  fi
}

# $1 — почта автора, $2 — что показать в ошибке.
check_email() {
  [ -n "$ALLOWED_EMAIL_RE" ] || return 0
  matches "$1" "$ALLOWED_EMAIL_RE" && return 0
  echo "git-flow: ${2:+${2}: }почта автора «${1}» не рабочая (ALLOWED_EMAIL_RE в git-flow.conf)." >&2
  echo "  Задайте её: git config user.email <рабочая почта>" >&2
  return 1
}
