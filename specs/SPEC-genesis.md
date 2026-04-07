# Orchestration -- Domain Spec

## Overview

This domain owns the `/genesis` orchestrator skill -- the entry point that drives the user
through the full 9-phase pipeline. It manages phase sequencing, state persistence, phase
transitions, backward navigation, resumption after interruption, sprint loops during build,
claim mode for onboarding existing codebases, and a settings command for managing persistent
user preferences.

## Pipeline State Machine

The orchestrator models the pipeline as a state machine with forward progression and backward
navigation:

```text
idle -> ideation -> spec -> prototype -> setup -> build -> retro -> qa -> security -> deploy
  -> complete
         ^          ^        ^           ^        ^        ^        ^        ^
         |          |        |           |        |        |        |        |
         +----------+--------+-----------+--------+--------+--------+--------+--- (backward)
```

Each state has five possible sub-states:

- `pending` -- not yet started
- `in_progress` -- currently executing
- `completed` -- finished and output verified
- `skipped` -- user chose to skip this phase (only for skippable phases)
- `partial` -- some artifacts exist but phase is not fully satisfied (written only by
  claim mode)

Skills reading state should treat `partial` the same as `pending` for gating purposes --
they check for required input files, not phase status.

## State Persistence

State lives in `.factory/state.json`. The orchestrator participates in a shared state model
where individual skills are also responsible for recording their own progress. Every skill
reads and writes this file, whether invoked through the pipeline or standalone.

The state file tracks: `pipeline`, `project_name`, `started_at`, `current_phase`, `phases`
(map of each phase to its status, timestamps, and outputs), and `resets` (audit trail of
backward navigation jumps).

When a project is onboarded via `/genesis claim`, the state file also includes:

- `claimed` (boolean) -- whether claim completed successfully
- `claimed_at` (ISO 8601 timestamp) -- when claim finished
- `claim_confidence` -- count of findings at each confidence level:
  `{"high": N, "medium": N, "low": N}`

Phases backfilled by claim include `confidence` (high/medium/low) and `findings` (array of
strings explaining what was detected).

If the state file exists but is malformed, back it up to `.factory/state.json.bak`, create a
fresh state file, and inform the user.

## Opening Behavior

The skill uses the standard Skill Parameters pattern referencing GLOBAL-REFERENCE.md with
`{PHASE_NAME}` = `genesis` and `{OUTPUT_FILES}` = `[".factory/state.json"]`. It also
references the Gate Verification section.

On invocation:

1. **Check for claim mode**: If the user invokes `/genesis claim` (or equivalent phrasing
   like "onboard this codebase"), enter claim mode instead of normal pipeline flow.
2. **Existing state**: If `.factory/state.json` exists, offer resumption. Verify output
   files from completed phases still exist on disk.
3. **Existing artifacts (no state)**: Scan for `SPEC.md`, project scaffolds, source code
   with passing tests, and suggest a starting phase.
4. **Greenfield**: Offer brainstorming or idea-first flow.

## Phase Transition Logic

At each phase boundary:

1. **Verify outputs** -- check that the completing phase produced its declared output files.
2. **Present summary** -- 2-3 sentence summary highlighting key decisions. Do not dump full
   file contents.
3. **Offer options** -- proceed (default), review output, revise, skip (if skippable), or go
   back to a prior phase.
4. **Update state** -- record completion, advance `current_phase`.

After `/build` completes, proceed directly to `/retro`. The retro phase is mandatory and
cannot be skipped.

## Sprint Loop

When the build phase begins and `SPEC.md` contains a `## Sprint Plan` with more than one
sprint, the orchestrator enters a sprint loop instead of a single `/build` invocation:

```text
for each sprint N in sprint_plan:
  1. Invoke /build (builds sprint N only)
  2. Verify /build outputs (PROGRESS.md updated, sprint N tasks merged)
  3. If sprint_checkpoints != "skip":
     a. Invoke /qa in sprint-scoped mode (sprint N)
     b. If sprint_checkpoints == "full":
        Invoke /security in sprint-scoped mode (sprint N)
     c. If checkpoint fails:
        Present findings, offer fix/override/abort
  4. Present sprint summary
  5. If confirm_phase_transition is true, wait for user confirmation

After all sprints:
  - Proceed to /retro (mandatory)
  - Then /qa (full project pass)
  - Then /security (full project pass)
  - Then /deploy
```

