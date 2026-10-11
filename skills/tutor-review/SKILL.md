---
name: tutor-review
description: Review the code the user wrote for the current task (correctness, edge cases, style, alternatives) and discuss the learnings; "save" appends them to LEARNINGS.md.
argument-hint: "[save] [path|git-ref]"
disable-model-invocation: true
allowed-tools: Read Grep Glob Bash(git diff *) Bash(git status *) Bash(git log *) Bash(git show *)
---

The code-tutor hook has prepared this review. The "code-tutor:" note added to this message names the review target, whether the learnings are saved, and today's date.

Review the user's own work as a mentor, in the language the user writes in.

## 1. Collect the changes

Read the review target from the note: run `git status` and `git diff` for changes, or read the named files. If there is nothing to review, ask the user which files or commit to look at and stop.

## 2. Review

Start with one or two things that are done well. Then go through these points, ordered by importance, each with a `file:line` reference:

- **Correctness**: does the code solve the task, and where are bugs?
- **Edge cases**: inputs and states that are not handled. Name concrete examples, such as an empty list, null, 0, a negative value, a duplicate or a concurrent call.
- **Style**: readability, naming, and the conventions of the project and framework (for PHP, for example, PSR-12 and Symfony best practices where they apply).
- **Alternatives**: one or two other approaches with their trade-offs.

Do not rewrite the user's code. Show a short snippet only when a point cannot be made without it, and leave fixes to the user. Do not change any file except LEARNINGS.md.

## 3. Learnings

Name two to four learnings that carry over to other tasks: the concept behind them, not the details of this task. Then ask the user what they take away, so this becomes a conversation, not a report.

## 4. LEARNINGS.md

If the note says "Save learnings to LEARNINGS.md: yes", append the learnings to `LEARNINGS.md` in the project root at the end of this answer. If it says "no", ask at the end whether to save them.

When saving, append to the end of the file and never change existing entries. Create the file with a `# Learnings` heading if it does not exist. Use this format, with today's date from the note:

```markdown
## YYYY-MM-DD: <short title of the task>

- <learning>
- <learning>
```
