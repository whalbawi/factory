# Orchestration — Domain Spec

## Overview

This domain owns the `/factory` orchestrator skill — the entry point that drives the user
through the full pipeline. It manages phase sequencing, state persistence, phase transitions,
backward navigation, and resumption after interruption.

## Internal Architecture

### Pipeline State Machine

The orchestrator models the pipeline as a state machine with forward progression and backward
navigation:

```text
idle -> ideation -> spec -> prototype -> setup -> build -> retro -> qa -> security -> deploy
  -> complete
         ^          ^        ^           ^        ^        ^        ^        ^
         |          |        |           |        |        |        |        |
         +----------+--------+-----------+--------+--------+--------+--------+--- (backward jumps)
```

Each state has four possible sub-states:

- `pending` — not yet started
- `in_progress` — currently executing
- `completed` — finished and output verified
- `skipped` — user chose to skip this phase (only for skippable phases)

Note: `/ideation` (when used for existing products) is a **standalone skill** not part of the
pipeline. It can be invoked at any time without affecting pipeline state. `/monitor` is
deferred to v1.1.

### State Persistence

State lives in `.factory/state.json`:

```json
{
  "pipeline": "factory",
  "project_name": "my-project",
  "started_at": "2026-04-03T10:00:00Z",
  "current_phase": "build",
  "phases": {
    "ideation": {
      "status": "completed",
      "started_at": "2026-04-03T10:00:00Z",
      "completed_at": "2026-04-03T10:45:00Z",
      "outputs": ["IDEATION.md"],
      "skipped": false
    },
    "spec": {
      "status": "completed",
      "started_at": "2026-04-03T10:45:00Z",
      "completed_at": "2026-04-03T12:00:00Z",
      "outputs": [
        "SPEC.md", "CLAUDE.md", "specs/SPEC-api.md", "specs/SPEC-frontend.md"
      ],
      "skipped": false
    },
    "prototype": {
      "status": "skipped",
      "skipped": true,
      "skip_reason": "User chose to skip — spec is clear enough"
    },
    "setup": {
      "status": "completed",
      "started_at": "2026-04-03T12:05:00Z",
      "completed_at": "2026-04-03T13:00:00Z",
      "outputs": ["fly.toml", "Dockerfile", ".github/workflows/ci.yml"],
      "skipped": false
    },
    "build": {
      "status": "in_progress",
      "started_at": "2026-04-03T13:00:00Z"
    }
  },
  "resets": [
    {
      "timestamp": "2026-04-03T14:00:00Z",
      "from_phase": "qa",
      "to_phase": "spec",
      "reason": "User wanted to revise the API design after QA revealed integration issues"
    }
  ]
}
```

State tracking is not exclusive to the `/factory` orchestrator. Every skill updates
`.factory/state.json` on invocation and completion, even when run standalone outside the
pipeline. The orchestrator reads existing state but does not own it exclusively — it
participates in a shared state model where individual skills are also responsible for
recording their own progress.

### Phase Transition Logic

At each phase boundary, the orchestrator:

1. **Verifies outputs** — Checks that the completing phase produced its declared output
   files. If outputs are missing, asks the user whether to re-run the phase or proceed
   without them.

2. **Presents summary** — 2-3 sentence summary of what was produced. Highlights key
   decisions or findings.

3. **Offers options**:

   - "Proceed to [next phase]" (default)
   - "Review [current phase] output" (let user inspect before moving on)
   - "Revise [current phase]" (re-run with adjustments)
   - "Skip [next phase]" (if the next phase is skippable)
   - "Go back to [phase]" (jump to any prior phase — see Backward Navigation)

4. **Updates state** — Records phase completion, advances `current_phase`.

Note: After `/build` completes, the orchestrator proceeds directly to `/retro`. The retro
phase is mandatory and cannot be skipped — it captures learnings from the build while they
are fresh.

### Backward Navigation

The pipeline supports jumping backward to any prior phase from any current phase. This
allows the user to revisit earlier decisions when later phases reveal issues.

#### Mechanics

When the user selects "Go back to [phase]":

1. The orchestrator sets the target phase's status to `in_progress`.

2. All phases after the target phase are reset to `pending`.

