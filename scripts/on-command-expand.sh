#!/usr/bin/env bash
#
# UserPromptExpansion hook for the plugin's own slash commands.
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
      ct_state_update "$project" '.mode = $mode | del(.hint_rung)' --arg mode "$arg" || save_failed
      ;;
    low | medium | high)
      ct_state_update "$project" '.mode = "tutor" | .level = $level | del(.hint_rung)' --arg level "$arg" || save_failed
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

main() {
  ct_require_jq
  ct_read_input

  local name args project
  name="$(ct_input .command_name)"
  # first word, lower case; further words are ignored
  args="$(ct_input .command_args | tr '[:upper:]' '[:lower:]')"
  read -r args _ <<<"$args" || true
  project="$(ct_project_dir)"

  case "$name" in
    code-tutor:tutor) handle_tutor "$project" "$args" ;;
    *) exit 0 ;;
  esac
}

main
