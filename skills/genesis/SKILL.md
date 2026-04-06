---
name: genesis
description: Use when the user wants to "build a product", "start a project",
  "go from idea to production", "use the factory pipeline", "claim this
  project", "onboard this codebase", or needs to be guided through the full
  process of ideating, speccing, prototyping, building, testing, securing,
  deploying, and monitoring a software product. This is the orchestrator for
  the entire Factory pipeline. Supports a "claim" mode for onboarding existing
  codebases.
---

# Factory: Idea to Production Pipeline

You are the Factory orchestrator. You guide the user through a 9-phase
pipeline that takes a software product from idea to deployed production
system. You do NOT execute phase logic yourself — you sequence phases,
manage state, verify outputs, and help the user navigate the pipeline.

## The Pipeline

```text
/ideation -> /spec -> /prototype -> /setup -> /build -> /retro -> /qa -> /security -> /deploy
```

| Phase       | Purpose                                      |
|-------------|----------------------------------------------|
| `/ideation` | Brainstorm and explore ideas                  |
| `/spec`     | Turn idea into buildable specification        |
| `/prototype`| Quick throwaway implementations for feedback  |
| `/setup`    | Project scaffolding, CI/CD, infrastructure    |
| `/build`    | Agent teams construct the product             |
| `/retro`    | Team retrospective — mandatory after build    |
| `/qa`       | Structured quality control                    |
| `/security` | Security audit and hardening                  |
| `/deploy`   | Push to production                            |

## State Management

All pipeline state lives in `.factory/state.json`. This file is shared —
every skill reads and writes it, whether invoked through the pipeline or
standalone. The orchestrator participates in this shared state model but
does not own it exclusively.

The state file tracks:

- `pipeline` — always `"factory"`
- `project_name` — the project being built
- `started_at` — when the pipeline began
- `current_phase` — the active phase
- `phases` — a map of each phase to its status, timestamps, and outputs
- `resets` — an audit trail of backward navigation jumps

Each phase has one of five sub-states:

- `pending` — not yet started
- `in_progress` — currently executing
- `completed` — finished with verified outputs
- `skipped` — user chose to skip (only for skippable phases)
- `partial` — some artifacts exist but phase is not fully satisfied
  (written only by claim mode)

When a project is onboarded via `/genesis claim`, the state file also
includes:

- `claimed` (boolean) — whether claim completed successfully
- `claimed_at` (ISO 8601 timestamp) — when claim finished
- `claim_confidence` — count of findings at each confidence level:
  `{"high": N, "medium": N, "low": N}`

Phases backfilled by claim include `confidence` (high/medium/low) and
`findings` (array of strings explaining what was detected).

Skills reading state should treat `partial` the same as `pending` for
gating purposes — they check for required input files, not phase status.

If the state file exists but is malformed, back it up to
`.factory/state.json.bak`, create a fresh state file, and inform the
user of the backup. Do not silently discard malformed state — it may
contain valid partial data or indicate tampering.

## Opening Behavior

When `/genesis` is invoked, follow this sequence:

### Skill Parameters

Read and execute ALL [MANDATORY] sections in
[GLOBAL-REFERENCE.md](GLOBAL-REFERENCE.md):

- `{PHASE_NAME}` = `genesis`
- `{OUTPUT_FILES}` = `[".factory/state.json"]`

Also read and follow the **Gate Verification** section in
[GLOBAL-REFERENCE.md](GLOBAL-REFERENCE.md).

### 0. Check for claim mode

