#!/usr/bin/env bash
#
# UserPromptExpansion hook for the plugin's own slash commands
# (/code-tutor:tutor, /code-tutor:hint, /code-tutor:tutor-review).
# Runs before the skill text reaches Claude and before UserPromptSubmit, so the
# state is already updated when Claude reads it. Arguments arrive as a JSON
# field, never through a shell, so they cannot inject commands.
#
# command_name always carries the plugin namespace, also when the user typed
# the short form (/tutor -> code-tutor:tutor).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/context.sh
source "$SCRIPT_DIR/lib/context.sh"

readonly TUTOR_USAGE="off | tutor | explain | low | medium | high | reset | status"

# block <reason>: stop the expansion and show the reason to the user (costs no model call).
block() {
  jq -n --arg reason "$1" '{decision: "block", reason: $reason}'
  exit 0
}

# save_failed: block instead of letting Claude confirm a change that never happened.
save_failed() {
  block "code-tutor: could not save the setting in $(ct_data_dir). Check that the directory is writable."
}

handle_tutor() {
  local project="$1" arg="$2"

  case "$arg" in
    off | tutor | explain)
      ct_state_update "$project" '.mode = $mode | del(.hint_rung, .hint_session)' --arg mode "$arg" || save_failed
      ;;
    low | medium | high)
      ct_state_update "$project" '.mode = "tutor" | .level = $level | del(.hint_rung, .hint_session)' --arg level "$arg" || save_failed
      ;;
    reset)
      ct_state_clear "$project" || save_failed
      ;;
    status | "")
      ;;
    *)
      block "code-tutor: unknown argument '$arg'. Usage: /code-tutor:tutor [$TUTOR_USAGE]"
      ;;
  esac

  ct_resolve "$project"
  ct_emit_context UserPromptExpansion \
    "code-tutor: /code-tutor:tutor ${arg:-status} was processed for project $project. Current setting: $(ct_status_line)."
}

handle_hint() {
  local project="$1" arg="$2" session="$3"

  ct_resolve "$project" "$session"
  if [[ "$CT_MODE" != tutor ]]; then
    block "code-tutor: /code-tutor:hint works in tutor mode (current mode: $CT_MODE). Switch with /code-tutor:tutor low|medium|high."
  fi

  case "$arg" in
    reset)
      ct_state_update "$project" 'del(.hint_rung, .hint_session)' || save_failed
      ct_emit_context UserPromptExpansion \
        "code-tutor: the hint ladder was reset. Answers are on rung $(ct_start_rung "$CT_LEVEL") of $CT_MAX_RUNG again (level $CT_LEVEL); the next /code-tutor:hint goes one rung higher."
      return
      ;;
    "") ;;
    *) block "code-tutor: unknown argument '$arg'. Usage: /code-tutor:hint [reset]" ;;
  esac

  local current next note=""
  current="${CT_RUNG:-$(ct_start_rung "$CT_LEVEL")}"
  next=$(( current < CT_MAX_RUNG ? current + 1 : CT_MAX_RUNG ))
  (( current < CT_MAX_RUNG )) || note=" The ladder was already on the top rung."

  ct_state_update "$project" '.hint_rung = ($rung | tonumber) | .hint_session = $session' \
    --arg rung "$next" --arg session "$session" || save_failed

  ct_emit_context UserPromptExpansion \
    "code-tutor: /code-tutor:hint moved the hint ladder to rung $next of $CT_MAX_RUNG (level $CT_LEVEL starts on rung $(ct_start_rung "$CT_LEVEL")).$note The next hint for the current task is one step more concrete than the previous answers and contains exactly this: $(ct_rung_rule "$next")"
}

# handle_review: reset the ladder and tell Claude what to review.
handle_review() {
  local project="$1" args="$2"
  local save="no" target="" word description
  local -a words=()

  # read -ra splits without glob expansion (an unquoted $args would expand "*")
  read -ra words <<<"$args" || true
  for word in "${words[@]}"; do
    if [[ "$(tr '[:upper:]' '[:lower:]' <<<"$word")" == save ]]; then
      save="yes"
    elif [[ -z "$target" ]]; then
      target="$word"
    fi
  done

  if [[ -z "$target" ]]; then
    description="the uncommitted changes in the project (git diff HEAD plus untracked files from git status)"
  elif [[ -e "$project/$target" || ( "$target" == /* && -e "$target" ) ]]; then
    description="the files at $target"
  elif git -C "$project" rev-parse --verify --quiet "$target^{commit}" >/dev/null 2>&1; then
    description="the changes since $target (git diff $target, plus uncommitted changes)"
  else
    block "code-tutor: '$target' is neither a file in the project nor a git commit. Usage: /code-tutor:tutor-review [save] [path|git-ref]"
  fi

  if [[ -f "$(ct_state_file "$project")" ]]; then
    ct_state_update "$project" 'del(.hint_rung, .hint_session)' || save_failed
  fi

  ct_emit_context UserPromptExpansion \
    "code-tutor: review target: $description. Save learnings to LEARNINGS.md: $save. Today is $(date +%Y-%m-%d). The hint ladder was reset."
}

main() {
  ct_require_jq
  ct_read_input

  local name raw_args first project
  name="$(ct_input .command_name)"
  raw_args="$(ct_input .command_args)"
  # first word, lower case; further words are ignored by /tutor and /hint
  first="$(tr '[:upper:]' '[:lower:]' <<<"$raw_args")"
  read -r first _ <<<"$first" || true
  project="$(ct_project_dir)"

  case "$name" in
    code-tutor:tutor) handle_tutor "$project" "$first" ;;
    code-tutor:hint) handle_hint "$project" "$first" "$(ct_session)" ;;
    code-tutor:tutor-review) handle_review "$project" "$raw_args" ;;
    *) exit 0 ;;
  esac
}

main
