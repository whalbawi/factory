#!/usr/bin/env bash
# Check cross-references between Factory spec and skill files.
# Verifies that spec file references (specs/SPEC-*.md) point to real files.
# Skips references inside code blocks (``` fenced blocks).

set -euo pipefail

root="${1:-.}"
error_count=0

# Strip code blocks from a file and output only prose lines
strip_code_blocks() {
  awk '/^```/{skip=!skip; next} !skip{print}' "$1"
}

# Check that spec files referenced as specs/SPEC-*.md exist
for file in "$root"/SPEC.md "$root"/specs/*.md "$root"/CLAUDE.md; do
  [ -f "$file" ] || continue

  refs=()
  while IFS= read -r ref; do
    [ -n "$ref" ] && refs+=("$ref")
  done < <(strip_code_blocks "$file" | grep -oE 'specs/SPEC-[a-z-]+\.md' | sort -u)

  for ref in "${refs[@]}"; do
    if [ ! -f "$root/$ref" ]; then
      echo "ERROR: $file references '$ref' but it does not exist"
      error_count=$((error_count + 1))
    fi
  done
done

# Check that SPEC.md and CLAUDE.md exist (referenced by most skills)
for required in SPEC.md CLAUDE.md; do
  if [ ! -f "$root/$required" ]; then
    echo "ERROR: Required file '$required' does not exist"
    error_count=$((error_count + 1))
  fi
done

# Check that all SPEC-*.md files in specs/ are referenced somewhere
# (only checks prose, not code blocks)
for spec_file in "$root"/specs/SPEC-*.md; do
  [ -f "$spec_file" ] || continue
  base=$(basename "$spec_file")
  ref="specs/$base"

  found=false
  for search_file in "$root"/SPEC.md "$root"/CLAUDE.md "$root"/specs/*.md; do
    [ -f "$search_file" ] || continue
    [[ "$search_file" -ef "$spec_file" ]] && continue
    if strip_code_blocks "$search_file" | grep -c "$ref" > /dev/null 2>&1; then
      found=true
      break
    fi
  done

  if [ "$found" = false ]; then
    echo "WARNING: $ref is not referenced by any other file"
  fi
done

if [[ $error_count -gt 0 ]]; then
  echo ""
  echo "Cross-reference check failed with $error_count error(s)."
  exit 1
fi

echo "Cross-reference check passed."
