# code-tutor

A Claude Code plugin that helps you **learn while working with Claude** instead of letting it write everything for you.

> Work in progress. See [CHANGELOG.md](CHANGELOG.md).

## Problem

## Solution

## Installation

```text
/plugin marketplace add TigBay/code-tutor
/plugin install code-tutor@code-tutor
```

## Modes and levels

## Architecture

## Limitations

The write guard is a learning aid, not a security boundary. It is designed to
stop Claude from *accidentally* taking over your task, and it is honest about
what it cannot see:

- **Edit, Write, NotebookEdit** inside the project are always blocked in
  `tutor` and `explain` mode (except `LEARNINGS.md` in the project root). Files
  outside the project, such as plan files, memory or `/tmp`, are not affected.
- **Bash and PowerShell** commands are checked with a best-effort parser. It
  ignores quoted text and heredoc bodies and detects output redirection
  (`>`, `>>`, `&>`, `>|`), `tee`, `cp`, `mv`, `rm`, `touch`, `ln`, `truncate`,
  `dd of=`, `patch`, `sed -i`, `perl -i`, `find -delete` / `-exec`, file-changing
  `git` commands (`restore`, `checkout -- <file>`, `reset --hard`, `clean`,
  `apply`, `stash`, ...), Symfony `make:*` commands and PowerShell file cmdlets.
- **Not detected:** code passed to an interpreter (`python -c`, `php -r`,
  `node -e`, `bash -c '...'`), scripts that write files, and build tools or
  package managers that generate or change files (`composer require`,
  `npm install`, code generators other than Symfony's maker).
- **Fail-open:** if a hook crashes, times out or `jq` is missing, Claude Code
  continues without the guard (`jq` missing is reported as a visible message).
- **Project identity** is the directory Claude Code was started in. Starting in
  a subdirectory or through a symlinked path gives that path its own setting.

## Roadmap

## License

[MIT](LICENSE)
