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

@test "a raised hint rung is shown with its rule for the same session" {
  ct_state_update "$CLAUDE_PROJECT_DIR" '.mode = "tutor" | .hint_rung = 4 | .hint_session = "s1"'
  run_hook on-prompt-submit.sh "$(submit_input 'next' s1)"
  [[ "$(context)" == *"hint rung=4/5"* ]]
  [[ "$(context)" == *"stay on rung 4 of 5: show a skeleton"* ]]
}

@test "a new session starts at the level's rung again" {
  ct_state_update "$CLAUDE_PROJECT_DIR" '.mode = "tutor" | .hint_rung = 4 | .hint_session = "s1"'
  run_hook on-prompt-submit.sh "$(submit_input 'next' s2)"
  [[ "$(context)" != *"hint rung"* ]]
  [[ "$(context)" != *"Hint ladder"* ]]
}

@test "the context has no empty lines" {
  ct_state_update "$CLAUDE_PROJECT_DIR" '.mode = "tutor"'
  run_hook on-prompt-submit.sh "$(submit_input 'x')"
  [[ "$(context)" != *$'\n\n'* ]]
}

@test "a missing jq yields a visible system message instead of an error" {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  for tool in bash cat dirname; do ln -s "$(command -v "$tool")" "$BATS_TEST_TMPDIR/bin/$tool"; done
  PATH="$BATS_TEST_TMPDIR/bin" run_hook on-prompt-submit.sh '{}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"systemMessage"'*"jq is not installed"* ]]
}
