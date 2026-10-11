# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Plugin manifest with `default_mode` and `default_level` options in `/config`.
- Marketplace file so the repository can be added with `/plugin marketplace add`.
- `/code-tutor:tutor [off|tutor|explain|low|medium|high|reset|status]` switches mode and level per project.
- Per-project settings via `.code-tutor.json`; precedence: `/tutor` state > project file > `/config` > default.
- `UserPromptSubmit` hook adds the active mode and level rules to every prompt (silent in mode `off`).
- `PreToolUse` write guard: in `tutor` and `explain` mode, Edit/Write/NotebookEdit and file-writing
  Bash/PowerShell commands inside the project are denied with a reason that steers Claude back to hints.
  `LEARNINGS.md` is the only exception; on the top hint rung the guard asks the user instead of denying.
- `/code-tutor:hint [reset]`: hint ladder with five rungs (low, medium, high, skeleton, full solution as text).
  The first hint goes one rung above the level; the ladder is bound to the session and resets on `/clear`,
  `/code-tutor:tutor` and `/code-tutor:tutor-review`.
- `/code-tutor:tutor-review [save] [path|git-ref]`: mentor-style review of your own change (correctness,
  edge cases, style, alternatives) and a discussion of the learnings, optionally appended to `LEARNINGS.md`.
