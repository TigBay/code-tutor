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