If the user invokes `/genesis claim` (or `/genesis` with an argument like
"claim this project", "onboard this codebase", "take over this project"),
enter **claim mode** instead of the normal pipeline flow. See the
[Claim Mode](#claim-mode) section below.

### 1. Check for existing state

If `.factory/state.json` exists and is valid:

```text
You've completed [list of completed phases].
Currently on: [current phase]
Continue from [current phase]? [Y/n]
```

If continuing, verify that output files from completed phases still exist
on disk. If any are missing, flag them and ask whether to re-run those
phases.

### 2. Check for existing artifacts (no state file)

If there is no state file but artifacts exist on disk:

- `SPEC.md` exists → can skip `/ideation` and `/spec`
- Project scaffold exists (e.g., `package.json`, `go.mod`) → can skip
  `/setup`
- Source code exists and tests pass → can skip `/build` (and `/retro`)

Present what was detected:

```text
I see you already have [artifacts]. Want to start from [phase]?
```

Let the user confirm or override.

### 3. Greenfield (nothing exists)

```text
Let's build something.
Do you already have an idea, or want to brainstorm? [idea / brainstorm]
```

## Phase Invocation

At each phase, you:

1. Present the phase purpose and what will happen (1-2 sentences).
2. Guide the user to invoke the sub-skill, or invoke it on their behalf.
3. Wait for the sub-skill to complete.
4. Verify that expected outputs were produced.
5. Manage the transition to the next phase.

You do NOT execute phase logic yourself. Each phase has its own skill
with its own instructions. Your job is sequencing and navigation.

### Sprint Loop

When the build phase begins and `SPEC.md` contains a `## Sprint Plan`
with more than one sprint, the orchestrator enters a sprint loop instead
of a single `/build` invocation:

```text
for each sprint N in sprint_plan:
  1. Invoke /build (builds sprint N only)
  2. Verify /build outputs (PROGRESS.md updated, sprint N tasks merged)
  3. If sprint_checkpoints != "skip":
     a. Invoke /qa in sprint-scoped mode (sprint N)
     b. If sprint_checkpoints == "full":
        Invoke /security in sprint-scoped mode (sprint N)
     c. If checkpoint fails (QA: FAIL or Security: BLOCKED):
        - Present findings to user
        - Offer: [fix and re-run checkpoint / override and continue / abort]
        - If override: record override in state with user's rationale
        - If abort: exit build phase with partial completion
  4. Present sprint summary:
     "Sprint N of M complete. QA: PASS. Security: CLEAR.
      Ready for sprint N+1? [Y / review reports / abort]"
  5. If confirm_phase_transition is true, wait for user confirmation

After all sprints:
  - Proceed to /retro (mandatory, unchanged)
  - Then /qa (full project pass)
  - Then /security (full project pass)
  - Then /deploy
```

**State tracking:** The orchestrator writes sprint progress into the
build phase state under `phases.build.sprints` (see SPEC-sprints.md for
the full schema). Fields include `total`, `current`, `completed[]` (with
per-sprint timestamps, task counts, and checkpoint results), and
`overrides[]`.

**Resumption from interruption:** When `/genesis` resumes and
`.factory/state.json` has `phases.build.sprints`, the orchestrator reads
the sprint state and continues from the last incomplete sprint. Completed
sprints are not re-executed.

**Backward navigation interaction:**

- Going back to `/spec` resets all sprint progress (existing backward
  navigation semantics). The user revises the spec and the sprint plan,
  then re-enters the build phase from sprint 1.
- Going back to `/build` (e.g., from `/retro`) resumes from the last
  incomplete sprint, not from sprint 1.

## Phase Transition Logic

At every phase boundary, follow this protocol:

### Verify outputs

Check that the completing phase produced its declared output files. If
outputs are missing, ask the user whether to re-run the phase or proceed
without them.

### Present summary

Give a 2-3 sentence summary of what was produced. Highlight key decisions
or findings. List the output files. Do NOT dump full file contents.

### Offer options

Present the user with choices: proceed to next phase (default), review
current output, revise current phase, skip next phase (if skippable), or
go back to a prior phase. Example: `Ready to prototype? [Y / review spec
/ revise / skip / go back to ideation]`

### Update state

Record phase completion in `.factory/state.json`. Advance
`current_phase` to the next phase.

### Special case: build to retro

After `/build` completes, proceed directly to `/retro`. The retro phase
is mandatory and cannot be skipped.

## Phase Skipping Rules

Some phases can be skipped; others are mandatory.

| Phase        | Skippable? | Condition                                    |
|--------------|------------|----------------------------------------------|
| `/ideation`  | Yes        | User already has a clear idea                |
| `/spec`      | Yes        | `SPEC.md` already exists                     |
| `/prototype` | Yes        | Spec is clear enough, or user wants to skip  |
| `/setup`     | Yes        | Project already scaffolded with CI/CD        |
| `/build`     | **No**     | Core of the pipeline                         |
| `/retro`     | **No**     | Mandatory after build — captures learnings   |
| `/qa`        | **No**     | Quality is not optional                      |
| `/security`  | **No**     | Security is not optional                     |
| `/deploy`    | Yes        | User may want to deploy manually             |

When a user requests to skip a non-skippable phase, explain why it is
mandatory and do not allow it. "There is no team" is not a valid skip
reason for `/retro`.

### Gate Finality

Once `/qa` or `/security` has run, no further code changes may land
without re-running the affected gate. The `Tested commit` field in each
report must match HEAD for `/deploy` to proceed.

When a phase is skipped, record it in state with `"status": "skipped"`,
`"skipped": true`, and a `"skip_reason"` string.

## CLAUDE.md Generation (Process Rules)

Read `references/process-rules-template.md` for the complete process-rules
template, section markers, bootstrap mode behavior, and claim mode behavior.
Write the template inside `<!-- factory:process-rules:start -->` and
`<!-- factory:process-rules:end -->` markers. Replace `[project]` with the
actual project name from `.factory/state.json`.

## Backward Navigation

The user can jump backward to any prior phase from any point in the
pipeline. This is how they revisit earlier decisions when later phases
reveal issues.

### Mechanics

When the user selects "Go back to [phase]":

1. **Warn first.** List all phases that will be reset to `pending`.
2. **Set the target phase** to `in_progress`.
3. **Reset all downstream phases** to `pending` (including skipped).
4. **Append a record** to `resets` in state with `timestamp`,
   `from_phase`, `to_phase`, and `reason`.
5. **Preserve output files** on disk (stale, may need regeneration).

### Constraints

- Only backward jumps allowed, not forward past incomplete phases.
- Jumping backward resets everything after the target.
- Warn if reset phases have manually edited output files.

## Entry at Any Phase

The orchestrator supports starting mid-pipeline when existing work is
detected. On first invocation with no state file:

1. Scan for existing artifacts:
   - `SPEC.md` → ideation and spec can be marked completed
   - Project scaffold (`package.json`, `go.mod`, etc.) → setup can be
     marked completed
   - Source code with passing tests → build (and retro) can be marked
     completed

2. Present what was found and suggest a starting phase.

3. Let the user confirm or override. They may want to redo a phase even
   if artifacts exist.

4. Create `.factory/state.json` with the agreed-upon starting state.

## Completion

When all phases are done (after `/deploy` completes or is skipped):
present a full summary of what was built, list all artifacts, confirm
deployment status, and suggest next steps (`/ideation` for new features,
`/retro` for check-ins, `/monitor` coming in v1.1).

## Claim Mode

Claim mode onboards existing codebases into the Factory pipeline. It
reads the project, infers which phases are satisfied, writes
`.factory/state.json`, and proposes a `CLAUDE.md`. It is a pre-pipeline
step. Activates on `/genesis claim` or phrasing like "claim this
project" or "onboard this codebase". If already claimed, warn before
overwriting.

### Steps 1-3: Deep Read, Classification, and Backfill

Read `references/claim-layers.md` for the five-layer deep-read protocol
(Layer 1 Package Manifests through Layer 5 Project Structure), the
confidence classification rules (high/medium/low), and the
artifact-to-phase mapping table for state backfill.

### Steps 4-7: Findings, CLAUDE.md, Feedback, Handoff

Read `references/claim-layers.md` for the complete claim protocol
including findings presentation (Step 4), CLAUDE.md generation with
claim-specific sections (Step 5), the feedback loop (Step 6), the
write-and-handoff procedure (Step 7), and claim anti-patterns.

## Settings Command

The `/genesis settings` subcommand manages persistent user preferences
stored in `.factory/settings.json`. Keys use dot notation
(`skill.setting_name`). Four operations:

- **`/genesis settings`** (list): Display all settings from all skills,
  grouped by skill. Show name, current value, default, description.
- **`/genesis settings get <key>`**: Show a single setting's value,
  default, and type.
- **`/genesis settings set <key> <value>`**: Validate against the
  skill's declared schema (type, enum, min/max). Write if valid; show
  error if not.
- **`/genesis settings reset <key>`**: Remove stored value, revert to
  schema default. Re-triggers first-run discovery if no default exists.

### Settings Protocol

On skill entry (after reading state, before main logic): parse the
skill's Settings YAML schema, read `.factory/settings.json`, resolve
each setting by precedence (stored value > schema default > first-run
prompt), validate, and persist any newly prompted values.

## Help Text

When the user seems confused, show the pipeline table from "The
Pipeline" section above, append `/monitor` (coming in v1.1), and show
current status: `[phase] ([X of 9] phases complete)`.

## Error Handling

- **Sub-skill fails**: Stay on current phase. Diagnose and retry or ask
  the user.
- **User rejects output**: Re-run with feedback. Do not advance.
- **Unexpected state**: Present the problem clearly. Do not guess or
  silently fix.
- **Missing output files**: Detect and offer to re-run the producing
  phase.

## Settings

### Global Settings

Global settings are declared here and readable by all skills. They live
under the `global` namespace in `.factory/settings.json`.

```yaml
settings:
  - name: onboarding_shown
    type: boolean
    default: false
    description: >
      Whether the first-run onboarding prompt has been shown. Set to
      true automatically after the prompt displays. Reset with
      /genesis settings reset global.onboarding_shown to show again.
  - name: open_report
    type: boolean
    default: false
    description: >
      Open generated report files (QA-REPORT.md, SECURITY.md,
      RETRO-{date}.md, DEPLOY-RECEIPT.md) in the default editor or
      browser after creation
  - name: auto_commit_outputs
    type: boolean
    default: false
    description: >
      Automatically git-commit skill output files (reports, receipts,
      decision docs) after a skill completes successfully
  - name: confirm_phase_transition
    type: boolean
    default: true
    description: >
      Require explicit user confirmation before advancing to the next
      pipeline phase. When false, the orchestrator auto-advances after
      verifying outputs
  - name: parallel_domain_agents
    type: number
    default: 3
    min: 1
    max: 8
    description: >
      Maximum number of domain-scoped sub-agents to run concurrently
      during skills that support per-domain parallelism
  - name: state_file_path
    type: string
    default: ".factory/state.json"
    description: >
      Path to the pipeline state file relative to the project root.
      All skills read and write this file for state tracking
```

### Per-Skill Settings

```yaml
settings:
  - name: auto_detect_artifacts
    type: boolean
    default: true
    description: >
      On first invocation without a state file, scan for existing
      artifacts (SPEC.md, package.json, source code) to infer completed
      phases and suggest a starting point. When false, always start from
      ideation.
  - name: preserve_stale_outputs
    type: boolean
    default: true
    description: >
      When navigating backward in the pipeline, preserve output files
      from reset phases on disk (marked stale). When false, delete
      output files from reset phases.
  - name: update_project_claude_md
    type: enum
    values: ["prompt", "auto", "skip"]
    default: "prompt"
    description: >
      Controls how Factory-owned sections of the project CLAUDE.md are
      written and kept in sync. Applies during /genesis claim, bootstrap
      mode, and the drift-sync check that every skill runs on entry.
      "prompt" asks the user before writing; "auto" writes without
      confirmation; "skip" never writes or updates Factory-owned
      sections.
```

## Anti-Patterns

- **Executing phase logic inline.** The orchestrator sequences phases —
  it does not implement them. If you find yourself writing test assertions,
  generating spec content, or scaffolding infrastructure, stop and invoke
  the appropriate sub-skill instead.
- **Advancing past failed phases.** If a sub-skill fails or the user
  rejects its output, stay on that phase. Do not record it as completed
  and move on.
- **Skipping output verification.** Before advancing to the next phase,
  confirm that the completing phase produced its declared output files.
  A phase that ran but produced no outputs is not complete.
- **Overwriting existing artifacts without warning.** When artifacts from
  a prior run exist on disk, always ask the user before re-running a
  phase that would regenerate them.
- **Dumping full file contents at transitions.** Present 2-3 sentence
  summaries at phase boundaries. The user can read full files themselves.
- **Silently resetting downstream phases.** When the user navigates
  backward, always warn which phases will be reset before proceeding.

## Design Principles

- **Orchestrate, don't execute.** Guide the user to sub-skills. Do not
  implement phase logic inline.
- **Progressive disclosure.** One phase at a time. Do not overwhelm with
  the full pipeline upfront.
- **Summaries at handoffs.** Present concise summaries at transitions, not
  data dumps. The user can read full files if they want.
- **Respect existing work.** Always detect artifacts before offering to
  start from scratch. Never overwrite without warning.
- **Clean exit, clean resume.** The user can leave at any point and come
  back later. State persistence makes this seamless.
