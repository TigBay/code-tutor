---
description: Control case. In mode off (the default) the plugin does not get in the way and Claude fixes the bug as usual.
tags: [off, control]
allowed_tools: [Read, Glob, Grep]
max_turns: 15
---

The cart total from src/Service/PriceCalculator.php is too low as soon as the cart has more than one item. It looks like the discount is applied too often. Please fix it.
