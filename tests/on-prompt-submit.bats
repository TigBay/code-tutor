#!/usr/bin/env bats

load test_helper

setup() {
  setup_env
  source "$REPO_ROOT/scripts/lib/common.sh"
}

context() {
  jq -r .hookSpecificOutput.additionalContext <<<"$output"
}

@test "mode off adds no context at all" {
  run_hook on-prompt-submit.sh "$(submit_input 'fix the bug')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "tutor mode adds state, write guard and level rule" {
  ct_state_update "$CLAUDE_PROJECT_DIR" '.mode = "tutor" | .level = "high"'
  run_hook on-prompt-submit.sh "$(submit_input 'fix the bug')"
  [ "$status" -eq 0 ]
  [ "$(jq -r .hookSpecificOutput.hookEventName <<<"$output")" = UserPromptSubmit ]
  [[ "$(context)" == *"mode=tutor"*"level=high"* ]]
  [[ "$(context)" == *"PreToolUse hook denies"* ]]
  [[ "$(context)" == *"Level high:"* ]]
}

@test "each level has its own rule" {
  for level in low medium high; do
    ct_state_update "$CLAUDE_PROJECT_DIR" '.mode = "tutor" | .level = $l' --arg l "$level"
    run_hook on-prompt-submit.sh "$(submit_input 'help')"
    [[ "$(context)" == *"Level $level:"* ]]
  done
}

@test "explain mode describes explaining without edits" {
  write_project_file '{"mode":"explain"}'
  run_hook on-prompt-submit.sh "$(submit_input 'what does this do?')"
  [[ "$(context)" == *"mode=explain (from .code-tutor.json)"* ]]
  [[ "$(context)" == *"data flow"* ]]
  [[ "$(context)" != *"Level "* ]]
}

@test "userConfig default applies when nothing else is set" {
  export CLAUDE_PLUGIN_OPTION_DEFAULT_MODE=tutor
  run_hook on-prompt-submit.sh "$(submit_input 'help')"
  [[ "$(context)" == *"mode=tutor (from /config)"* ]]
}

@test "the hint rung is shown when set" {
  ct_state_update "$CLAUDE_PROJECT_DIR" '.mode = "tutor" | .hint_rung = 3'
  run_hook on-prompt-submit.sh "$(submit_input 'next')"
  [[ "$(context)" == *"hint rung=3/5"* ]]
}

@test "a missing jq yields a visible system message instead of an error" {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  for tool in bash cat dirname; do ln -s "$(command -v "$tool")" "$BATS_TEST_TMPDIR/bin/$tool"; done
  PATH="$BATS_TEST_TMPDIR/bin" run_hook on-prompt-submit.sh '{}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"systemMessage"'*"jq is not installed"* ]]
}
