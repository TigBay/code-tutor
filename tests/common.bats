#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load test_helper

setup() {
  setup_env
  # shellcheck source=../scripts/lib/common.sh
  source "$REPO_ROOT/scripts/lib/common.sh"
}

# --- defaults and precedence -------------------------------------------------

@test "without any configuration mode is off and level is medium" {
  ct_resolve "$CLAUDE_PROJECT_DIR"
  [ "$CT_MODE" = off ]
  [ "$CT_MODE_SOURCE" = default ]
  [ "$CT_LEVEL" = medium ]
  [ "$CT_LEVEL_SOURCE" = default ]
  [ -z "$CT_RUNG" ]
}

@test "userConfig overrides the built-in defaults" {
  export CLAUDE_PLUGIN_OPTION_DEFAULT_MODE=tutor
  export CLAUDE_PLUGIN_OPTION_DEFAULT_LEVEL=high
  ct_resolve "$CLAUDE_PROJECT_DIR"
  [ "$CT_MODE" = tutor ]
  [ "$CT_MODE_SOURCE" = config ]
  [ "$CT_LEVEL" = high ]
  [ "$CT_LEVEL_SOURCE" = config ]
}

@test "project file overrides userConfig" {
  export CLAUDE_PLUGIN_OPTION_DEFAULT_MODE=off
  write_project_file '{"mode":"explain","level":"low"}'
  ct_resolve "$CLAUDE_PROJECT_DIR"
  [ "$CT_MODE" = explain ]
  [ "$CT_MODE_SOURCE" = project ]
  [ "$CT_LEVEL" = low ]
}

@test "state file overrides project file" {
  write_project_file '{"mode":"explain","level":"low"}'
  ct_state_update "$CLAUDE_PROJECT_DIR" '.mode = "tutor"'
  ct_resolve "$CLAUDE_PROJECT_DIR"
  [ "$CT_MODE" = tutor ]
  [ "$CT_MODE_SOURCE" = state ]
  # level is resolved independently and still comes from the project file
  [ "$CT_LEVEL" = low ]
  [ "$CT_LEVEL_SOURCE" = project ]
}

@test "invalid values are skipped and the next layer wins" {
  export CLAUDE_PLUGIN_OPTION_DEFAULT_LEVEL=high
  write_project_file '{"mode":"yolo","level":"extreme"}'
  ct_resolve "$CLAUDE_PROJECT_DIR"
  [ "$CT_MODE" = off ]
  [ "$CT_LEVEL" = high ]
}

@test "a corrupt project file is ignored" {
  write_project_file '{not json'
  ct_resolve "$CLAUDE_PROJECT_DIR"
  [ "$CT_MODE" = off ]
}

@test "a corrupt state file is ignored and replaced on the next update" {
  file="$(ct_state_file "$CLAUDE_PROJECT_DIR")"
  mkdir -p "$(dirname "$file")"
  echo 'garbage' >"$file"
  ct_resolve "$CLAUDE_PROJECT_DIR"
  [ "$CT_MODE" = off ]

  ct_state_update "$CLAUDE_PROJECT_DIR" '.mode = "tutor"'
  ct_resolve "$CLAUDE_PROJECT_DIR"
  [ "$CT_MODE" = tutor ]
}

# --- state file ----------------------------------------------------------------

@test "state is stored per project" {
  other="$BATS_TEST_TMPDIR/other"
  ct_state_update "$CLAUDE_PROJECT_DIR" '.mode = "tutor"'
  ct_resolve "$other"
  [ "$CT_MODE" = off ]
  [ "$(ct_state_file "$CLAUDE_PROJECT_DIR")" != "$(ct_state_file "$other")" ]
}

@test "state file lives under CLAUDE_PLUGIN_DATA and records the project path" {
  ct_state_update "$CLAUDE_PROJECT_DIR" '.mode = "explain"'
  file="$(ct_state_file "$CLAUDE_PROJECT_DIR")"
  [[ "$file" == "$CLAUDE_PLUGIN_DATA/projects/"*.json ]]
  [ "$(jq -r .project "$file")" = "$CLAUDE_PROJECT_DIR" ]
  [ -n "$(jq -r .updated_at "$file")" ]
}

