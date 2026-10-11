---
description: /code-tutor:tutor-review save with a path reviews the user's fixed file, leaves it untouched and appends the learnings to LEARNINGS.md (the only file the guard allows in tutor mode). A path target keeps the case free of Bash, which the eval sandbox needs for git.
tags: [review, guard]
allowed_tools: [Read, Glob, Grep]
max_turns: 20
---

/code-tutor:tutor-review save src/Service/PriceCalculator.php
