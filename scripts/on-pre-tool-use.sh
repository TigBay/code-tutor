#!/usr/bin/env bash
#
# PreToolUse hook: in tutor and explain mode, stop Claude from changing files
# inside the project.
#
#   Edit, Write, MultiEdit, NotebookEdit  -> deny, except <project>/LEARNINGS.md
#   Bash, PowerShell                       -> deny when lib/bash-guard.sh detects a write
#
# On the top hint rung in tutor mode the decision is "ask" instead of "deny":
# the user may explicitly want the solution in their files and confirms it in
# the permission prompt. Files outside the project (plans, memory, /tmp) are
# never blocked. Mode off produces no output, so the normal permission flow runs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/bash-guard.sh
source "$SCRIPT_DIR/lib/bash-guard.sh"

# decide <what would happen>: print the permission decision for a blocked write.
decide() {
  local what="$1"

  if [[ "$CT_MODE" == tutor && "$CT_RUNG" == "$CT_MAX_RUNG" ]]; then
    jq -n --arg reason "code-tutor (top hint rung): $what. Allow this only if you asked Claude to write the solution into your files." \
      '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $reason}}'
    return
  fi

  local guidance
  if [[ "$CT_MODE" == tutor ]]; then
    guidance="The user writes the code themselves. Instead of changing the file, give a hint at level $CT_LEVEL: point to the place and the next step. Only LEARNINGS.md may be written."
  else
    guidance="Explain mode is read-only. Explain the code instead; improvement ideas are welcome as text."
  fi
  jq -n --arg reason "code-tutor is in $CT_MODE mode: $what. $guidance" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
}

main() {
  ct_require_jq
  ct_read_input

  local project tool path command reason
  project="$(ct_project_dir)"
  ct_resolve "$project"
  [[ "$CT_MODE" != off ]] || exit 0

  CT_GUARD_PROJECT="$(ct_realpath "$project")"
  tool="$(ct_input .tool_name)"

  case "$tool" in
    Edit | Write | MultiEdit | NotebookEdit)
      path="$(ct_input '.tool_input.file_path // .tool_input.notebook_path')"
      [[ -n "$path" && "$path" != /* ]] && path="$project/$path"
      # files outside the project are not the user's code
      [[ -z "$path" ]] || ct__inside_project "$path" || exit 0
      [[ "$(ct_realpath "${path:-/}")" != "$CT_GUARD_PROJECT/LEARNINGS.md" ]] || exit 0
      decide "$tool would change ${path:-a file}"
      ;;
    Bash | PowerShell)
      command="$(ct_input .tool_input.command)"
      reason="$(ct_bash_write_reason "$project" "$command")" || exit 0
      decide "this $tool command writes files ($reason)"
      ;;
  esac
}

main
