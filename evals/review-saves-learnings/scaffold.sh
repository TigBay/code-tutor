#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=../fixtures/price-calculator.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures/price-calculator.sh"

create_project
set_mode '{"mode": "tutor", "level": "medium"}'
apply_user_fix
