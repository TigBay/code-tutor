# shellcheck shell=bash
#
# Shared helpers for the code-tutor hook scripts.
#
# Settings are resolved per field (mode and level independently), first
# valid value wins:
#   1. state file   ${CLAUDE_PLUGIN_DATA}/projects/<sha256(project)>.json (set by /tutor)
#   2. project file <project>/.code-tutor.json                            (checked in by a team)
#   3. userConfig   CLAUDE_PLUGIN_OPTION_DEFAULT_MODE / _LEVEL             (/config)
#   4. built-in     CT_DEFAULT_MODE / CT_DEFAULT_LEVEL
#
# userConfig defaults from plugin.json are NOT exported to hooks (only values
# saved in /config are), so the built-in defaults must match plugin.json;
# tests/manifest.bats checks that.

readonly CT_MODES="off tutor explain"
readonly CT_LEVELS="low medium high"
readonly CT_DEFAULT_MODE="off"
readonly CT_DEFAULT_LEVEL="medium"
readonly CT_MAX_RUNG=5
readonly CT_PROJECT_FILE=".code-tutor.json"

# Separator for multi-value jq output. Not whitespace, so `read` keeps empty fields.
readonly CT_SEP=$'\x1f'

CT_INPUT=""

# ct_require_jq: exit cleanly with a visible message when jq is missing.
# Hooks fail open, so normal Claude Code behavior continues without the plugin.
ct_require_jq() {
  command -v jq >/dev/null 2>&1 && return 0
  printf '{"systemMessage":"code-tutor: jq is not installed, so the plugin is inactive. Install jq (for example: sudo apt install jq, brew install jq)."}\n'
  exit 0
}

# ct_read_input: store the hook's JSON input from stdin in CT_INPUT.
ct_read_input() {
  CT_INPUT="$(cat)"
}

# ct_input <jq-path>: print a string field of the hook input, empty if absent.
ct_input() {
  jq -r "$1 // empty" <<<"$CT_INPUT" 2>/dev/null || true
}

# ct_is_one_of <value> <space separated list>
ct_is_one_of() {
  [[ "$1" != *" "* ]] || return 1
  case " $2 " in
    *" $1 "*) [[ -n "$1" ]] ;;
    *) return 1 ;;
  esac
}

# ct_project_dir: the project the session belongs to.
ct_project_dir() {
  local dir="${CLAUDE_PROJECT_DIR:-}"
  [[ -n "$dir" ]] || dir="$(ct_input .cwd)"
  [[ -n "$dir" ]] || dir="$PWD"
  printf '%s\n' "${dir%/}"
}

ct_data_dir() {
  printf '%s\n' "${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/code-tutor}"
}

ct_hash() {
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | cut -d' ' -f1
  else
    printf '%s' "$1" | shasum -a 256 | cut -d' ' -f1
  fi
}

# ct_state_file <project>
ct_state_file() {
  printf '%s/projects/%s.json\n' "$(ct_data_dir)" "$(ct_hash "$1")"
}

# ct_read_fields <file>: print "mode<SEP>level<SEP>hint_rung<SEP>hint_session"
# of a JSON file. Missing or corrupt files yield empty fields.
ct_read_fields() {
  local file="$1"
  if [[ -f "$file" ]]; then
    jq -r --arg sep "$CT_SEP" \
      '[.mode // "", .level // "", (.hint_rung // "" | tostring), .hint_session // ""] | join($sep)' \
      "$file" 2>/dev/null && return 0
  fi
  printf '%s%s%s\n' "$CT_SEP" "$CT_SEP" "$CT_SEP"
}

