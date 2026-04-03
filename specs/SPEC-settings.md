# Settings System -- Domain Spec

## Overview

The settings system lets users persist preferences across sessions without editing
SKILL.md files. Each skill declares its configurable settings in a `## Settings` section
using a YAML code block. User values are stored in `.factory/settings.json`, namespaced
by skill name. The `/factory settings` subcommand provides list, get, and set operations
with schema-based validation.

This is a cross-cutting feature, not a pipeline phase. It has no position in the
pipeline sequence and does not appear in `.factory/state.json` phase tracking. It is a
subcommand of `/factory` (like `/factory claim`) and a protocol that every skill follows
on entry.

---

## Contract

| Field               | Value                                                        |
|---------------------|--------------------------------------------------------------|
| **Required inputs** | At least one installed skill with a `## Settings` section    |
| **Optional inputs** | `.factory/settings.json` (created on first write)            |
| **Outputs**         | `.factory/settings.json` (created or updated)                |
| **Side effects**    | Skills read settings on entry and adapt behavior accordingly |

The settings system does NOT produce a report file. It modifies `.factory/settings.json`
in place. This is the only Factory artifact that is written by every skill (on first-run
discovery) and by the user (via `/factory settings set`).

---

## Settings Schema Format

Each skill MAY declare a `## Settings` section in its SKILL.md file. The section
contains a single YAML code block with a `settings` key whose value is an array of
setting declarations.

### Schema Structure

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

### Field Definitions

| Field         | Required | Type     | Notes                                         |
|---------------|----------|----------|-----------------------------------------------|
| `name`        | Yes      | string   | Lowercase, underscores allowed, no spaces.    |
|               |          |          | Must be unique within a skill's settings.     |
| `type`        | Yes      | string   | One of: `enum`, `boolean`, `number`, `string` |
| `values`      | Conditional | array | Required for `enum`. Forbidden for others.    |
| `default`     | No       | varies   | Must match declared type. Omit for first-run  |
|               |          |          | discovery (skill will prompt on first use).   |
| `min`         | No       | number   | Only valid for `number` type.                 |
| `max`         | No       | number   | Only valid for `number` type.                 |
| `description` | Yes      | string   | Shown to the user in `/factory settings` list |

### Type Rules

**enum** -- Value must be one of the strings in `values`. The `values` array must have
at least two entries (a single-value enum is a constant, not a setting).

**boolean** -- Value must be `true` or `false`. Stored as JSON boolean. When set via
the CLI, accepts `true`, `false`, `yes`, `no`, `Y`, `N` (case-insensitive), all
normalized to JSON `true` or `false`.

**number** -- Value must be a JSON number. If `min` is declared, value must be >= min.
If `max` is declared, value must be <= max. Both `min` and `max` are optional and
independent (you can declare `min` without `max` and vice versa).

**string** -- Any non-empty string. No further validation beyond non-emptiness. Use
`enum` instead when there is a finite set of valid values.

---

## Storage Format

Settings are stored in `.factory/settings.json` at the project root's `.factory/`
directory (the same directory that holds `state.json`). The file uses a flat namespace
model: top-level keys are skill names, and each key maps to an object of setting
name-value pairs.

### File Structure

```json
{
  "global": {
    "open_markdown": "Y",
    "confirm_destructive": true
  },
  "qa": {
    "coverage_target": 80,
    "mutation_testing": false,
    "open_report": "Y"
  },
  "deploy": {
    "default_environment": "staging",
    "auto_archive_receipts": true
  },
  "build": {
    "max_parallel_agents": 4,
    "ci_check_interval": 5
  },
  "security": {
    "severity_threshold": "high",
    "auto_fix": false
  }
}
```

### Storage Rules

1. The file is created on first write (first `/factory settings set` or first-run
   discovery). It does not exist in a fresh project.
2. The file is valid JSON. If it becomes malformed, back it up to
   `.factory/settings.json.bak`, create a fresh `{}` file, and inform the user.
   This matches the recovery behavior for `.factory/state.json`.
