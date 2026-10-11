---
# The discount line is no longer inside the loop.
type: regex
weight: 2
target:
  source: file
  path: src/Service/PriceCalculator.php
pattern: 'intdiv\(\$total \* \$discountPercent, 100\);\s*\}\s*return \$total;'
match: not_contains
---
