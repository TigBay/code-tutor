# shellcheck shell=bash
#
# Common setup for all bats files: every test gets its own plugin data dir
# and project dir, and no userConfig values leak in from the developer's shell.

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
export REPO_ROOT

setup_env() {
  export CLAUDE_PLUGIN_DATA="$BATS_TEST_TMPDIR/data"
  export CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR/project"
  mkdir -p "$CLAUDE_PLUGIN_DATA" "$CLAUDE_PROJECT_DIR"
  unset CLAUDE_PLUGIN_OPTION_DEFAULT_MODE CLAUDE_PLUGIN_OPTION_DEFAULT_LEVEL
}

# write_project_file <json>: create .code-tutor.json in the test project.
write_project_file() {
  printf '%s\n' "$1" >"$CLAUDE_PROJECT_DIR/.code-tutor.json"
}

# expand_input <command_name> <command_args> [session_id]: UserPromptExpansion hook input.
expand_input() {
  jq -n --arg name "$1" --arg args "$2" --arg session "${3:-session-1}" --arg cwd "$CLAUDE_PROJECT_DIR" \
    '{hook_event_name: "UserPromptExpansion", expansion_type: "slash_command",
      command_name: $name, command_args: $args, command_source: "plugin",
      prompt: ("/" + $name + " " + $args), cwd: $cwd, session_id: $session}'
}

# submit_input <prompt> [session_id]: UserPromptSubmit hook input.
submit_input() {
  jq -n --arg prompt "$1" --arg session "${2:-session-1}" --arg cwd "$CLAUDE_PROJECT_DIR" \
    '{hook_event_name: "UserPromptSubmit", prompt: $prompt, cwd: $cwd, session_id: $session}'
}

# run_hook <script> <json>: run a hook script with JSON on stdin.
# Claude Code starts hooks with the "bash" on PATH; CT_TEST_BASH picks another
# one, such as /bin/bash 3.2 on macOS.
run_hook() {
  run "${CT_TEST_BASH:-bash}" "$REPO_ROOT/scripts/$1" <<<"$2"
}

# tool_input_json <tool> <tool_input json>: PreToolUse hook input.
tool_input_json() {
  jq -n --arg tool "$1" --argjson input "$2" --arg cwd "$CLAUDE_PROJECT_DIR" \
    '{hook_event_name: "PreToolUse", tool_name: $tool, tool_input: $input, cwd: $cwd}'
}