3. Only declared settings may appear under a skill's namespace. Unknown keys are
   logged as warnings and ignored (not deleted -- the user may have settings from
   a newer version of a skill).
4. The `global` namespace is reserved for cross-skill settings. No skill may use
   `global` as its skill name.
5. The file is human-editable. Users may edit it directly with a text editor. Skills
   must tolerate hand-edited values by validating on read, not just on write.
6. The file MUST NOT contain secrets, API keys, or credentials. Settings are
   committed to the repo or at minimum visible in plain text. If a user attempts to
   store a value that looks like a secret (starts with `sk-`, `ghp_`, `AKIA`, or
   matches common key patterns), warn them and refuse.

---

## Settings Protocol (How Skills Read Settings)

Every skill that declares settings follows this protocol on entry, before executing
its main logic. This protocol runs after state tracking (reading `.factory/state.json`)
and before the skill's first user-visible action.

### Step 1: Parse Schema

Read the skill's own `## Settings` section from its SKILL.md. Parse the YAML code
block to extract the settings schema. If the skill has no `## Settings` section, skip
the entire settings protocol.

### Step 2: Load Stored Values

Read `.factory/settings.json`. If the file does not exist, treat all settings as unset.
Extract the skill's namespace (e.g., `qa` for the `/qa` skill) and the `global`
namespace.

### Step 3: Validate and Resolve

For each declared setting, resolve its effective value using this precedence order:

1. **Stored value** (from `.factory/settings.json`) -- highest priority
2. **Default value** (from the schema) -- fallback
3. **First-run discovery** (prompt the user) -- when no stored value and no default

Validation runs on the stored value before it is used:

- If the stored value does not match the declared type, log a warning:
  `Setting qa.coverage_target has invalid value "abc" (expected number), using
  default 80`
- Replace the invalid value with the default. If there is no default, trigger
  first-run discovery.
- Do NOT silently write the corrected value back to the file. The user may have a
  reason for the value. Log the warning and use the default for this session only.

### Step 4: First-Run Discovery

For any setting that has no stored value and no default (or whose default is the
special string `"ask"`):

1. Present the setting to the user with its description and available options:

   ```text
   Setting: coverage_target
   Description: Minimum test coverage percentage
   Type: number (0-100)
   Value: [enter a number]
   ```

2. Validate the user's input against the schema.
3. If valid, write the value to `.factory/settings.json` under the skill's namespace.
4. If invalid, explain why and re-prompt (up to 3 attempts, then use a sensible
   fallback and warn).

First-run discovery only triggers once per setting per project. After the user
provides a value, it is persisted and never asked again unless the user deletes it
from `.factory/settings.json`.

### Step 5: Make Settings Available

After resolution, the skill uses the effective values throughout its execution. There
is no special API -- the skill simply reads the resolved values from the settings
protocol and references them in its logic.

---

## The `/factory settings` Command

The `/factory settings` command is a subcommand of the `/factory` orchestrator. It
provides three operations: list, get, and set.

### `/factory settings` (list)

Display all settings from all installed skills, grouped by skill name. For each
setting, show:

- Name (fully qualified: `skill.setting_name`)
- Current value (from `.factory/settings.json`, or "(default)" if using the schema
  default, or "(unset)" if no value and no default)
- Default value
- Description

Example output:

```text
=== Global Settings ===

  global.open_markdown        = Y         (default: ask)
    Open markdown files in browser after creation

  global.confirm_destructive  = true      (default: true)
    Ask for confirmation before destructive operations

=== /qa Settings ===

  qa.coverage_target          = 80        (default: 100)
    Minimum test coverage percentage

  qa.mutation_testing         = (default) (default: false)
    Run mutation testing when supported by the stack

  qa.open_report              = Y         (default: ask)
    Open QA report in browser after creation

=== /deploy Settings ===

  deploy.default_environment  = staging   (default: prod)
    Default target environment when none specified

  deploy.auto_archive_receipts = true     (default: true)
    Automatically archive previous DEPLOY-RECEIPT.md files

=== /build Settings ===

  build.max_parallel_agents   = 4         (default: 3)
    Maximum number of parallel specialist agents

  build.ci_check_interval     = 5         (default: 5)
    Number of merges between CI inspection runs
```

