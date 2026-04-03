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
    "open_report": true,
    "auto_commit_outputs": false,
    "confirm_phase_transition": true,
    "parallel_domain_agents": 3,
    "state_file_path": ".factory/state.json"
  },
  "ideation": {
    "idea_count": 7,
    "max_selected_ideas": 3
  },
  "build": {
    "max_parallel_agents": 4,
    "ci_inspection_interval": 5,
    "progress_tracking": "full"
  },
  "qa": {
    "write_missing_tests": true,
    "edge_case_hunting": "full"
  },
  "deploy": {
    "auto_archive_receipts": true
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
  `Setting build.max_parallel_agents has invalid value "abc" (expected number),
  using default 4`
- Replace the invalid value with the default. If there is no default, trigger
  first-run discovery.
- Do NOT silently write the corrected value back to the file. The user may have a
  reason for the value. Log the warning and use the default for this session only.

### Step 4: First-Run Discovery

For any setting that has no stored value and no default (or whose default is the
special string `"ask"`):

1. Present the setting to the user with its description and available options:

   ```text
   Setting: discovery_track
   Description: Controls discovery depth in /spec
   Type: enum (auto, full, focused, fast)
   Value: [choose one]
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

  global.open_report              = true      (default: false)
    Open generated report files in the default editor after creation

  global.auto_commit_outputs      = (default) (default: false)
    Automatically git-commit skill output files after completion

  global.confirm_phase_transition = true      (default: true)
    Require explicit user confirmation before advancing phases

  global.parallel_domain_agents   = 3         (default: 3)
    Maximum concurrent domain-scoped sub-agents

  global.state_file_path          = (default) (default: ".factory/state.json")
    Path to pipeline state file relative to project root

=== /ideation Settings ===

  ideation.idea_count             = 7         (default: 7)
    Target number of feature ideas to generate

  ideation.max_selected_ideas     = (default) (default: 3)
    Maximum ideas the user can select for deep dive

=== /build Settings ===

  build.max_parallel_agents       = 4         (default: 4)
    Maximum number of parallel specialist agents

  build.ci_inspection_interval    = 5         (default: 5)
    Number of PRs merged between CI pipeline inspections

  build.progress_tracking         = (default) (default: "full")
    Level of progress file tracking (full or rollup_only)

=== /qa Settings ===

  qa.write_missing_tests          = true      (default: true)
    Automatically write tests for uncovered acceptance criteria

  qa.edge_case_hunting            = (default) (default: "full")
    Depth of edge case hunting (full, light, skip)

=== /deploy Settings ===

  deploy.auto_archive_receipts    = true      (default: true)
    Automatically archive previous DEPLOY-RECEIPT.md files
```

If no settings file exists and no skills declare settings, say:
`No settings declared by any installed skill.`

### `/factory settings get <key>`

Retrieve a single setting value. The key uses dot notation: `skill.setting_name`.

```text
> /factory settings get build.max_parallel_agents
build.max_parallel_agents = 4
```

If the setting is unset and has a default:

```text
> /factory settings get qa.edge_case_hunting
qa.edge_case_hunting = full (default)
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
> /factory settings set build.max_parallel_agents 6
Set build.max_parallel_agents = 6

> /factory settings set build.max_parallel_agents abc
Error: build.max_parallel_agents expects a number, got "abc"

> /factory settings set build.max_parallel_agents 12
Error: build.max_parallel_agents must be between 1 and 8, got 12

> /factory settings set qa.edge_case_hunting light
Set qa.edge_case_hunting = light
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
> /factory settings reset build.max_parallel_agents
Reset build.max_parallel_agents (will use default: 4)

> /factory settings reset global.open_report
Reset global.open_report (will use default: false)
```

---

## Global vs Per-Skill Namespacing

### Global Settings

Global settings live under the `global` namespace in `.factory/settings.json`. They
apply across all skills. Global settings are declared in the `/factory` orchestrator's
SKILL.md (since `/factory` is the only skill that governs cross-cutting behavior).

Any skill can read global settings. Only the `/factory` skill declares them.

The five global settings:

```yaml
settings:
  - name: open_report
    type: boolean
    default: false
    description: >
      Open generated report files (QA-REPORT.md, SECURITY.md, RETRO-{date}.md,
      DEPLOY-RECEIPT.md) in the default editor or browser after creation
  - name: auto_commit_outputs
    type: boolean
    default: false
    description: >
      Automatically git-commit skill output files (reports, receipts, decision
      docs) after a skill completes successfully
  - name: confirm_phase_transition
    type: boolean
    default: true
    description: >
      Require explicit user confirmation before advancing to the next pipeline
      phase. When false, the orchestrator auto-advances after verifying outputs
  - name: parallel_domain_agents
    type: number
    default: 3
    min: 1
    max: 8
    description: >
      Maximum number of domain-scoped sub-agents to run concurrently during
      skills that support per-domain parallelism
  - name: state_file_path
    type: string
    default: ".factory/state.json"
    description: >
      Path to the pipeline state file relative to the project root. All skills
      read and write this file for state tracking
```

### Per-Skill Settings

Per-skill settings live under the skill's name as the namespace key. Each skill
declares and owns its own settings. No skill may write to another skill's namespace.

### Namespace Resolution

When a skill reads a setting, it checks its own namespace first. If it also needs a
global setting, it reads from the `global` namespace explicitly. There is no
inheritance or fallback between namespaces -- a skill that wants `open_report`
behavior must explicitly read `global.open_report`.

### Conflict Rules

- A per-skill setting and a global setting may have the same `name` field. They
  are fully independent because namespacing disambiguates them.
- If two skills somehow declare a setting with the same fully-qualified key (which
  would require two skills with the same name), the first-loaded skill wins and a
  warning is logged. This should not happen in practice because skill names are
  unique.

---

## Concrete Examples: Settings Declarations for Factory Skills

These are the actual settings from the reviewed inventory. 5 global + 17 per-skill.

### /factory (orchestrator) -- Global + Per-Skill Settings

Global settings (declared by `/factory`, readable by all skills):

```yaml
settings:
  - name: open_report
    type: boolean
    default: false
    description: >
      Open generated report files (QA-REPORT.md, SECURITY.md, RETRO-{date}.md,
      DEPLOY-RECEIPT.md) in the default editor or browser after creation
  - name: auto_commit_outputs
    type: boolean
    default: false
    description: >
      Automatically git-commit skill output files (reports, receipts, decision
      docs) after a skill completes successfully
  - name: confirm_phase_transition
    type: boolean
    default: true
    description: >
      Require explicit user confirmation before advancing to the next pipeline
      phase. When false, the orchestrator auto-advances after verifying outputs
  - name: parallel_domain_agents
    type: number
    default: 3
    min: 1
    max: 8
    description: >
      Maximum number of domain-scoped sub-agents to run concurrently during
      skills that support per-domain parallelism
  - name: state_file_path
    type: string
    default: ".factory/state.json"
    description: >
      Path to the pipeline state file relative to the project root. All skills
      read and write this file for state tracking
```

Per-skill settings for the orchestrator itself:

```yaml
settings:
  - name: auto_detect_artifacts
    type: boolean
    default: true
    description: >
      On first invocation without a state file, scan for existing artifacts
      (SPEC.md, package.json, source code) to infer completed phases and
      suggest a starting point. When false, always start from ideation.
  - name: preserve_stale_outputs
    type: boolean
    default: true
    description: >
      When navigating backward in the pipeline, preserve output files from
      reset phases on disk (marked stale). When false, delete output files
      from reset phases.
  - name: claim_write_claude_md
    type: enum
    values: ["prompt", "auto", "skip"]
    default: "prompt"
    description: >
      Controls CLAUDE.md behavior during /factory claim. "prompt" asks the
      user before writing; "auto" writes without confirmation; "skip" never
      writes CLAUDE.md during claim.
```

### /ideation -- Brainstorming Settings

```yaml
settings:
  - name: idea_count
    type: number
    default: 7
    min: 3
    description: >
      Target number of feature ideas to generate in Step 3 (idea generation).
      The skill generates between idea_count-2 and idea_count+1 ideas.
  - name: max_selected_ideas
    type: number
    default: 3
    min: 1
    description: >
      Maximum number of ideas the user can select for deep dive in Step 4.
      Caps scope to keep the ideation session focused.
```

### /spec -- Discovery Settings

```yaml
settings:
  - name: discovery_track
    type: enum
    values: ["auto", "full", "focused", "fast"]
    default: "auto"
    description: >
      Controls discovery depth. "auto" lets the skill calibrate based on the
      user's first message. "full", "focused", and "fast" force a specific
      track regardless of input signal.
  - name: peer_review_enabled
    type: boolean
    default: true
    description: >
      Enable the peer review pass (Phase 2d) where specialist agents read
      and critique each other's specs. Disabling saves time but reduces
      cross-domain consistency.
```

### /prototype -- Prototyping Settings

```yaml
settings:
  - name: prototype_count
    type: number
    default: 3
    min: 2
    max: 4
    description: >
      Target number of alternative prototypes to generate. Must be at least 2
      unless the spec genuinely admits only one approach.
  - name: auto_run_prototypes
    type: boolean
    default: true
    description: >
      Automatically execute each prototype to verify it runs before presenting
      to the user. When false, prototypes are built but not executed.
```

### /setup

No Factory-usage settings. Deployment platform, environment provisioning, and telemetry
are project-level decisions that belong in SPEC.md and CLAUDE.md.

### /build -- Construction Settings

```yaml
settings:
  - name: max_parallel_agents
    type: number
    default: 4
    min: 1
    max: 8
    description: >
      Maximum number of specialist agents (BE, FE, OPS, etc.) the Architect
      may run concurrently. Higher values speed up builds but increase
      resource usage.
  - name: ci_inspection_interval
    type: number
    default: 5
    min: 0
    description: >
      Number of PRs merged to main between CI pipeline inspections. After
      this many merges, the OPS agent inspects for false positives and false
      negatives. Set to 0 to disable periodic inspections.
  - name: progress_tracking
    type: enum
    values: ["full", "rollup_only"]
    default: "full"
    description: >
      "full" requires both per-agent PROGRESS-{PREFIX}.md files and the
      rolled-up PROGRESS.md. "rollup_only" requires only the Architect's
      PROGRESS.md, reducing overhead for small projects.
```

### /retro -- Retrospective Settings

```yaml
settings:
  - name: retro_schedule
    type: enum
    values: ["after_build", "every_n_merges", "on_demand"]
    default: "after_build"
    description: >
      When retros are triggered in the pipeline. "after_build" runs once
      after /build completes (mandatory). "every_n_merges" also triggers
      mid-build retros at the interval set by retro_merge_interval.
      "on_demand" makes retro purely user-initiated.
  - name: retro_merge_interval
    type: number
    default: 10
    min: 0
    description: >
      Number of PRs merged to main between mid-build retros. Only applies
      when retro_schedule is "every_n_merges". Set to 0 to disable.
```

### /qa -- Quality Control Settings

```yaml
settings:
  - name: write_missing_tests
    type: boolean
    default: true
    description: >
      When QA finds acceptance criteria without corresponding tests (Step 3),
      automatically write the missing tests. When false, QA only reports
      the gaps without writing tests.
  - name: edge_case_hunting
    type: enum
    values: ["full", "light", "skip"]
    default: "full"
    description: >
      Depth of edge case hunting in Step 4. "full" probes all categories
      (input validation, concurrency, resource exhaustion, state transitions,
      external failures). "light" probes input validation and error paths
      only. "skip" disables edge case hunting (not recommended).
```

### /security -- Security Audit Settings

```yaml
settings:
  - name: history_scan_depth
    type: enum
    values: ["full", "recent", "current"]
    default: "full"
    description: >
      How deeply the secrets management review scans git history. "full"
      scans all commits for leaked secrets. "recent" scans the last 100
      commits. "current" scans only the current tree (fastest but misses
      historically leaked secrets).
  - name: threat_model_depth
    type: enum
    values: ["full", "abbreviated"]
    default: "full"
    description: >
      Depth of the STRIDE threat model in Step 3. "full" enumerates all
      attack surfaces and threats per domain. "abbreviated" covers only
      high-risk surfaces (external inputs, auth boundaries, data stores).
```

### /deploy -- Deployment Settings

```yaml
settings:
  - name: auto_archive_receipts
    type: boolean
    default: true
    description: >
      Automatically rename existing DEPLOY-RECEIPT.md to
      DEPLOY-RECEIPT-{timestamp}.md before writing a new receipt. When
      false, overwrite the existing receipt without archiving.
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
        "qa.write_missing_tests": true,
        "qa.edge_case_hunting": "full",
        "global.open_report": true
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

- **Inventing settings that should be in CLAUDE.md.** Settings control how Factory
  behaves, not the target project. Coverage targets, test commands, security severity
  thresholds, tech stack, and code style belong in CLAUDE.md or SPEC.md, not in
  settings. If the setting describes the project rather than Factory's behavior, it
  is not a setting.

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
   a flat JSON structure. Nested namespaces (e.g., `build.progress.tracking`) were
   considered and rejected -- they add complexity without meaningful benefit for the
   expected number of settings per skill (1-3).

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
   active during a run aids debugging ("why did QA use `light` edge case hunting last
   time?") but is not used for gating or validation.

6. **No environment-specific settings.** Settings do not vary by deployment environment
   (alpha/staging/prod). Environment-specific configuration belongs in deployment
   config (fly.toml, environment variables), not in Factory settings. If this becomes
   a need, it can be added as a `per_environment` flag on individual settings.

7. **Secret detection is best-effort.** The system checks for common secret patterns
   (AWS keys, GitHub tokens, etc.) but cannot catch all secrets. The anti-pattern
   documentation makes the policy clear; enforcement is advisory, not exhaustive.

8. **Settings control Factory behavior, not the target project.** The scope test is:
   does this setting change how Factory operates, or does it describe the project being
   built? Coverage targets, test commands, security severity thresholds, deployment
   platforms, and tech stack choices belong in CLAUDE.md or SPEC.md. The reviewed
   inventory (5 global + 17 per-skill) reflects this principle.

9. **`/factory settings` is a subcommand, not a standalone skill.** The orchestrator is
   always installed in a Factory project, so routing through `/factory` is safe and
   keeps meta-operations consolidated.

10. **Project-scoped settings only.** Settings live in `.factory/settings.json` in the
    project directory. User-scoped settings (`~/.factory/settings.json`) deferred to a
    future version if users request cross-project preferences. Precedence would be:
    project settings > user settings > schema defaults.

11. **No `null` values.** The `reset` command (key removal) reverts to the default.
    Storing `null` would be confusing when users hand-edit the file.

12. **`## Settings` section is optional.** Skills without settings (e.g., `/setup`)
    skip the settings protocol entirely. No empty boilerplate required.

### Open Questions

None. All questions from the initial design have been resolved (see decisions 9-12).
