---
name: tutor
description: Switch the code-tutor mode and hint level for the current project (off, tutor, explain, low, medium, high, reset, status).
argument-hint: "[off|tutor|explain|low|medium|high|reset|status]"
disable-model-invocation: true
---

The code-tutor hook has already processed `/code-tutor:tutor $ARGUMENTS`. Its result is the "code-tutor:" note added to this message; nothing else needs to be changed.

Confirm the result to the user in two to four short lines, in the language the user writes in:

- the current mode and level, and where each value comes from
- in one sentence, what this means for the next requests (for example which kind of hints they will get on this level)
- in mode tutor or explain: that `/code-tutor:hint` gives the next, more concrete hint, `/code-tutor:tutor-review` reviews their solution, and `/code-tutor:tutor off` returns to normal behavior

Do not use any tools for this command.
