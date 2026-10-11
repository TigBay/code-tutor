#!/usr/bin/env bats

load test_helper

setup() {
  setup_env
  source "$REPO_ROOT/scripts/lib/common.sh"
}

# state_field <field>: read a field from the test project's state file.
state_field() {
  jq -r ".$1 // empty" "$(ct_state_file "$CLAUDE_PROJECT_DIR")"
}

context() {
  jq -r .hookSpecificOutput.additionalContext <<<"$output"
}

@test "/tutor low switches to tutor mode with level low" {
  run_hook on-command-expand.sh "$(expand_input code-tutor:tutor low)"
  [ "$status" -eq 0 ]
  [ "$(state_field mode)" = tutor ]
  [ "$(state_field level)" = low ]
  [[ "$(context)" == *"mode=tutor"*"level=low"* ]]
}

@test "/tutor explain changes the mode and keeps the level" {
  ct_state_update "$CLAUDE_PROJECT_DIR" '.level = "high"'
  run_hook on-command-expand.sh "$(expand_input code-tutor:tutor explain)"
  [ "$(state_field mode)" = explain ]
  [ "$(state_field level)" = high ]
}

@test "/tutor off is stored, so it also overrides a project file" {
  write_project_file '{"mode":"tutor"}'
  run_hook on-command-expand.sh "$(expand_input code-tutor:tutor off)"
  [ "$(state_field mode)" = off ]
  [[ "$(context)" == *"mode=off (set for this project via /code-tutor:tutor)"* ]]
}

@test "changing the mode resets the hint ladder" {
  ct_state_update "$CLAUDE_PROJECT_DIR" '.mode = "tutor" | .hint_rung = 4'
  run_hook on-command-expand.sh "$(expand_input code-tutor:tutor high)"
  [ -z "$(state_field hint_rung)" ]
}

@test "arguments are case-insensitive and extra words are ignored" {
  run_hook on-command-expand.sh "$(expand_input code-tutor:tutor '  HIGH please')"
  [ "$(state_field level)" = high ]
}

@test "/tutor reset removes the project override" {
  write_project_file '{"mode":"explain"}'
  ct_state_update "$CLAUDE_PROJECT_DIR" '.mode = "tutor"'
  run_hook on-command-expand.sh "$(expand_input code-tutor:tutor reset)"
  [ ! -f "$(ct_state_file "$CLAUDE_PROJECT_DIR")" ]
  [[ "$(context)" == *"mode=explain (from .code-tutor.json)"* ]]
}

@test "/tutor status and no argument report without writing state" {
  for arg in status ""; do
    run_hook on-command-expand.sh "$(expand_input code-tutor:tutor "$arg")"
    [ "$status" -eq 0 ]
    [[ "$(context)" == *"mode=off (built-in default)"* ]]
  done
  [ ! -f "$(ct_state_file "$CLAUDE_PROJECT_DIR")" ]
}

@test "an unknown argument blocks the expansion with a usage hint" {
  run_hook on-command-expand.sh "$(expand_input code-tutor:tutor yolo)"
  [ "$status" -eq 0 ]
  [ "$(jq -r .decision <<<"$output")" = block ]
  [[ "$(jq -r .reason <<<"$output")" == *"unknown argument 'yolo'"*"Usage"* ]]
  [ ! -f "$(ct_state_file "$CLAUDE_PROJECT_DIR")" ]
}

@test "shell metacharacters in arguments are treated as plain text" {
  run_hook on-command-expand.sh "$(expand_input code-tutor:tutor '$(touch pwned)')"
  [ "$(jq -r .decision <<<"$output")" = block ]
  [ ! -e pwned ]
  [ ! -e "$CLAUDE_PROJECT_DIR/pwned" ]
}

@test "other commands are ignored" {
  for name in code-tutor:tutor-review other-plugin:tutor; do
    run_hook on-command-expand.sh "$(expand_input "$name" low)"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
  [ ! -f "$(ct_state_file "$CLAUDE_PROJECT_DIR")" ]
}
