#!/usr/bin/env bash
# Validate .factory/state.json against .factory/state-schema.json.
# Uses jsonschema via uv. Exit 0 if valid or no state file; exit 1 on failure.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE_FILE="$REPO_ROOT/.factory/state.json"
SCHEMA_FILE="$REPO_ROOT/.factory/state-schema.json"

if [ ! -f "$STATE_FILE" ]; then
  echo "No state file at $STATE_FILE -- nothing to validate."
  exit 0
fi

if [ ! -f "$SCHEMA_FILE" ]; then
  echo "ERROR: Schema file not found at $SCHEMA_FILE" >&2
  exit 1
fi

echo "Validating $STATE_FILE against $SCHEMA_FILE ..."

uv run --with 'jsonschema[format]' python3 -c "
import json, sys
from jsonschema import validate, ValidationError, Draft202012Validator

with open('$SCHEMA_FILE') as f:
    schema = json.load(f)
with open('$STATE_FILE') as f:
    instance = json.load(f)

validator = Draft202012Validator(schema, format_checker=Draft202012Validator.FORMAT_CHECKER)
errors = sorted(validator.iter_errors(instance), key=lambda e: list(e.absolute_path))

if errors:
    print(f'FAIL: {len(errors)} validation error(s) found.\n', file=sys.stderr)
    for i, err in enumerate(errors, 1):
        path = '.'.join(str(p) for p in err.absolute_path) or '(root)'
        print(f'  {i}. [{path}] {err.message}', file=sys.stderr)
    sys.exit(1)
else:
    print('PASS: state.json is valid.')
"