If no settings file exists and no skills declare settings, say:
`No settings declared by any installed skill.`

### `/factory settings get <key>`

Retrieve a single setting value. The key uses dot notation: `skill.setting_name`.

```text
> /factory settings get qa.coverage_target
qa.coverage_target = 80
```

If the setting is unset and has a default:

```text
> /factory settings get qa.mutation_testing
qa.mutation_testing = false (default)
```

If the key does not match any declared setting:

```text
> /factory settings get qa.nonexistent
Error: qa.nonexistent is not a declared setting. Run /factory settings to see
available settings.
```

### `/factory settings set <key> <value>`

Set a setting value. Validates the value against the skill's schema before writing.

```text
> /factory settings set qa.coverage_target 80
Set qa.coverage_target = 80

> /factory settings set qa.coverage_target abc
Error: qa.coverage_target expects a number, got "abc"

> /factory settings set qa.coverage_target 150
Error: qa.coverage_target must be between 0 and 100, got 150

> /factory settings set deploy.default_environment alpha
Set deploy.default_environment = alpha
```

The set operation:

1. Parses the key into skill name and setting name.
2. Loads the schema from the skill's SKILL.md.
3. Validates the value against the schema.
4. If valid, writes to `.factory/settings.json`.
5. If invalid, shows the error and does not write.

### `/factory settings reset <key>`

Remove a setting from `.factory/settings.json`, reverting it to its default (or to
"unset" if no default). This is the only way to re-trigger first-run discovery for a
setting.

```text
> /factory settings reset qa.coverage_target
Reset qa.coverage_target (will use default: 100)

> /factory settings reset qa.open_report
Reset qa.open_report (will prompt on next /qa run)
```

---

## Global vs Per-Skill Namespacing

### Global Settings

Global settings live under the `global` namespace in `.factory/settings.json`. They
apply across all skills. Global settings are declared in the `/factory` orchestrator's
SKILL.md (since `/factory` is the only skill that governs cross-cutting behavior).

Any skill can read global settings. Only the `/factory` skill declares them.

Example global settings:

```yaml
settings:
  - name: open_markdown
    type: enum
    values: ["Y", "N", "ask"]
    default: "ask"
    description: Open generated markdown files in the browser after creation
  - name: confirm_destructive
    type: boolean
    default: true
    description: Ask for confirmation before destructive operations like phase resets
```

### Per-Skill Settings

Per-skill settings live under the skill's name as the namespace key. Each skill
declares and owns its own settings. No skill may write to another skill's namespace.

### Namespace Resolution

When a skill reads a setting, it checks its own namespace first. If it also needs a
global setting, it reads from the `global` namespace explicitly. There is no
inheritance or fallback between namespaces -- a skill that wants `open_markdown`
behavior must explicitly read `global.open_markdown`.

### Conflict Rules

- A per-skill setting and a global setting may have the same `name` field (e.g.,
  both `global.open_markdown` and `qa.open_report` can coexist). They are fully
  independent because namespacing disambiguates them.
- If two skills somehow declare a setting with the same fully-qualified key (which
  would require two skills with the same name), the first-loaded skill wins and a
  warning is logged. This should not happen in practice because skill names are
  unique.

---

## Concrete Examples: Settings Declarations for Factory Skills

### /factory (orchestrator) -- Global Settings

```yaml
settings:
  - name: open_markdown
    type: enum
    values: ["Y", "N", "ask"]
    default: "ask"
    description: Open generated markdown files in the browser after creation
  - name: confirm_destructive
    type: boolean
    default: true
    description: Ask for confirmation before destructive operations like phase resets
```

