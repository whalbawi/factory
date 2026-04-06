#!/usr/bin/env bash
# Lint all Factory skill files for size, required sections, and placeholder text.
# Exits with code 1 if any check fails, 0 if all pass.

set -euo pipefail

errors=0

echo "Checking skill files for size, structure, and placeholders..."
echo ""

# Find all SKILL.md files, excluding skills/references/
skill_files=()
while IFS= read -r -d '' f; do
  skill_files+=("$f")
done < <(find skills -name "SKILL.md" -not -path "skills/references/*" -print0 2>/dev/null)

if [[ ${#skill_files[@]} -eq 0 ]]; then
  echo "WARNING: No skill files found under skills/*/SKILL.md"
  exit 0
fi

for file in "${skill_files[@]}"; do
  skill_name="$(dirname "$file" | sed 's|skills/||')"

  # --- Check line count ---
  line_count=$(wc -l < "$file" | tr -d ' ')
  if [[ $line_count -gt 500 ]]; then
    echo "ERROR: $file exceeds 500 lines ($line_count lines)"
    errors=$((errors + 1))
  fi

  # --- Check required sections ---
  head_lines=$(head -n 10 "$file")

  if ! echo "$head_lines" | grep -q "name:"; then
    echo "ERROR: $file missing 'name:' in YAML frontmatter (first 10 lines)"
    errors=$((errors + 1))
  fi

  if ! echo "$head_lines" | grep -q "description:"; then
    echo "ERROR: $file missing 'description:' in YAML frontmatter (first 10 lines)"
    errors=$((errors + 1))
  fi

  if ! grep -q "Skill Parameters\|Read and execute ALL" "$file"; then
    echo "ERROR: $file missing 'Skill Parameters' or 'Read and execute ALL' section"
    errors=$((errors + 1))
  fi

  if ! grep -q "^#\+.*Settings" "$file"; then
    echo "ERROR: $file missing 'Settings' heading"
    errors=$((errors + 1))
  fi

  if ! grep -q "^#\+.*Anti-Patterns" "$file"; then
    echo "ERROR: $file missing 'Anti-Patterns' heading"
    errors=$((errors + 1))
  fi

  # --- Check for placeholder text ---
  if grep -iq "\[insert here\]\|\[TODO\]\|\[placeholder\]" "$file"; then
    echo "ERROR: $file contains placeholder text"
    grep -in "\[insert here\]\|\[TODO\]\|\[placeholder\]" "$file" | while read -r match; do
      echo "  $match"
    done
    errors=$((errors + 1))
  fi
done

echo ""
echo "Skill lint check: $errors error(s)."

if [[ $errors -gt 0 ]]; then
  exit 1
fi

echo "Skill lint check passed."
