# shellcheck shell=bash
#
# Shared fixture for the eval cases: a small Symfony-style PHP project with one
# bug. The discount is applied inside the loop, so earlier items are discounted
# again on every iteration (two items of 1000 cents at 10% give 1710, not 1800).
#
# Sourced by each case's scaffold.sh, which runs in the empty eval workspace.

# create_project: write the project files and commit them.
create_project() {
  mkdir -p src/Service

  cat >composer.json <<'EOF'
{
    "name": "acme/shop",
    "type": "project",
    "require": {
        "php": ">=8.2"
    },
    "autoload": {
        "psr-4": {
            "App\\": "src/"
        }
    }
}
EOF

  cat >src/Service/PriceCalculator.php <<'EOF'
<?php

declare(strict_types=1);

namespace App\Service;

final class PriceCalculator
{
    /**
     * Total of a cart in cents, after a percentage discount on the whole cart.
     *
     * @param list<array{price: int, quantity: int}> $items prices in cents
     */
    public function total(array $items, int $discountPercent): int
    {
        $total = 0;
        foreach ($items as $item) {
            $total += $item['price'] * $item['quantity'];
            $total -= intdiv($total * $discountPercent, 100);
        }

        return $total;
    }
}
EOF

  git init -q
  git add -A
  git -c user.name="Eval User" -c user.email=eval@example.com commit -qm "Add price calculator"
}

# apply_user_fix: the change a user would make after the hints (left uncommitted).
apply_user_fix() {
  cat >src/Service/PriceCalculator.php <<'EOF'
<?php

declare(strict_types=1);

namespace App\Service;

final class PriceCalculator
{
    /**
     * Total of a cart in cents, after a percentage discount on the whole cart.
     *
     * @param list<array{price: int, quantity: int}> $items prices in cents
     */
    public function total(array $items, int $discountPercent): int
    {
        $total = 0;
        foreach ($items as $item) {
            $total += $item['price'] * $item['quantity'];
        }

        return $total - intdiv($total * $discountPercent, 100);
    }
}
EOF
}

# set_mode <json>: commit a code-tutor project file, like a training repository would.
set_mode() {
  printf '%s\n' "$1" >.code-tutor.json
  git add .code-tutor.json
  git -c user.name="Eval User" -c user.email=eval@example.com commit -qm "Set code-tutor mode"
}