3. A record is appended to the `resets` array in state:

   ```json
   {
     "timestamp": "2026-04-03T14:00:00Z",
     "from_phase": "qa",
     "to_phase": "spec",
     "reason": "User wanted to revise the API design after QA revealed integration issues"
   }
   ```

4. Output files from reset phases are **not deleted** — they remain on disk but are
   considered stale. They may need to be regenerated after the user works through the
   phases again.

5. The user is warned before the jump is executed:

   ```text
   Going back to spec will mark prototype, setup, build, retro, and qa as pending.
   Their output files will be preserved but may need to be regenerated.
   Proceed? [Y/n]
   ```

#### Constraints

- The user can only jump backward, not forward past incomplete phases.
- Jumping backward always resets everything after the target phase, even skipped phases.
- The `resets` array provides an audit trail of all backward jumps for debugging and
  analytics.

### Resumption Logic

When `/factory` is invoked and `.factory/state.json` exists:

1. Read state file
2. Identify the last completed phase and the current phase
3. Present status: "You've completed [phases]. Currently on [current phase]. Want to
   continue, or start over?"
4. If continuing, verify that output files from completed phases still exist. If any are
   missing, flag it.
5. Resume at the current phase.

### Phase Skipping Rules

| Phase | Skippable? | Condition |
|-------|-----------|-----------|
| `/ideation` | Yes | User already has a clear idea |
| `/spec` | Yes | `SPEC.md` already exists |
| `/prototype` | Yes | Spec is clear enough, or user wants to go straight to build |
| `/setup` | Yes | Project is already scaffolded with CI/CD |
| `/build` | No | This is the core of the pipeline |
| `/retro` | No | Mandatory after build — captures learnings while fresh |
| `/qa` | No | Quality is not optional |
| `/security` | No | Security is not optional |
| `/deploy` | Yes | User may want to deploy manually |

### Entry at Any Phase

The orchestrator supports starting at any phase, not just the beginning:

1. User invokes `/factory` with no prior state
2. Orchestrator checks for existing artifacts:

   - `SPEC.md` exists? -> can skip `/ideation` and `/spec`
   - Project scaffold exists? -> can skip `/setup`
   - Source code exists and tests pass? -> can skip `/build` (and `/retro`)

3. Presents detected state: "I see you already have [artifacts]. Want to start from
   [phase]?"
4. User confirms or overrides.

---

## Orchestrator Skill Structure

```markdown
---
name: factory
description: Use when the user wants to "build a product", "start a project",
  "go from idea to production", "use the factory pipeline", or needs to be
  guided through the full process of ideating, speccing, prototyping, building,
  reviewing, testing, securing, and deploying a software product. This is the
  orchestrator for the entire Factory pipeline.
---

# Factory: Idea to Production Pipeline

[Full orchestrator instructions here — see the skill file specification below]
```

### Orchestrator Behavior Specification

**Opening**: When invoked, the orchestrator:

1. Checks for `.factory/state.json` — if exists, offer resumption
2. Checks for existing artifacts (`SPEC.md`, source code, etc.) — if exist, offer to skip
   completed phases
3. If greenfield: "Let's build something. Do you have an idea already, or want to
   brainstorm?"

**Phase invocation**: The orchestrator does NOT directly execute phase logic. It:

- Presents the phase purpose and what will happen
- Guides the user to invoke the sub-skill (or invokes it automatically)
- Waits for completion
- Verifies outputs
- Manages the transition

**Error handling**:

- Sub-skill fails: Stay on current phase, diagnose, retry or ask user
- User rejects output: Re-run phase with user's feedback incorporated
- Unexpected state: Present what happened and ask user how to proceed — don't guess

**Completion**: When all phases are done (after `/deploy`):

- Present a full summary of what was built
- List all artifacts produced
- Confirm the product is deployed
- Suggest next steps: "You can run `/ideation` to brainstorm new features. `/monitor` is
  coming in v1.1."

---

## QA Perspective

### Orchestrator Acceptance Criteria

1. **Fresh start**: `/factory` on empty repo starts at ideation/spec phase
2. **Resumption**: `/factory` with existing state file resumes correctly
3. **Skip detection**: `/factory` with existing SPEC.md offers to skip spec phase
4. **Phase gating**: Cannot advance past retro, QA, or security if they report failures
5. **State persistence**: State file is updated after every phase transition
6. **Shared state**: Individual skills update `.factory/state.json` independently; the
   orchestrator correctly reads state written by standalone skill invocations
