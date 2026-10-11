# shellcheck shell=bash
#
# Text building blocks that the hooks add to Claude's context.
#
# The wording is deliberately factual ("the user wants ...", "edits are denied")
# rather than imperative system-style commands: the Claude Code docs note that
# text framed as out-of-band instructions can trigger prompt-injection defenses.
# Requires lib/common.sh.

# ct_source_label <source>: human readable origin of a setting.
ct_source_label() {
  case "$1" in
    state) echo "set for this project via /code-tutor:tutor" ;;
    project) echo "from $CT_PROJECT_FILE" ;;
    config) echo "from /config" ;;
    *) echo "built-in default" ;;
  esac
}

# ct_status_line: one line describing the resolved settings (after ct_resolve).
ct_status_line() {
  local line
  line="mode=$CT_MODE ($(ct_source_label "$CT_MODE_SOURCE")), level=$CT_LEVEL ($(ct_source_label "$CT_LEVEL_SOURCE"))"
  [[ -z "$CT_RUNG" ]] || line+=", hint rung=$CT_RUNG/$CT_MAX_RUNG"
  printf '%s\n' "$line"
}

# ct_rung_rule <rung>: what an answer on this rung of the hint ladder contains.
# Rungs 1-3 are the levels low, medium and high.
ct_rung_rule() {
  case "$1" in
    1) echo "point to the relevant area of the code, give the direction and 2-4 targeted guiding questions (for example \"How does X relate to Y?\") that let the user find the cause. The questions do not contain the fix, not as an either-or choice and not as an assumption such as \"after you move it\". No method names, no steps, no code." ;;
    2) echo "name the file and method, the concept or pattern that is needed and what has to change. No syntax, no pseudocode." ;;
    3) echo "name the file and method or line range, give concrete steps in order, name the fitting functions, classes or APIs, and add pseudocode where it helps. No complete solution." ;;
    4) echo "show a skeleton of the change with only the decisive lines written out and the rest left as TODO comments for the user. Still not the complete solution." ;;
    5) echo "show the complete solution as code in the chat with a short explanation of each change. Claude writes it into files only when the user explicitly asks for that; the user then confirms the write in a permission prompt." ;;
  esac
}

# ct_level_rule <level>: what an answer on this level contains.
ct_level_rule() {
  echo "Level $1: $(ct_rung_rule "$(ct_start_rung "$1")")"
}

# ct_ladder_rule: the current hint rung, if /code-tutor:hint raised it (after ct_resolve).
ct_ladder_rule() {
  [[ -n "$CT_RUNG" ]] || return 0
  echo "Hint ladder: the user asked for more concrete hints with /code-tutor:hint; answers on the current task stay on rung $CT_RUNG of $CT_MAX_RUNG: $(ct_rung_rule "$CT_RUNG")"
}

# ct_mode_context: full context for the current mode (after ct_resolve).
# Prints nothing in mode off, so the plugin costs no tokens there.
ct_mode_context() {
  ct__mode_context_lines | sed '/^$/d'
}

ct__mode_context_lines() {
  case "$CT_MODE" in
    tutor)
      cat <<EOF
code-tutor plugin state: $(ct_status_line).
In tutor mode the user writes the code themselves in order to learn. Claude does not change project files: a PreToolUse hook denies Edit, Write, NotebookEdit and file-writing Bash commands inside the project; LEARNINGS.md is the only exception. Files outside the project, such as plan or scratch files, are not restricted.
Claude first analyzes the relevant code itself and then answers with hints, so that the user understands the core idea within a few minutes instead of searching for hours.
$(ct_level_rule "$CT_LEVEL")
$(ct_ladder_rule)
A complete solution is shown only on the top rung of /code-tutor:hint, as text in the chat. /code-tutor:tutor off returns to normal editing.
EOF
      ;;
    explain)
      cat <<EOF
code-tutor plugin state: $(ct_status_line).
In explain mode the user wants to understand existing code. Claude explains structure, data flow, patterns and pitfalls with references to concrete files and methods, and does not change project files: a PreToolUse hook denies Edit, Write, NotebookEdit and file-writing Bash commands inside the project. Improvement ideas are welcome as text.
EOF
      ;;
  esac
}
