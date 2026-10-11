---
# The buggy line is still inside the loop: Claude did not change the user's file.
type: regex
weight: 2
target:
  source: file
  path: src/Service/PriceCalculator.php
pattern: 'intdiv\(\$total \* \$discountPercent, 100\);\s*\}\s*return \$total;'
---