7. **All paths**: Every phase can be entered, completed, skipped (where allowed), and
   re-run
8. **Clean exit**: User can exit at any point and resume later
9. **Backward navigation**: User can jump to any prior phase; later phases are reset to
   pending; output files are preserved; resets array is updated; user is warned before
   the jump
10. **Retro is mandatory**: `/retro` always runs after `/build` and cannot be skipped

### Backward Navigation Scenario

1. User completes ideation, spec, setup, build, retro, and enters QA.
2. QA reveals that the API contract in the spec is wrong.
3. User selects "Go back to spec" at the QA phase boundary.
4. Orchestrator warns: "Going back to spec will mark prototype, setup, build, retro, and
   qa as pending. Their output files will be preserved but may need to be regenerated.
   Proceed? [Y/n]"
5. User confirms. State is updated: spec is `in_progress`, prototype/setup/build/retro/qa
   are `pending`.
6. A record is added to `resets` with `from_phase: "qa"`, `to_phase: "spec"`.
7. User revises the spec and proceeds through the pipeline again.

### Edge Cases

- State file exists but is malformed — reset state, inform user
- Output files referenced in state but deleted from disk — detect and re-run phase
- User invokes a sub-skill directly while factory pipeline is active — state file should
  not be corrupted; standalone skill writes are compatible with orchestrator reads
- Two `/factory` invocations simultaneously — not supported in v1, but must not corrupt
  state file
- Backward jump to a phase whose output files were manually edited — warn user that the
  phase will overwrite those files if re-run

---

## Product Design Perspective

### Pipeline UX Flow

```text
Welcome to Factory.

[If resuming]
> You've completed ideation, spec, and prototype.
> Currently on: setup
> Continue from setup? [Y/n]

[If fresh]
> Let's build something.
> Do you already have an idea, or want to brainstorm? [idea / brainstorm]

--- Phase transition (after build) ---

> Build complete. Here's what was produced:
> - 12 source files across 3 domains
> - All 47 tests passing
>
> Moving to retro to capture learnings from the build.

--- Phase transition (after retro) ---

> Retro complete. Key takeaways:
> - [summary of learnings]
>
> Ready for QA? [Y / review retro / revise / go back to build]

--- Phase transition ---

> Spec complete. Here's what was produced:
> - SPEC.md: [product name] — [one-liner]
> - 3 domain specs: api, frontend, storage
> - CLAUDE.md with build conventions
>
> Key decisions:
> - Tech stack: TypeScript, React, PostgreSQL
> - Deployment: Fly.io
>
> Ready to prototype? [Y / review spec / revise / skip / go back to ideation]

--- Backward navigation ---

> Going back to spec will mark prototype, setup, build, retro, and qa as pending.
> Their output files will be preserved but may need to be regenerated.
> Proceed? [Y/n]
```

### Information Density

At each transition, present:

- What was just done (1 sentence)
- What was produced (file list)
- Key decisions (2-3 bullets)
- What's next (1 sentence + options, including backward navigation)

Do NOT dump the full content of output files. The user can read them if they want.
Summaries only.

---

## Tech Writing Perspective

### Orchestrator Help Text

When the user seems confused about what Factory does or where they are:

```text
Factory guides you from idea to deployed product through these phases:

  /ideation  → Brainstorm and explore ideas
  /spec      → Turn idea into buildable specification
  /prototype → Quick throwaway implementations for feedback
  /setup     → Project scaffolding, CI/CD, infrastructure
  /build     → Agent teams construct the product
  /retro     → Team retrospective — mandatory after build
  /qa        → Structured quality control
  /security  → Security audit and hardening
  /deploy    → Push to production

Coming in v1.1:
  /monitor   → Health monitoring and bug triage

You can run the full pipeline with /factory, or use any skill independently.
Current status: [phase] ([X of 9] phases complete)
```

### State File Documentation

The `.factory/state.json` file is human-readable by design. If a user opens it, they should
understand their pipeline status without consulting docs.

Every skill — whether invoked via the `/factory` pipeline or standalone — reads and writes
`.factory/state.json`. This means state is always up to date, even if the user runs
`/build` or `/retro` directly without the orchestrator.
