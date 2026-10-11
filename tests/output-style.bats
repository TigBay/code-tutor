#!/usr/bin/env bats
#
# The output style is static for a session, so it relies on the state note
# that the UserPromptSubmit hook adds. These tests keep both in sync and pin
# the design decision that the style stays optional.

load test_helper

setup() {
  setup_env
  source "$REPO_ROOT/scripts/lib/common.sh"
  STYLE="$REPO_ROOT/output-styles/tutor.md"
}

# frontmatter <field>: value of a frontmatter field in the style file.
frontmatter() {
  awk -v field="$1" '
    NR == 1 && $0 == "---" { inside = 1; next }
    inside && $0 == "---" { exit }
    inside && index($0, field ": ") == 1 { print substr($0, length(field) + 3) }
  ' "$STYLE"
}

@test "the style has a name and a description" {
  [ "$(frontmatter name)" = tutor ]
  [ -n "$(frontmatter description)" ]
}

@test "the style keeps Claude Code's coding instructions" {
  [ "$(frontmatter keep-coding-instructions)" = true ]
}

@test "the style is optional and not forced on every user of the plugin" {
  [ -z "$(frontmatter force-for-plugin)" ]
}

@test "the note prefix the style refers to is what the hook emits" {
  prefix="code-tutor plugin state:"
  grep -qF "\"$prefix\"" "$STYLE"
  for mode in tutor explain; do
    ct_state_update "$CLAUDE_PROJECT_DIR" '.mode = $m' --arg m "$mode"
    run_hook on-prompt-submit.sh "$(submit_input 'x')"
    [[ "$(jq -r .hookSpecificOutput.additionalContext <<<"$output")" == "$prefix"* ]]
  done
}

@test "the style names the hint command that exists" {
  grep -qF '/code-tutor:hint' "$STYLE"
  [ -f "$REPO_ROOT/skills/hint/SKILL.md" ]
}
