# Settings System -- Domain Spec

## Overview

The settings system lets users persist preferences across sessions without editing
SKILL.md files. Each skill declares its configurable settings in a `## Settings` section
using a YAML code block. User values are stored in `.factory/settings.json`, namespaced
by skill name. The `/genesis settings` subcommand provides list, get, set, and reset
operations with schema-based validation.

This is a cross-cutting feature, not a pipeline phase. It has no position in the
pipeline sequence and does not appear in `.factory/state.json` phase tracking.

## Contract

| Field               | Value                                                        |
|---------------------|--------------------------------------------------------------|
| **Required inputs** | At least one installed skill with a `## Settings` section    |
| **Optional inputs** | `.factory/settings.json` (created on first write)            |
| **Outputs**         | `.factory/settings.json` (created or updated)                |
| **Side effects**    | Skills read settings on entry and adapt behavior accordingly |

The settings system does NOT produce a report file. It modifies `.factory/settings.json`
in place.

## Settings Schema Format

Each skill MAY declare a `## Settings` section in its SKILL.md. The section contains a
YAML code block with a `settings` key whose value is an array of setting declarations.

```yaml
settings:
  - name: setting_name
    type: enum | boolean | number | string
    values: ["a", "b", "c"]       # required for enum, forbidden for other types
    default: "a"                   # optional -- omit for "ask on first run"
    min: 0                         # optional -- number type only
    max: 100                       # optional -- number type only
    description: Human-readable explanation of what this setting controls
```

### Type Rules

- **enum** -- Value must be one of `values`. Array must have at least two entries.
- **boolean** -- `true` or `false`. CLI accepts `yes`/`no`/`Y`/`N` (normalized).
- **number** -- JSON number. Optional `min`/`max` bounds.
- **string** -- Any non-empty string. Use `enum` when there is a finite set of values.

## Storage Format

Settings are stored in `.factory/settings.json` using flat namespace model: top-level
keys are skill names, each mapping to an object of setting name-value pairs.

### Storage Rules

1. Created on first write. Does not exist in a fresh project.
2. Must be valid JSON. If malformed, back up to `.factory/settings.json.bak`, create
   fresh `{}`, and inform the user.
3. Only declared settings may appear under a skill's namespace. Unknown keys are logged
   as warnings (not deleted).
4. The `global` namespace is reserved for cross-skill settings declared by `/genesis`.
5. Human-editable. Skills validate on read, not just on write.
6. MUST NOT contain secrets. Refuses values matching common secret patterns (`sk-`,
   `ghp_`, `AKIA`).

## Settings Protocol (How Skills Read Settings)

On skill entry (after state tracking, before main logic):

1. **Parse schema** from the skill's `## Settings` YAML.
2. **Load stored values** from `.factory/settings.json`.
3. **Resolve** each setting: stored value > schema default > first-run prompt.
   Validate stored values; replace invalid ones with defaults for the session (log
   warning, do not modify file).
4. **First-run discovery** for settings with no stored value and no default: present
   to user, validate, persist on confirmation.
5. **Use resolved values** throughout skill execution.

## The `/genesis settings` Command

Four operations:

- **`/genesis settings`** (list): All settings grouped by skill with current value,
  default, and description.
- **`/genesis settings get <key>`**: Single setting value via dot notation
  (`skill.setting_name`).
- **`/genesis settings set <key> <value>`**: Validate against schema, write if valid.
- **`/genesis settings reset <key>`**: Remove stored value, revert to default.

## Settings Inventory

The authoritative list of all settings (6 global + 17 per-skill) is maintained in
[SETTINGS-INVENTORY.md](SETTINGS-INVENTORY.md). That file contains the complete YAML
declarations for every skill and the rejected-settings table with rationale.

### Summary

- **Global** (declared by `/genesis`, readable by all): `onboarding_shown`,
  `open_report`, `auto_commit_outputs`, `confirm_phase_transition`,
  `parallel_domain_agents`, `state_file_path`
- **/genesis**: `auto_detect_artifacts`, `preserve_stale_outputs`,
  `update_project_claude_md`
- **/ideation**: `idea_count`, `max_selected_ideas`
- **/spec**: `discovery_track`, `peer_review_enabled`
- **/prototype**: `prototype_count`, `auto_run_prototypes`
- **/setup**: No settings (project-level decisions belong in SPEC.md/CLAUDE.md)
- **/build**: `max_parallel_agents`, `ci_inspection_interval`, `progress_tracking`
- **/retro**: `retro_schedule`, `retro_merge_interval`
- **/qa**: `write_missing_tests`, `edge_case_hunting`
- **/security**: `history_scan_depth`, `threat_model_depth`
- **/deploy**: `auto_archive_receipts`

## Namespacing

- **Global settings** live under `global` in `.factory/settings.json`. Declared by
  `/genesis`, readable by all skills.
- **Per-skill settings** live under the skill's name. Each skill owns its namespace
  and must not write to another skill's namespace.
- No inheritance between namespaces. A skill that wants `open_report` behavior must
  explicitly read `global.open_report`.

## Validation Rules

| Type    | Valid values                       | CLI normalization                           |
|---------|-----------------------------------|---------------------------------------------|
| enum    | Exact match from `values` array   | Case-sensitive, no normalization             |
| boolean | `true`, `false`                   | `yes`/`no`/`Y`/`N`/`true`/`false` -> bool   |
| number  | Any JSON number within min/max    | Parsed as float, rejected if NaN             |
| string  | Any non-empty string              | Trimmed of leading/trailing whitespace       |

Validation timing: on write (reject invalid), on read (fall back to default for
session), on first-run discovery (re-prompt on invalid input).

## Anti-Patterns

- **Storing secrets in settings.** Settings are plain-text JSON. Use deployment
  platform secret management instead.
- **Inventing settings that should be in CLAUDE.md.** Settings control Factory
  behavior, not the target project. Coverage targets, test commands, and code style
  belong in CLAUDE.md or SPEC.md.
- **Using string type when enum is appropriate.** Use `enum` for 3-5 valid values.
- **Declaring settings without defaults.** Most settings should work out of the box.
- **Writing to another skill's namespace.** Cross-skill coordination uses global
  settings or `.factory/state.json`.
- **Silently correcting invalid values.** Log a warning, use the default for the
  session. Do not rewrite the file.
- **Prompting for every setting on first run.** Only trigger for settings lacking
  both a stored value and a default.
