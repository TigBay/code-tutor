# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-10-11

First release.

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
- Optional output style `code-tutor:tutor` (`/output-style code-tutor:tutor`): structured hints
  (where, hint, your turn), structured explanations, and short "why" notes after edits in mode `off`.
- Eval suite for `claude plugin eval` with six cases on a PHP fixture and a no-plugin baseline
  (mean Δ +0.76, see `evals/README.md`).
- Hooks run with bash 3.2 (the default on macOS) and with BSD or busybox tools.
- CI on every push: manifest validation, shellcheck, and the bats suite on Ubuntu, macOS (bash 3.2)
  and Alpine (busybox). The eval suite runs on demand.

[Unreleased]: https://github.com/TigBay/code-tutor/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/TigBay/code-tutor/releases/tag/v0.1.0