# ct_resolve <project> [session_id]
# Set CT_MODE, CT_LEVEL, CT_RUNG and CT_MODE_SOURCE, CT_LEVEL_SOURCE.
# The hint rung belongs to the session that climbed the ladder: when a
# session_id is given and differs from the stored one (new session, /clear),
# CT_RUNG is empty and the ladder starts again at the level's rung.
# shellcheck disable=SC2034 # the CT_* results are read by the sourcing hook scripts
ct_resolve() {
  local project="$1" session="${2:-}"
  local s_mode s_level s_rung s_session p_mode p_level _unused

  IFS="$CT_SEP" read -r s_mode s_level s_rung s_session < <(ct_read_fields "$(ct_state_file "$project")")
  IFS="$CT_SEP" read -r p_mode p_level _unused < <(ct_read_fields "$project/$CT_PROJECT_FILE")

  CT_MODE="$CT_DEFAULT_MODE"
  CT_MODE_SOURCE="default"
  if ct_is_one_of "$s_mode" "$CT_MODES"; then
    CT_MODE="$s_mode"; CT_MODE_SOURCE="state"
  elif ct_is_one_of "$p_mode" "$CT_MODES"; then
    CT_MODE="$p_mode"; CT_MODE_SOURCE="project"
  elif ct_is_one_of "${CLAUDE_PLUGIN_OPTION_DEFAULT_MODE:-}" "$CT_MODES"; then
    CT_MODE="$CLAUDE_PLUGIN_OPTION_DEFAULT_MODE"; CT_MODE_SOURCE="config"
  fi

  CT_LEVEL="$CT_DEFAULT_LEVEL"
  CT_LEVEL_SOURCE="default"
  if ct_is_one_of "$s_level" "$CT_LEVELS"; then
    CT_LEVEL="$s_level"; CT_LEVEL_SOURCE="state"
  elif ct_is_one_of "$p_level" "$CT_LEVELS"; then
    CT_LEVEL="$p_level"; CT_LEVEL_SOURCE="project"
  elif ct_is_one_of "${CLAUDE_PLUGIN_OPTION_DEFAULT_LEVEL:-}" "$CT_LEVELS"; then
    CT_LEVEL="$CLAUDE_PLUGIN_OPTION_DEFAULT_LEVEL"; CT_LEVEL_SOURCE="config"
  fi

  CT_RUNG=""
  if [[ "$s_rung" =~ ^[1-9][0-9]*$ ]] && (( s_rung <= CT_MAX_RUNG )) &&
    [[ -z "$session" || "$s_session" == "$session" ]]; then
    CT_RUNG="$s_rung"
  fi
}

# ct_session: session_id from the hook input (empty when unknown).
ct_session() {
  ct_input .session_id
}

# ct_start_rung <level>: the rung a normal answer on this level is on.
# The first /code-tutor:hint goes one rung higher.
ct_start_rung() {
  case "$1" in
    low) echo 1 ;;
    high) echo 3 ;;
    *) echo 2 ;;
  esac
}

# ct_state_update <project> <jq-filter> [jq args...]
# Apply a jq filter to the project's state and write it atomically.
# Returns non-zero, leaving the old state untouched, when it cannot write.
ct_state_update() {
  local project="$1" filter="$2"
  shift 2
  local file dir current tmp
  file="$(ct_state_file "$project")"
  dir="$(dirname "$file")"
  mkdir -p "$dir" 2>/dev/null || return 1

  current="{}"
  if [[ -f "$file" ]] && jq -e 'type == "object"' "$file" >/dev/null 2>&1; then
    current="$(cat "$file")"
  fi

  tmp="$(mktemp "$dir/.state.XXXXXX" 2>/dev/null)" || return 1
  if jq --arg project "$project" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$@" \
      "$filter | .project = \$project | .updated_at = \$now" <<<"$current" >"$tmp" &&
    mv -f "$tmp" "$file"; then
    return 0
  else
    rm -f "$tmp"
    return 1
  fi
}

# ct_state_clear <project>: drop the per-project override.
ct_state_clear() {
  rm -f "$(ct_state_file "$1")" 2>/dev/null
}

# ct_emit_context <event> <text>: print hook output that adds context for Claude.
ct_emit_context() {
  jq -n --arg event "$1" --arg text "$2" \
    '{hookSpecificOutput: {hookEventName: $event, additionalContext: $text}}'
}
