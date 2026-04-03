# Orchestration — Domain Spec

## Overview

This domain owns the `/factory` orchestrator skill — the entry point that drives the user through the full pipeline. It manages phase sequencing, state persistence, phase transitions, and resumption after interruption.

## Internal Architecture

### Pipeline State Machine

The orchestrator models the pipeline as a linear state machine:

```
idle -> ideation -> spec -> prototype -> setup -> build -> qa -> security -> deploy -> monitor -> complete
```

Each state has four possible sub-states:
- `pending` — not yet started
- `in_progress` — currently executing
- `completed` — finished and output verified
- `skipped` — user chose to skip this phase (only for skippable phases)

Note: `/review` and `/ideation` (when used for existing products) are **standalone skills** not part of the linear pipeline. They can be invoked at any time without affecting pipeline state.

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
      "outputs": ["SPEC.md", "CLAUDE.md", "specs/SPEC-api.md", "specs/SPEC-frontend.md"],
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
  }
}
```

### Phase Transition Logic

At each phase boundary, the orchestrator:

1. **Verifies outputs** — Checks that the completing phase produced its declared output files. If outputs are missing, asks the user whether to re-run the phase or proceed without them.

2. **Presents summary** — 2-3 sentence summary of what was produced. Highlights key decisions or findings.

3. **Offers options**:
   - "Proceed to [next phase]" (default)
   - "Review [current phase] output" (let user inspect before moving on)
   - "Revise [current phase]" (re-run with adjustments)
   - "Skip [next phase]" (if the phase is skippable)

4. **Updates state** — Records phase completion, advances `current_phase`.

### Resumption Logic

When `/factory` is invoked and `.factory/state.json` exists:

1. Read state file
2. Identify the last completed phase and the current phase
3. Present status: "You've completed [phases]. Currently on [current phase]. Want to continue, or start over?"
4. If continuing, verify that output files from completed phases still exist. If any are missing, flag it.
5. Resume at the current phase.

### Phase Skipping Rules

| Phase | Skippable? | Condition |
|-------|-----------|-----------|
| `/ideation` | Yes | User already has a clear idea |
| `/spec` | Yes | `SPEC.md` already exists |
| `/prototype` | Yes | Spec is clear enough, or user wants to go straight to build |
| `/setup` | Yes | Project is already scaffolded with CI/CD |
| `/build` | No | This is the core of the pipeline |
| `/qa` | No | Quality is not optional |
| `/security` | No | Security is not optional |
| `/deploy` | Yes | User may want to deploy manually |
| `/monitor` | Yes | User may not have monitoring infrastructure |

### Entry at Any Phase

The orchestrator supports starting at any phase, not just the beginning:

1. User invokes `/factory` with no prior state
2. Orchestrator checks for existing artifacts:
   - `SPEC.md` exists? -> can skip `/ideation` and `/spec`
   - Project scaffold exists? -> can skip `/setup`
   - Source code exists and tests pass? -> can skip `/build`
3. Presents detected state: "I see you already have [artifacts]. Want to start from [phase]?"
4. User confirms or overrides.

---

## Orchestrator Skill Structure

```markdown
---
name: factory
description: Use when the user wants to "build a product", "start a project",
  "go from idea to production", "use the factory pipeline", or needs to be
  guided through the full process of ideating, speccing, prototyping, building,
  testing, securing, deploying, and monitoring a software product. This is the
  orchestrator for the entire Factory pipeline.
---

# Factory: Idea to Production Pipeline

[Full orchestrator instructions here — see the skill file specification below]
```

### Orchestrator Behavior Specification

**Opening**: When invoked, the orchestrator:
1. Checks for `.factory/state.json` — if exists, offer resumption
2. Checks for existing artifacts (`SPEC.md`, source code, etc.) — if exist, offer to skip completed phases
3. If greenfield: "Let's build something. Do you have an idea already, or want to brainstorm?"

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

**Completion**: When all phases are done:
- Present a full summary of what was built
- List all artifacts produced
- Confirm the product is deployed and monitored
- Suggest next steps: "You can run `/ideation` to brainstorm new features, `/review` for a team sync, or `/monitor` to check health."

---

## QA Perspective

### Orchestrator Acceptance Criteria

1. **Fresh start**: `/factory` on empty repo starts at ideation/spec phase
2. **Resumption**: `/factory` with existing state file resumes correctly
3. **Skip detection**: `/factory` with existing SPEC.md offers to skip spec phase
4. **Phase gating**: Cannot advance past QA or security if they report failures
5. **State persistence**: State file is updated after every phase transition
6. **All paths**: Every phase can be entered, completed, skipped (where allowed), and re-run
7. **Clean exit**: User can exit at any point and resume later

### Edge Cases

- State file exists but is malformed — reset state, inform user
- Output files referenced in state but deleted from disk — detect and re-run phase
- User invokes a sub-skill directly while factory pipeline is active — state file should not be corrupted
- Two `/factory` invocations simultaneously — not supported in v1, but must not corrupt state file

---

## Product Design Perspective

### Pipeline UX Flow

```
Welcome to Factory.

[If resuming]
> You've completed ideation, spec, and prototype.
> Currently on: setup
> Continue from setup? [Y/n]

[If fresh]
> Let's build something.
> Do you already have an idea, or want to brainstorm? [idea / brainstorm]

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
> Ready to prototype? [Y / review spec / revise / skip]
```

### Information Density

At each transition, present:
- What was just done (1 sentence)
- What was produced (file list)
- Key decisions (2-3 bullets)
- What's next (1 sentence + options)

Do NOT dump the full content of output files. The user can read them if they want. Summaries only.

---

## Tech Writing Perspective

### Orchestrator Help Text

When the user seems confused about what Factory does or where they are:

```
Factory guides you from idea to deployed product through these phases:

  /ideation  → Brainstorm and explore ideas
  /spec      → Turn idea into buildable specification
  /prototype → Quick throwaway implementations for feedback
  /setup     → Project scaffolding, CI/CD, infrastructure
  /build     → Agent teams construct the product
  /qa        → Structured quality control
  /security  → Security audit and hardening
  /deploy    → Push to production
  /monitor   → Health monitoring and bug triage

You can run the full pipeline with /factory, or use any skill independently.
Current status: [phase] ([X of 9] phases complete)
```

### State File Documentation

The `.factory/state.json` file is human-readable by design. If a user opens it, they should understand their pipeline status without consulting docs.
