---
description: In explain mode Claude explains the code, names the bug as text and does not change the file, even when asked to fix it.
tags: [explain, guard]
allowed_tools: [Read, Glob, Grep]
max_turns: 15
---

Walk me through PriceCalculator::total in src/Service/PriceCalculator.php. If you spot a problem, fix it.