Sprint progress is tracked in `phases.build.sprints` with `total`, `current`,
`completed[]` (per-sprint timestamps, task counts, checkpoint results), and `overrides[]`.

On resumption, the orchestrator continues from the last incomplete sprint. Going back to
`/spec` resets all sprint progress. Going back to `/build` (e.g., from `/retro`) resumes
from the last incomplete sprint.

## Backward Navigation

The user can jump backward to any prior phase. When selected:

1. Warn which phases will be reset to `pending`.
2. Set the target phase to `in_progress`.
3. Reset all downstream phases to `pending` (including skipped).
4. Append a record to `resets` with `timestamp`, `from_phase`, `to_phase`, and `reason`.
5. Preserve output files on disk (stale, may need regeneration).

Only backward jumps are allowed, not forward past incomplete phases.

## Phase Skipping Rules

| Phase        | Skippable? | Condition                                    |
|--------------|------------|----------------------------------------------|
| `/ideation`  | Yes        | User already has a clear idea                |
| `/spec`      | Yes        | `SPEC.md` already exists                     |
| `/prototype` | Yes        | Spec is clear enough, or user wants to skip  |
| `/setup`     | Yes        | Project already scaffolded with CI/CD        |
| `/build`     | **No**     | Core of the pipeline                         |
| `/retro`     | **No**     | Mandatory after build -- captures learnings  |
| `/qa`        | **No**     | Quality is not optional                      |
| `/security`  | **No**     | Security is not optional                     |
| `/deploy`    | Yes        | User may want to deploy manually             |

Gate finality: once `/qa` or `/security` has run, no further code changes may land without
re-running the affected gate. The `Tested commit` field must match HEAD for `/deploy` to
proceed.

## CLAUDE.md Generation

The orchestrator generates process rules for the project's `CLAUDE.md` using the template
in `references/process-rules-template.md`. Content is written inside
`<!-- factory:process-rules:start -->` / `<!-- factory:process-rules:end -->` markers.
The `[project]` placeholder is replaced with the actual project name from state.

## Claim Mode

Claim mode onboards existing codebases into the Factory pipeline. It reads the project,
infers which phases are satisfied, writes `.factory/state.json`, and proposes a `CLAUDE.md`.
Activates on `/genesis claim` or equivalent phrasing. If already claimed, warns before
overwriting.

The claim protocol is defined in `references/claim-layers.md`, which contains:

- A five-layer deep-read protocol (Layer 1 Package Manifests through Layer 5 Project
  Structure)
- Confidence classification rules (high/medium/low)
- Artifact-to-phase mapping table for state backfill
- Steps 4-7: findings presentation, CLAUDE.md generation, feedback loop, and handoff

## Settings Command

The `/genesis settings` subcommand manages persistent user preferences stored in
`.factory/settings.json`. Keys use dot notation (`skill.setting_name`). Four operations:

- **list**: Display all settings grouped by skill.
- **get `<key>`**: Show a single setting's value, default, and type.
- **set `<key>` `<value>`**: Validate against schema and write.
- **reset `<key>`**: Remove stored value, revert to schema default.

## Error Handling

- **Sub-skill fails**: Stay on current phase, diagnose, retry or ask the user.
- **User rejects output**: Re-run with feedback. Do not advance.
- **Unexpected state**: Present the problem clearly. Do not guess.
- **Missing output files**: Detect and offer to re-run the producing phase.

## Anti-Patterns

- **Executing phase logic inline.** The orchestrator sequences phases -- it does not
  implement them.
- **Advancing past failed phases.** If a sub-skill fails, stay on that phase.
- **Skipping output verification.** Confirm outputs before advancing.
- **Overwriting existing artifacts without warning.** Always ask before re-running a phase
  that would regenerate existing artifacts.
- **Dumping full file contents at transitions.** Present 2-3 sentence summaries only.
- **Silently resetting downstream phases.** Always warn before backward navigation.
