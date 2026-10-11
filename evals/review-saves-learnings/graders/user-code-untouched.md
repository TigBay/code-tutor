---
# The user's fix is still in place exactly as they wrote it.
type: regex
target:
  source: file
  path: src/Service/PriceCalculator.php
pattern: '\}\s*return \$total - intdiv\(\$total \* \$discountPercent, 100\);'
---
