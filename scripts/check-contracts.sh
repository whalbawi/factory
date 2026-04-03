#!/usr/bin/env bash
# Check contract consistency across Factory skill specs.
# Verifies that the pipeline's input/output chain is coherent:
# each skill's required inputs should be outputs of a prior skill.

set -euo pipefail

root="${1:-.}"
errors=0
warnings=0

# Define the v1 pipeline order.
pipeline=(ideation spec prototype setup build retro qa security deploy)

echo "Checking contract consistency across the pipeline..."
echo ""

# Check that each skill spec file exists
for skill in "${pipeline[@]}"; do
  spec_file="$root/specs/SPEC-${skill}.md"
  if [ ! -f "$spec_file" ]; then
    echo "ERROR: Missing spec file for /$skill: $spec_file"
    errors=$((errors + 1))
  fi
done

# Check that the core-skills index references all pipeline skills
index_file="$root/specs/SPEC-core-skills.md"
if [ -f "$index_file" ]; then
  for skill in "${pipeline[@]}"; do
    if ! grep -q "SPEC-${skill}.md" "$index_file"; then
      echo "WARNING: SPEC-core-skills.md does not reference SPEC-${skill}.md"
      warnings=$((warnings + 1))
    fi
  done
fi

# Check that SPEC.md references all pipeline skills
if [ -f "$root/SPEC.md" ]; then
  for skill in "${pipeline[@]}"; do
    if ! grep -q "/${skill}" "$root/SPEC.md"; then
      echo "WARNING: SPEC.md does not mention /${skill}"
      warnings=$((warnings + 1))
    fi
  done
fi

# Check that each skill spec mentions state tracking
for skill in "${pipeline[@]}"; do
  spec_file="$root/specs/SPEC-${skill}.md"
  [ -f "$spec_file" ] || continue

  if ! grep -qi "state.json\|state tracking\|State Tracking" "$spec_file"; then
    echo "ERROR: SPEC-${skill}.md does not mention state tracking"
    errors=$((errors + 1))
  fi
done

# Check that each skill spec has a Contract section
for skill in "${pipeline[@]}"; do
  spec_file="$root/specs/SPEC-${skill}.md"
  [ -f "$spec_file" ] || continue

  if ! grep -q "^## Contract" "$spec_file"; then
    echo "ERROR: SPEC-${skill}.md missing '## Contract' section"
    errors=$((errors + 1))
  fi
done

# Check that each skill spec has an Anti-Patterns section
for skill in "${pipeline[@]}"; do
  spec_file="$root/specs/SPEC-${skill}.md"
  [ -f "$spec_file" ] || continue

  if ! grep -q "Anti-Pattern" "$spec_file"; then
    echo "WARNING: SPEC-${skill}.md missing Anti-Patterns section"
    warnings=$((warnings + 1))
  fi
done

echo ""
echo "Contract consistency check: $errors error(s), $warnings warning(s)."

if [[ $errors -gt 0 ]]; then
  exit 1
fi

echo "Contract consistency check passed."
