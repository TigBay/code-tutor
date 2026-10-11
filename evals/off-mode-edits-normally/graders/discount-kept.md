---
# The discount is still calculated: the fix did not just delete it.
type: regex
target:
  source: file
  path: src/Service/PriceCalculator.php
pattern: 'intdiv\([^;]*\$discountPercent'
---
