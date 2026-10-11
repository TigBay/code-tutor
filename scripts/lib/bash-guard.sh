# shellcheck shell=bash
#
# Best-effort detection of shell commands that write files inside the project.
#
# The command is first reduced to a skeleton (quoted text and heredoc bodies
# removed, see shell-skeleton.awk), then checked for
#   - output redirection (>, >>, &>, >|) to a file
#   - commands at command position that change files (cp, mv, rm, tee, sed -i,
#     git restore, Symfony make:*, PowerShell Set-Content, ...)
#
# Paths outside the project (for example /tmp) are allowed. Unknown or relative
# paths count as inside the project. Code passed as a string to an interpreter
# (python -c, php -r, bash -c, ...) is not inspected: see README "Limitations".
# Requires lib/common.sh.

CT_GUARD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CT_GUARD_PROJECT=""
# 1 while checking a command whose file arguments are supplied at runtime
# (after xargs or find -exec), so "rm" without paths still counts as a write.
CT_GUARD_DYNAMIC_ARGS=0

ct_realpath() {
  realpath -m -- "$1" 2>/dev/null || printf '%s\n' "$1"
}

# ct__inside_project <path>: true unless the path is clearly outside the project.
ct__inside_project() {
  local path="$1"
  # the command is text, so "~" and "$HOME" are still literal and expanded here
  # shellcheck disable=SC2088
  case "$path" in
    "~/"*) path="$HOME/${path#"~/"}" ;;
    '$HOME/'*) path="$HOME/${path#'$HOME/'}" ;;
    '${HOME}/'*) path="$HOME/${path#'${HOME}/'}" ;;
  esac
  [[ "$path" == /* ]] || return 0
  path="$(ct_realpath "$path")"
  [[ "$path" == "$CT_GUARD_PROJECT" || "$path" == "$CT_GUARD_PROJECT"/* ]]
}

# ct__first_inside <paths...>: print the first path inside the project.
ct__first_inside() {
  local p
  for p in "$@"; do
    if ct__inside_project "$p"; then
      printf '%s\n' "$p"
      return 0
    fi
  done
  return 1
}

# ct__redirect_reason <skeleton>
ct__redirect_reason() {
  local s="$1" target
  local re='(^|[^-=<>])(&|[0-9]*)>>?\|?[[:space:]]*(&?[^[:space:];|&<>()]*)'
  while [[ "$s" =~ $re ]]; do
    target="${BASH_REMATCH[3]}"
    s="${s#*"${BASH_REMATCH[0]}"}"
    case "$target" in
      "" | "&"* | /dev/null | /dev/stdout | /dev/stderr | /dev/tty | /dev/fd/*) continue ;;
    esac
    if ct__inside_project "$target"; then
      printf 'output redirection to %s\n' "$target"
      return 0
    fi
  done
  return 1
}

# ct__non_options <args...>: print arguments that do not start with "-".
ct__non_options() {
  local a
  for a in "$@"; do
    [[ "$a" == -* ]] || printf '%s\n' "$a"
  done
}

ct__git_reason() {
  local -a a=("$@")
  local i=0 n=$#
  while (( i < n )); do
    case "${a[i]}" in
      -C | -c | --git-dir | --work-tree | --namespace) i=$((i + 2)) ;;
      -*) i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  (( i < n )) || return 1

  local sub="${a[i]}"
  local -a rest=("${a[@]:i+1}")
  local -a positional=()
  local arg
  for arg in "${rest[@]}"; do
    [[ "$arg" == -* ]] || positional+=("$arg")
  done

  case "$sub" in
    restore | clean | apply | am | mv | rm)
      echo "git $sub changes files"; return 0 ;;
    checkout)
      for arg in "${rest[@]}"; do
        case "$arg" in
          -- | -f | --force | -p | --patch) echo "git checkout restores files"; return 0 ;;
        esac
      done
      if (( ${#positional[@]} >= 2 )); then
        echo "git checkout restores files"; return 0
      fi
      ;;
    reset)
      for arg in "${rest[@]}"; do
        case "$arg" in
          --hard | --merge | --keep) echo "git reset $arg changes files"; return 0 ;;
        esac
      done
      ;;
    stash)
      case "${rest[0]:-push}" in
        list | show) ;;
        *) echo "git stash changes files"; return 0 ;;
      esac
      ;;
  esac
  return 1
}

# ct__segment_reason <words...>: check one simple command.
ct__segment_reason() {
  local -a w=("$@")
  local i=0 n=$#

  # skip variable assignments, shell keywords and wrapper commands
  while (( i < n )); do
    case "${w[i]}" in
      [A-Za-z_]*=*) i=$((i + 1)) ;;
      '{' | '}' | '!' | if | then | else | elif | do | while | until) i=$((i + 1)) ;;
      sudo | command | exec | nice | nohup | time | env | builtin)
        i=$((i + 1))
        while (( i < n )) && [[ "${w[i]}" == -* ]]; do
          case "${w[i]}" in -u | -g | -C | -n) i=$((i + 1)) ;; esac
          i=$((i + 1))
        done
        ;;
      xargs)
        CT_GUARD_DYNAMIC_ARGS=1
        i=$((i + 1))
        while (( i < n )) && [[ "${w[i]}" == -* ]]; do
          case "${w[i]}" in -I | -n | -P | -L | -d | -s | -E | -a) i=$((i + 1)) ;; esac
          i=$((i + 1))
        done
        ;;
      *) break ;;
    esac
  done
  (( i < n )) || return 1

  local cmd="${w[i]##*/}"
  local -a args=("${w[@]:i+1}")
  local -a paths=()
  local arg path j
  mapfile -t paths < <(ct__non_options "${args[@]}")

  case "$cmd" in
    rm | rmdir | mv | touch | truncate | unlink | shred)
      # these change every path they are given
      if (( ${#paths[@]} == 0 )); then
        (( CT_GUARD_DYNAMIC_ARGS )) || return 1
        echo "$cmd changes the files passed to it"; return 0
      fi
      path="$(ct__first_inside "${paths[@]}")" || return 1
      echo "$cmd changes $path"; return 0
      ;;
    cp | ln | install | rsync)
      # only the destination (last path) is written
      if (( ${#paths[@]} == 0 )); then
        (( CT_GUARD_DYNAMIC_ARGS )) || return 1
        echo "$cmd writes the files passed to it"; return 0
      fi
      path="${paths[${#paths[@]}-1]}"
      ct__inside_project "$path" || return 1
      echo "$cmd writes to $path"; return 0
      ;;
    patch)
      echo "patch changes files"; return 0
      ;;
    tee)
      for path in "${paths[@]}"; do
        [[ "$path" == /dev/* ]] && continue
        if ct__inside_project "$path"; then
          echo "tee writes to $path"; return 0
        fi
      done
      ;;
    sed)
      for arg in "${args[@]}"; do
        if [[ "$arg" == --in-place* || "$arg" =~ ^-[nErsuz]*i ]]; then
          echo "sed edits files in place"; return 0
        fi
      done
      ;;
    perl | ruby)
      for arg in "${args[@]}"; do
        if [[ "$arg" =~ ^-[pnlae0]*i ]]; then
          echo "$cmd edits files in place"; return 0
        fi
      done
      ;;
    dd)
      for arg in "${args[@]}"; do
        if [[ "$arg" == of=* ]] && ct__inside_project "${arg#of=}"; then
          echo "dd writes to ${arg#of=}"; return 0
        fi
      done
      ;;
    find)
      for (( j = 0; j < ${#args[@]}; j++ )); do
        case "${args[j]}" in
          -delete) echo "find -delete removes files"; return 0 ;;
          -exec | -execdir | -ok | -okdir)
            CT_GUARD_DYNAMIC_ARGS=1
            ct__segment_reason "${args[@]:j+1}" && return 0
            ;;
        esac
      done
      ;;
    git)
      ct__git_reason "${args[@]}" && return 0
      ;;
    php | symfony | console)
      for arg in "${args[@]}"; do
        if [[ "$arg" == make:* ]]; then
          echo "the Symfony maker command $arg generates files"; return 0
        fi
      done
      ;;
    *)
      case "$(tr '[:upper:]' '[:lower:]' <<<"$cmd")" in
        set-content | add-content | clear-content | out-file | new-item | remove-item | copy-item | move-item | rename-item)
          echo "$cmd changes files"; return 0
          ;;
      esac
      ;;
  esac
  return 1
}

# ct_bash_write_reason <project> <command>
# Print a short reason and return 0 when the command writes inside the project.
ct_bash_write_reason() {
  CT_GUARD_PROJECT="$(ct_realpath "$1")"
  local skeleton segment c
  skeleton="$(printf '%s\n' "$2" | awk -f "$CT_GUARD_LIB_DIR/shell-skeleton.awk")"

  ct__redirect_reason "$skeleton" && return 0

  # split into simple commands at operators, subshells and substitutions;
  # braces are left alone ({} and ${VAR} are words, "{ ...; }" is handled as keyword)
  skeleton="${skeleton//&&/$'\n'}"
  skeleton="${skeleton//||/$'\n'}"
  for c in ';' '|' '&' '(' ')' '`'; do
    skeleton="${skeleton//"$c"/$'\n'}"
  done

  local -a words
  while IFS= read -r segment; do
    read -ra words <<<"$segment"
    (( ${#words[@]} > 0 )) || continue
    CT_GUARD_DYNAMIC_ARGS=0
    ct__segment_reason "${words[@]}" && return 0
  done <<<"$skeleton"
  return 1
}