### /qa -- Quality Control Settings

```yaml
settings:
  - name: coverage_target
    type: number
    min: 0
    max: 100
    default: 100
    description: Minimum test coverage percentage
  - name: mutation_testing
    type: boolean
    default: false
    description: Run mutation testing when supported by the stack
  - name: open_report
    type: enum
    values: ["Y", "N", "ask"]
    default: "ask"
    description: Open QA report in browser after creation
```

### /deploy -- Deployment Settings

```yaml
settings:
  - name: default_environment
    type: enum
    values: ["alpha", "staging", "prod"]
    default: "prod"
    description: Default target environment when none specified
  - name: auto_archive_receipts
    type: boolean
    default: true
    description: Automatically archive previous DEPLOY-RECEIPT.md files
```

### /build -- Construction Settings

```yaml
settings:
  - name: max_parallel_agents
    type: number
    min: 1
    max: 10
    default: 3
    description: Maximum number of parallel specialist agents
  - name: ci_check_interval
    type: number
    min: 1
    max: 20
    default: 5
    description: Number of merges between CI inspection runs
```

### /security -- Security Audit Settings

```yaml
settings:
  - name: severity_threshold
    type: enum
    values: ["critical", "high", "medium", "low"]
    default: "critical"
    description: >
      Minimum severity level that blocks deployment. Default blocks only on
      critical. Set to high to also block on high-severity findings.
  - name: auto_fix
    type: boolean
    default: false
    description: >
      Automatically apply safe fixes for dependency vulnerabilities (patch
      version bumps only)
```

---

## Settings and State Tracking

The settings system does not participate in `.factory/state.json` phase tracking.
It has no `status`, `started_at`, or `completed_at` fields.

However, `.factory/settings.json` is referenced in the state file's metadata for
auditability. When a skill reads settings on entry, it records which settings were
used in its state entry:

```json
{
  "phases": {
    "qa": {
      "status": "in_progress",
      "started_at": "2026-04-03T14:00:00Z",
      "settings_used": {
        "qa.coverage_target": 80,
        "qa.mutation_testing": false,
        "global.open_markdown": "Y"
      }
    }
  }
}
```

This `settings_used` field is informational only. It serves as an audit trail of what
configuration was active during a given run. It is written on phase start and never
updated mid-run.

---

## Validation Rules Summary

| Type    | Valid values                       | CLI normalization                           |
|---------|-----------------------------------|---------------------------------------------|
| enum    | Exact match from `values` array   | Case-sensitive, no normalization             |
| boolean | `true`, `false`                   | `yes`/`no`/`Y`/`N`/`true`/`false` -> bool   |
| number  | Any JSON number within min/max    | Parsed as float, rejected if NaN             |
| string  | Any non-empty string              | Trimmed of leading/trailing whitespace       |

### Validation Timing

- **On write** (`/factory settings set`): Validate before writing. Reject invalid
  values with a clear error message.
- **On read** (settings protocol step 3): Validate stored values. Replace invalid
  values with defaults for the current session. Log a warning. Do not modify the
  file.
- **On first-run discovery**: Validate user input immediately. Re-prompt on invalid
  input.

---

## Anti-Patterns

- **Storing secrets in settings.** Settings are plain-text JSON, potentially committed
  to the repo. Never store API keys, tokens, passwords, or credentials as settings.
  The system actively refuses values matching common secret patterns.

- **Inventing settings that should be in CLAUDE.md.** Settings are for user
  preferences that vary between people or projects. Project-level conventions (test
  commands, tech stack, code style) belong in CLAUDE.md, not in settings. If the value
  would be the same for every user of the project, it is not a setting.

- **Using string type when enum is appropriate.** If there are only 3-5 valid values,
  use `enum` for validation. `string` is for genuinely freeform values like custom
  paths or labels.

