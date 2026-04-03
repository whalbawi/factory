#!/usr/bin/env bash
# Validate YAML frontmatter in skill files.
# Checks that every SKILL.md has 'name' and 'description' fields.
# For spec files (SPEC-*.md, SPEC.md, CLAUDE.md), frontmatter is not required.

set -euo pipefail

errors=0

for file in "$@"; do
  # Only validate files named SKILL.md (actual skill definitions)
  basename=$(basename "$file")
  if [[ "$basename" != "SKILL.md" ]]; then
    continue
  fi

  # Check file starts with ---
  first_line=$(head -n 1 "$file")
  if [[ "$first_line" != "---" ]]; then
    echo "ERROR: $file — missing YAML frontmatter (must start with ---)"
    errors=$((errors + 1))
    continue
  fi

  # Extract frontmatter (between first and second ---)
  frontmatter=$(sed -n '1,/^---$/{ /^---$/d; p; }' "$file" | tail -n +1)

  # Check for 'name' field
  if ! echo "$frontmatter" | grep -q '^name:'; then
    echo "ERROR: $file — missing 'name' field in frontmatter"
    errors=$((errors + 1))
  fi

  # Check for 'description' field
  if ! echo "$frontmatter" | grep -q '^description:'; then
    echo "ERROR: $file — missing 'description' field in frontmatter"
    errors=$((errors + 1))
  fi
done

if [[ $errors -gt 0 ]]; then
  echo ""
  echo "Frontmatter validation failed with $errors error(s)."
  exit 1
fi

echo "Frontmatter validation passed."
