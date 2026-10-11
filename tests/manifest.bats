#!/usr/bin/env bats
#
# The hooks never see the userConfig defaults from plugin.json (Claude Code only
# exports values the user saved in /config). The built-in fallbacks in
# lib/common.sh therefore have to mirror the manifest by hand; these tests keep
# both sources in sync.

load test_helper

setup() {
  source "$REPO_ROOT/scripts/lib/common.sh"
  MANIFEST="$REPO_ROOT/.claude-plugin/plugin.json"
}

@test "built-in default mode matches the userConfig default" {
  [ "$(jq -r .userConfig.default_mode.default "$MANIFEST")" = "$CT_DEFAULT_MODE" ]
}

@test "built-in default level matches the userConfig default" {
  [ "$(jq -r .userConfig.default_level.default "$MANIFEST")" = "$CT_DEFAULT_LEVEL" ]
}

@test "mode options in the manifest match the modes the hooks accept" {
  [ "$(jq -r '.userConfig.default_mode.options | join(" ")' "$MANIFEST")" = "$CT_MODES" ]
}

@test "level options in the manifest match the levels the hooks accept" {
  [ "$(jq -r '.userConfig.default_level.options | join(" ")' "$MANIFEST")" = "$CT_LEVELS" ]
}

@test "every script referenced in hooks.json exists" {
  while IFS= read -r path; do
    [ -f "$REPO_ROOT/${path#\$\{CLAUDE_PLUGIN_ROOT\}/}" ]
  done < <(jq -r '.hooks[][].hooks[].args[]? | select(startswith("${CLAUDE_PLUGIN_ROOT}"))' "$REPO_ROOT/hooks/hooks.json")
}