- **Declaring settings without defaults.** Every setting should have a sensible default
  unless user input is genuinely required on first use. The `"ask"` default pattern
  (first-run discovery) should be rare -- most settings should work out of the box.

- **Writing to another skill's namespace.** Each skill owns its namespace. The `/qa`
  skill must never write to `deploy.*` or `build.*`. Cross-skill coordination happens
  through global settings or through `.factory/state.json`.

- **Silently correcting invalid values in the file.** When validation fails on read,
  log a warning and use the default for the session. Do not silently rewrite the file.
  The user may have a reason for the value (e.g., testing with an older skill version).

- **Prompting for every setting on first run.** First-run discovery only triggers for
  settings that lack both a stored value and a default. Most settings have defaults and
  require no user interaction.

- **Making the settings protocol blocking.** The settings protocol should be fast. If
  no first-run discovery is needed (all settings have stored values or defaults), the
  protocol completes silently with zero user interaction.

---

## Architect Review

### Decisions Made

1. **Flat namespace, not nested.** Settings use `skill.setting_name` dot notation with
   a flat JSON structure. Nested namespaces (e.g., `qa.coverage.target`) were
   considered and rejected -- they add complexity without meaningful benefit for the
   expected number of settings per skill (2-5).

2. **Schema in SKILL.md, not in a separate file.** Settings schemas are declared inline
   in each skill's SKILL.md rather than in a separate `settings.schema.json`. This
   keeps skills self-contained (a core quality standard) and avoids schema drift.

3. **Validate on read, not just on write.** Since users can hand-edit
   `.factory/settings.json`, validation must happen on every read. Invalid values fall
   back to defaults rather than crashing the skill.

4. **No settings migration system.** When a skill renames or removes a setting, the
   old value remains in `.factory/settings.json` as an unknown key (logged as a
   warning, not deleted). A formal migration system is deferred -- the expected
   setting churn rate does not justify the complexity.

5. **`settings_used` in state is informational only.** Recording which settings were
   active during a run aids debugging ("why did QA use 80% coverage last time?") but
   is not used for gating or validation.

6. **No environment-specific settings.** Settings do not vary by deployment environment
   (alpha/staging/prod). Environment-specific configuration belongs in deployment
   config (fly.toml, environment variables), not in Factory settings. If this becomes
   a need, it can be added as a `per_environment` flag on individual settings.

7. **Secret detection is best-effort.** The system checks for common secret patterns
   (AWS keys, GitHub tokens, etc.) but cannot catch all secrets. The anti-pattern
   documentation makes the policy clear; enforcement is advisory, not exhaustive.

### Open Questions

1. **Should `/factory settings` require the orchestrator skill to be installed?** The
   current design routes `settings` through the `/factory` subcommand, which means the
   orchestrator must be present. An alternative is a standalone `/settings` skill, but
   this breaks the convention that all meta-operations go through `/factory`.
   **Recommendation**: Keep it as a `/factory` subcommand. The orchestrator is always
   installed in a Factory project.

2. **Should settings be project-scoped or user-scoped?** The current design is
   project-scoped (`.factory/settings.json` lives in the project directory). A
   user-scoped settings file (`~/.factory/settings.json`) would let preferences follow
   the user across projects. **Recommendation**: Start with project-scoped only. Add
   user-scoped as a layered override in a future version if users request it. Precedence
   would be: project settings > user settings > schema defaults.

3. **Should settings support `null` to explicitly mean "use default"?** The current
   design uses `reset` to remove a key, reverting to the default. An alternative is to
   allow `null` as a stored value meaning "explicitly use default."
   **Recommendation**: No. `reset` (key removal) is simpler and less ambiguous.
   A `null` in the file would be confusing when the user hand-edits.

4. **Should the `## Settings` section be required in all skills?** The current design
   makes it optional -- skills without settings simply skip the settings protocol.
   **Recommendation**: Keep it optional. Forcing every skill to declare an empty
   settings section adds boilerplate without value.
