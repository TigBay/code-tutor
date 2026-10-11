#!/usr/bin/env bash
#
# UserPromptSubmit hook: add the active mode and level to Claude's context on
# every prompt, so a switch via /code-tutor:tutor takes effect immediately and
# survives context compaction. Silent in mode off.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/context.sh
source "$SCRIPT_DIR/lib/context.sh"

ct_require_jq
ct_read_input
ct_resolve "$(ct_project_dir)" "$(ct_session)"

context="$(ct_mode_context)"
[[ -n "$context" ]] || exit 0
ct_emit_context UserPromptSubmit "$context"