@test "updates merge with the existing state" {
  ct_state_update "$CLAUDE_PROJECT_DIR" '.mode = "tutor"'
  ct_state_update "$CLAUDE_PROJECT_DIR" '.level = $level' --arg level high
  ct_resolve "$CLAUDE_PROJECT_DIR"
  [ "$CT_MODE" = tutor ]
  [ "$CT_LEVEL" = high ]
}

@test "a failing update leaves the previous state and no temp files" {
  ct_state_update "$CLAUDE_PROJECT_DIR" '.mode = "tutor"'
  run ct_state_update "$CLAUDE_PROJECT_DIR" 'this is not jq'
  [ "$status" -ne 0 ]
  ct_resolve "$CLAUDE_PROJECT_DIR"
  [ "$CT_MODE" = tutor ]
  [ -z "$(find "$CLAUDE_PLUGIN_DATA" -name '.state.*')" ]
}

@test "clearing the state falls back to the next layer" {
  write_project_file '{"mode":"explain"}'
  ct_state_update "$CLAUDE_PROJECT_DIR" '.mode = "tutor"'
  ct_state_clear "$CLAUDE_PROJECT_DIR"
  ct_resolve "$CLAUDE_PROJECT_DIR"
  [ "$CT_MODE" = explain ]
}

# --- hint rung -------------------------------------------------------------------

@test "hint rung is read from state when within range" {
  ct_state_update "$CLAUDE_PROJECT_DIR" '.hint_rung = 4'
  ct_resolve "$CLAUDE_PROJECT_DIR"
  [ "$CT_RUNG" = 4 ]
}

@test "out-of-range hint rung is ignored" {
  ct_state_update "$CLAUDE_PROJECT_DIR" '.hint_rung = 9'
  ct_resolve "$CLAUDE_PROJECT_DIR"
  [ -z "$CT_RUNG" ]
}

@test "start rung depends on level" {
  [ "$(ct_start_rung low)" = 1 ]
  [ "$(ct_start_rung medium)" = 2 ]
  [ "$(ct_start_rung high)" = 3 ]
}

# --- helpers -------------------------------------------------------------------

@test "CLAUDE_PROJECT_DIR wins over cwd from the hook input" {
  CT_INPUT='{"cwd":"/somewhere/else"}'
  [ "$(ct_project_dir)" = "$CLAUDE_PROJECT_DIR" ]
}

@test "project paths with spaces and quotes round-trip through the state" {
  weird="$BATS_TEST_TMPDIR/my \"odd\" project's dir"
  mkdir -p "$weird"
  ct_state_update "$weird" '.mode = "explain"'
  ct_resolve "$weird"
  [ "$CT_MODE" = explain ]
  [ "$(jq -r .project "$(ct_state_file "$weird")")" = "$weird" ]
}

@test "project dir falls back to cwd from the hook input" {
  unset CLAUDE_PROJECT_DIR
  CT_INPUT='{"cwd":"/srv/app/"}'
  [ "$(ct_project_dir)" = /srv/app ]
}

@test "ct_is_one_of rejects empty values and partial matches" {
  ct_is_one_of tutor "$CT_MODES"
  run ! ct_is_one_of "" "$CT_MODES"
  run ! ct_is_one_of tut "$CT_MODES"
  run ! ct_is_one_of "off tutor" "$CT_MODES"
}

@test "ct_emit_context produces valid hook output" {
  run ct_emit_context UserPromptSubmit 'line one
line "two"'
  [ "$status" -eq 0 ]
  [ "$(jq -r .hookSpecificOutput.hookEventName <<<"$output")" = UserPromptSubmit ]
  [ "$(jq -r .hookSpecificOutput.additionalContext <<<"$output")" = 'line one
line "two"' ]
}
