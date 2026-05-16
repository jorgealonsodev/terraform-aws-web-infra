#!/usr/bin/env bash
# gen-docs.sh — Regenerate terraform-docs for all modules.
# Usage: ./scripts/gen-docs.sh
# Requires Docker with the terraform-docs image available.
set -euo pipefail

MODULES_DIR="modules"

for mod in "$MODULES_DIR"/*/; do
  if [ -f "${mod}main.tf" ]; then
    echo "Generating docs for: $mod"
    docker run --rm -v "$(pwd):/workspace" -w "/workspace/$mod" \
      quay.io/terraform-docs/terraform-docs:latest markdown table \
      --output-file README.md --output-mode inject /workspace/"$mod"
  fi
done

echo "Done. Module docs regenerated."
