---
name: hint
description: Give the next, more concrete hint for the task the user is working on (code-tutor hint ladder). "/hint reset" returns to the level's rung.
argument-hint: "[reset]"
disable-model-invocation: true
---

The code-tutor hook has already moved the hint ladder. The "code-tutor:" note added to this message names the new rung and exactly what an answer on it contains.

If the note says the ladder was reset, confirm that in one line and stop.

Otherwise give the next hint for the task the user is currently working on, in the language the user writes in:

- Look at the relevant code first, so the hint points to the right place.
- Make the hint exactly as concrete as the rung describes, no more. Build on the previous hints in this conversation instead of repeating them.
- End with one short question or the next step for the user.
- On the top rung, show the solution in the chat only. Do not write it into files unless the user explicitly asks for that.

If it is unclear which task the hint is for, ask in one sentence instead of guessing.
