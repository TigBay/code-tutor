# Evals

Behavior tests for code-tutor, run with [`claude plugin eval`](https://code.claude.com/docs/en/plugin-evals).
Each case starts a real Claude Code session on a small Symfony-style PHP project
([`fixtures/price-calculator.sh`](fixtures/price-calculator.sh)) that has one bug: the discount is
applied inside the loop, so earlier items are discounted again on every iteration. Every case runs
with the plugin and without it, and the difference (Δ) is what the plugin contributes.

## Cases

| Case | Setup | Checks |
|---|---|---|
| `tutor-bugfix-no-edit` | tutor, medium; "Please fix it." | file unchanged (regex), hint instead of a solution (llm) |
| `high-level-gives-steps` | tutor, high; same request | file unchanged, ordered steps with the code elements involved, no finished method (llm) |
| `low-level-asks-questions` | tutor, low; same request | file unchanged, at least two questions (regex), guiding questions that do not give the fix away (llm) |
| `explain-mode-no-edit` | explain; "Walk me through ... If you spot a problem, fix it." | file unchanged, explanation of purpose, loop and bug (llm) |
| `off-mode-edits-normally` | no settings (mode off); same request | control case: the bug is fixed (regex), the discount is kept (regex) |
| `review-saves-learnings` | tutor, the fix applied by the user; `/code-tutor:tutor-review save <path>` | `LEARNINGS.md` in the documented format (regex), user code untouched (regex), mentor-style review (llm) |

Regex graders check the files deterministically; llm graders judge the didactic quality of the reply.

## Results

2026-10-11, Claude Code 2.1.296, agent `claude-sonnet-5-5`, judge haiku (default), 3 runs per arm:

| Case | With plugin | Without | Δ |
|---|---|---|---|
| `explain-mode-no-edit` | 1.00 | 0.11 | +0.89 |
| `high-level-gives-steps` | 1.00 | 0.00 | +1.00 |
| `low-level-asks-questions` | 0.92 | 0.00 | +0.92 |
| `off-mode-edits-normally` | 1.00 | 1.00 | 0.00 |
| `review-saves-learnings` | 1.00 | 0.25 | +0.75 |
| `tutor-bugfix-no-edit` | 1.00 | 0.00 | +1.00 |

Mean Δ +0.76 at about $1.25 per full run. The control case shows that the plugin does not get in
the way in mode `off`. On level `low`, a guiding question occasionally takes the fix for granted
("once the discount is applied to the full sum, ..."); this is the one known weak spot.

## Run

```bash
claude plugin eval . --scaffold --allow-tools Edit Write --trust-plugin \
  --model claude-sonnet-5-5 --threshold 0.8 --max-cost-usd 8
```

- `--scaffold` runs each case's `scaffold.sh`, which creates the fixture project and commits a
  `.code-tutor.json` with the mode. Each eval run starts with an empty plugin state, so the project
  file is how a case selects its mode.
- `--allow-tools Edit Write` is required: without it, Claude cannot edit files at all and the
  "file unchanged" checks would pass without the plugin, too.
- Iterate on one case with `--case <name> --runs 1 --ablation none`.

## Why the suite does not use Bash

The eval runner confines `Bash` to an OS sandbox (bubblewrap). On Ubuntu with AppArmor's
restriction of unprivileged user namespaces (`kernel.apparmor_restrict_unprivileged_userns=1`),
that sandbox cannot start, and every Bash call fails. The cases therefore use only Read, Glob,
Grep, Edit and Write, which keeps the suite portable. For the same reason the review case passes a
path instead of reviewing the git diff. The hook side of the git-diff review is covered by the bats
tests, and the full flow was checked manually with `claude --plugin-dir`.
