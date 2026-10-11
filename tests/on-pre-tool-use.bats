#!/usr/bin/env bats

load test_helper

setup() {
  setup_env
  source "$REPO_ROOT/scripts/lib/common.sh"
  P="$CLAUDE_PROJECT_DIR"
}

set_state() {
  ct_state_update "$P" "$1"
}

edit_input() {
  tool_input_json Edit "$(jq -n --arg p "$1" '{file_path: $p, old_string: "a", new_string: "b"}')"
}

bash_input() {
  tool_input_json Bash "$(jq -n --arg c "$1" '{command: $c}')"
}

decision() {
  jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$output"
}

reason() {
  jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$output"
}

@test "mode off lets every tool through without output" {
  run_hook on-pre-tool-use.sh "$(edit_input "$P/src/Foo.php")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run_hook on-pre-tool-use.sh "$(bash_input 'rm src/Foo.php')"
  [ -z "$output" ]
}

@test "tutor mode denies Edit, Write, MultiEdit and NotebookEdit in the project" {
  set_state '.mode = "tutor" | .level = "medium"'
  for tool in Edit Write MultiEdit; do
    run_hook on-pre-tool-use.sh "$(tool_input_json "$tool" "$(jq -n --arg p "$P/src/Foo.php" '{file_path: $p}')")"
    [ "$(decision)" = deny ]
  done
  run_hook on-pre-tool-use.sh "$(tool_input_json NotebookEdit "$(jq -n --arg p "$P/nb.ipynb" '{notebook_path: $p, new_source: "x"}')")"
  [ "$(decision)" = deny ]
}

@test "the deny reason steers Claude back to giving a hint at the level" {
  set_state '.mode = "tutor" | .level = "high"'
  run_hook on-pre-tool-use.sh "$(edit_input "$P/src/Foo.php")"
  [[ "$(reason)" == *"tutor mode"*"src/Foo.php"*"give a hint at level high"* ]]
}

@test "explain mode denies with an explain-specific reason" {
  write_project_file '{"mode":"explain"}'
  run_hook on-pre-tool-use.sh "$(edit_input "$P/src/Foo.php")"
  [ "$(decision)" = deny ]
  [[ "$(reason)" == *"Explain mode is read-only"* ]]
}

@test "LEARNINGS.md in the project root may be written" {
  set_state '.mode = "tutor"'
  run_hook on-pre-tool-use.sh "$(edit_input "$P/LEARNINGS.md")"
  [ -z "$output" ]
  run_hook on-pre-tool-use.sh "$(edit_input "$P/src/../LEARNINGS.md")"
  [ -z "$output" ]
}

@test "other files named LEARNINGS.md and look-alikes are protected" {
  set_state '.mode = "tutor"'
  for path in "$P/docs/LEARNINGS.md" "$P/LEARNINGS.md.php" "$P/learnings.md"; do
    run_hook on-pre-tool-use.sh "$(edit_input "$path")"
    [ "$(decision)" = deny ]
  done
}

@test "a LEARNINGS.md symlink to source code is protected" {
  set_state '.mode = "tutor"'
  mkdir -p "$P/src"
  touch "$P/src/Foo.php"
  ln -s src/Foo.php "$P/LEARNINGS.md"
  run_hook on-pre-tool-use.sh "$(edit_input "$P/LEARNINGS.md")"
  [ "$(decision)" = deny ]
}

@test "files outside the project such as plans and memory are not blocked" {
  set_state '.mode = "tutor"'
  for path in "$HOME/.claude/plans/plan.md" "/tmp/scratch.php" "$BATS_TEST_TMPDIR/other/x.php"; do
    run_hook on-pre-tool-use.sh "$(edit_input "$path")"
    [ -z "$output" ]
  done
}

@test "a relative file path is resolved against the project" {
  set_state '.mode = "tutor"'
  run_hook on-pre-tool-use.sh "$(edit_input "src/Foo.php")"
  [ "$(decision)" = deny ]
}

@test "file-writing Bash commands are denied with the detected pattern" {
  set_state '.mode = "tutor"'
  run_hook on-pre-tool-use.sh "$(bash_input "sed -i 's/a/b/' src/Foo.php")"
  [ "$(decision)" = deny ]
  [[ "$(reason)" == *"this Bash command writes files (sed edits files in place)"* ]]
}

@test "read-only Bash commands pass without output" {
  set_state '.mode = "tutor"'
  run_hook on-pre-tool-use.sh "$(bash_input 'vendor/bin/phpunit 2>&1 | tail -20')"
  [ -z "$output" ]
}

@test "PowerShell commands go through the same guard" {
  set_state '.mode = "tutor"'
  run_hook on-pre-tool-use.sh "$(tool_input_json PowerShell '{"command":"Set-Content -Path src/Foo.php -Value x"}')"
  [ "$(decision)" = deny ]
}

@test "on the top hint rung a write asks the user instead of denying" {
  set_state '.mode = "tutor" | .hint_rung = 5'
  run_hook on-pre-tool-use.sh "$(edit_input "$P/src/Foo.php")"
  [ "$(decision)" = ask ]
  [[ "$(reason)" == *"Allow this only if you asked Claude"* ]]
  run_hook on-pre-tool-use.sh "$(bash_input 'rm src/Foo.php')"
  [ "$(decision)" = ask ]
}

@test "below the top rung it stays deny" {
  set_state '.mode = "tutor" | .hint_rung = 4'
  run_hook on-pre-tool-use.sh "$(edit_input "$P/src/Foo.php")"
  [ "$(decision)" = deny ]
}

@test "explain mode never asks, even with a leftover top rung" {
  set_state '.mode = "explain" | .hint_rung = 5'
  run_hook on-pre-tool-use.sh "$(edit_input "$P/src/Foo.php")"
  [ "$(decision)" = deny ]
}

@test "unrelated tools are ignored" {
  set_state '.mode = "tutor"'
  run_hook on-pre-tool-use.sh "$(tool_input_json Read "$(jq -n --arg p "$P/src/Foo.php" '{file_path: $p}')")"
  [ -z "$output" ]
}
