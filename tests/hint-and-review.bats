#!/usr/bin/env bats

load test_helper

setup() {
  setup_env
  source "$REPO_ROOT/scripts/lib/common.sh"
  P="$CLAUDE_PROJECT_DIR"
}

state_field() {
  jq -r ".$1 // empty" "$(ct_state_file "$P")"
}

context() {
  jq -r .hookSpecificOutput.additionalContext <<<"$output"
}

hint() {
  run_hook on-command-expand.sh "$(expand_input code-tutor:hint "${1:-}" "${2:-session-1}")"
}

review() {
  run_hook on-command-expand.sh "$(expand_input code-tutor:tutor-review "$1")"
}

# --- hint ladder -------------------------------------------------------------------

@test "the first hint goes one rung above the level" {
  for pair in low:2 medium:3 high:4; do
    ct_state_clear "$P"
    ct_state_update "$P" '.mode = "tutor" | .level = $l' --arg l "${pair%%:*}"
    hint
    [ "$status" -eq 0 ]
    [ "$(state_field hint_rung)" = "${pair##*:}" ]
  done
}

@test "each hint climbs one rung and stops at the top" {
  ct_state_update "$P" '.mode = "tutor" | .level = "low"'
  for expected in 2 3 4 5 5; do
    hint
    [ "$(state_field hint_rung)" = "$expected" ]
  done
  [[ "$(context)" == *"already on the top rung"* ]]
}

@test "the hint context names the rung and its content" {
  ct_state_update "$P" '.mode = "tutor" | .level = "high"'
  hint
  [[ "$(context)" == *"rung 4 of 5 (level high starts on rung 3)"* ]]
  [[ "$(context)" == *"skeleton"* ]]
  hint
  [[ "$(context)" == *"complete solution as code in the chat"* ]]
}

@test "the ladder is stored for the session that climbed it" {
  ct_state_update "$P" '.mode = "tutor" | .level = "medium"'
  hint "" s1
  [ "$(state_field hint_session)" = s1 ]
  hint "" s1
  [ "$(state_field hint_rung)" = 4 ]
  # a new session starts again above the level's rung
  hint "" s2
  [ "$(state_field hint_rung)" = 3 ]
  [ "$(state_field hint_session)" = s2 ]
}

@test "/hint reset returns to the level's rung" {
  ct_state_update "$P" '.mode = "tutor" | .level = "medium" | .hint_rung = 5 | .hint_session = "session-1"'
  hint reset
  [ -z "$(state_field hint_rung)" ]
  [[ "$(context)" == *"reset"*"rung 2 of 5 again"* ]]
}

@test "/tutor resets the ladder" {
  ct_state_update "$P" '.mode = "tutor" | .hint_rung = 5 | .hint_session = "session-1"'
  run_hook on-command-expand.sh "$(expand_input code-tutor:tutor medium)"
  [ -z "$(state_field hint_rung)" ]
  [ -z "$(state_field hint_session)" ]
}

@test "/hint outside tutor mode blocks with an explanation" {
  hint
  [ "$(jq -r .decision <<<"$output")" = block ]
  [[ "$(jq -r .reason <<<"$output")" == *"works in tutor mode (current mode: off)"* ]]
  [ ! -f "$(ct_state_file "$P")" ]
}

@test "/hint works when tutor mode comes from the project file" {
  write_project_file '{"mode":"tutor","level":"low"}'
  hint
  [ "$(state_field hint_rung)" = 2 ]
}

@test "/hint with an unknown argument blocks" {
  ct_state_update "$P" '.mode = "tutor"'
  hint please
  [ "$(jq -r .decision <<<"$output")" = block ]
  [[ "$(jq -r .reason <<<"$output")" == *"Usage: /code-tutor:hint [reset]"* ]]
}

@test "on rung 5 the write guard asks instead of denying" {
  ct_state_update "$P" '.mode = "tutor" | .level = "high"'
  hint; hint
  [ "$(state_field hint_rung)" = 5 ]
  input="$(tool_input_json Edit "$(jq -n --arg p "$P/src/A.php" '{file_path: $p}')" | jq '.session_id = "session-1"')"
  run_hook on-pre-tool-use.sh "$input"
  [ "$(jq -r .hookSpecificOutput.permissionDecision <<<"$output")" = ask ]
  # another session is back below the top rung and gets deny
  run_hook on-pre-tool-use.sh "$(jq '.session_id = "other"' <<<"$input")"
  [ "$(jq -r .hookSpecificOutput.permissionDecision <<<"$output")" = deny ]
}

# --- review --------------------------------------------------------------------------

@test "review without arguments targets uncommitted changes and does not save" {
  review ""
  [ "$status" -eq 0 ]
  [[ "$(context)" == *"review target: the uncommitted changes"* ]]
  [[ "$(context)" == *"Save learnings to LEARNINGS.md: no"* ]]
  [[ "$(context)" == *"Today is $(date +%Y-%m-%d)"* ]]
}

@test "review with save and a path" {
  mkdir -p "$P/src"
  touch "$P/src/Foo.php"
  review "SAVE src/Foo.php"
  [[ "$(context)" == *"the files at src/Foo.php"* ]]
  [[ "$(context)" == *"LEARNINGS.md: yes"* ]]
}

@test "review with a git ref" {
  git -C "$P" init -q
  git -C "$P" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
  review "HEAD~0 save"
  [[ "$(context)" == *"the changes since HEAD~0"* ]]
  [[ "$(context)" == *"LEARNINGS.md: yes"* ]]
}

@test "review with an unknown target blocks" {
  review "does/not/exist"
  [ "$(jq -r .decision <<<"$output")" = block ]
  [[ "$(jq -r .reason <<<"$output")" == *"neither a file in the project nor a git commit"* ]]
}

@test "review arguments are not glob-expanded" {
  touch "$P/a.php" "$P/b.php"
  cd "$P"
  review "*"
  [ "$(jq -r .decision <<<"$output")" = block ]
  [[ "$(jq -r .reason <<<"$output")" == *"'*'"* ]]
}

@test "review resets the hint ladder" {
  ct_state_update "$P" '.mode = "tutor" | .hint_rung = 5 | .hint_session = "session-1"'
  review ""
  [ -z "$(state_field hint_rung)" ]
}

@test "review does not create a state file when there is none" {
  review ""
  [ ! -f "$(ct_state_file "$P")" ]
}
