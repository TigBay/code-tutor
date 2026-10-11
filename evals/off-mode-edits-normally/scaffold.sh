#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=../fixtures/price-calculator.sh
source "$(dirname "${BASH_SOURCE[0]}")/../fixtures/price-calculator.sh"

# no .code-tutor.json: the plugin runs with its defaults (mode off)
create_project
