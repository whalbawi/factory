---
name: factory
description: Use when the user wants to "build a product", "start a project",
  "go from idea to production", "use the factory pipeline", or needs to be
  guided through the full process of ideating, speccing, prototyping, building,
  testing, securing, deploying, and monitoring a software product. This is the
  orchestrator for the entire Factory pipeline.
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

Each phase has one of four sub-states:

- `pending` — not yet started
- `in_progress` — currently executing
- `completed` — finished with verified outputs
- `skipped` — user chose to skip (only for skippable phases)

If the state file exists but is malformed, reset it and inform the user.

## Opening Behavior

When `/factory` is invoked, follow this sequence:

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

## Phase Transition Logic

At every phase boundary, follow this protocol:

### Verify outputs

Check that the completing phase produced its declared output files. If
outputs are missing, ask the user whether to re-run the phase or proceed
without them.

### Present summary

Give a 2-3 sentence summary of what was produced. Highlight key decisions
or findings. List the output files. Do NOT dump the full content of
output files — summaries only.

Example:

```text
Spec complete. Here's what was produced:
- SPEC.md: [product name] — [one-liner]
- 3 domain specs: api, frontend, storage
- CLAUDE.md with build conventions

Key decisions:
- Tech stack: TypeScript, React, PostgreSQL
- Deployment: Fly.io
```

### Offer options

Present the user with choices:

- **Proceed to [next phase]** (default)
- **Review [current phase] output** — let the user inspect before moving
- **Revise [current phase]** — re-run with adjustments
- **Skip [next phase]** — only if the next phase is skippable
- **Go back to [phase]** — jump to any prior phase

Example:

```text
Ready to prototype? [Y / review spec / revise / skip / go back to ideation]
```

### Update state

Record phase completion in `.factory/state.json`. Advance
`current_phase` to the next phase.

### Special case: build to retro

After `/build` completes, proceed directly to `/retro`. The retro phase
is mandatory and cannot be skipped — it captures learnings from the build
while they are fresh.

```text
Build complete. Here's what was produced:
- 12 source files across 3 domains
- All 47 tests passing

Moving to retro to capture learnings from the build.
```

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
mandatory and do not allow it.

When a phase is skipped, record the skip in state with the reason:

```json
{
  "status": "skipped",
  "skipped": true,
  "skip_reason": "User chose to skip — spec is clear enough"
}
```

## Backward Navigation

The user can jump backward to any prior phase from any point in the
pipeline. This is how they revisit earlier decisions when later phases
reveal issues.

### Mechanics

When the user selects "Go back to [phase]":

1. **Warn first.** Show exactly what will be affected:

   ```text
   Going back to spec will mark prototype, setup, build, retro, and qa
   as pending. Their output files will be preserved but may need to be
   regenerated. Proceed? [Y/n]
   ```

2. **Set the target phase** to `in_progress`.

3. **Reset all downstream phases** (everything after the target) to
   `pending`. This includes skipped phases.

4. **Append a record** to the `resets` array in state:

   ```json
   {
     "timestamp": "2026-04-03T14:00:00Z",
     "from_phase": "qa",
     "to_phase": "spec",
     "reason": "User wanted to revise the API design"
   }
   ```

5. **Preserve output files** on disk. They are not deleted, but they are
   considered stale and may need to be regenerated as the user works
   through the phases again.

### Constraints

- The user can only jump backward, not forward past incomplete phases.
- Jumping backward always resets everything after the target, even phases
  that were previously skipped.
- If output files from reset phases were manually edited by the user, warn
  that re-running the phase may overwrite those files.

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

1. Present a full summary of what was built.
2. List all artifacts produced across every phase.
3. Confirm deployment status (deployed, or skipped if manual).
4. Suggest next steps:

```text
Your product is deployed.

Next steps:
- Run /ideation to brainstorm new features
- Run /retro for periodic check-ins
- /monitor is coming in v1.1
```

## Help Text

When the user seems confused about what Factory does, where they are in
the pipeline, or what to do next, show this:

```text
Factory guides you from idea to deployed product through these phases:

  /ideation  -> Brainstorm and explore ideas
  /spec      -> Turn idea into buildable specification
  /prototype -> Quick throwaway implementations for feedback
  /setup     -> Project scaffolding, CI/CD, infrastructure
  /build     -> Agent teams construct the product
  /retro     -> Team retrospective — mandatory after build
  /qa        -> Structured quality control
  /security  -> Security audit and hardening
  /deploy    -> Push to production

Coming in v1.1:
  /monitor   -> Health monitoring and bug triage

You can run the full pipeline with /factory, or use any skill
independently.
Current status: [phase] ([X of 9] phases complete)
```

## Error Handling

### Sub-skill fails

Stay on the current phase. Do not advance. Diagnose what went wrong and
either retry the sub-skill or ask the user how to proceed.

### User rejects output

Re-run the phase with the user's feedback incorporated. Do not advance
until the user is satisfied.

### Unexpected state

If the state file is corrupted, references missing files, or is otherwise
inconsistent, present what happened clearly and ask the user how to
proceed. Do not guess or silently fix things.

### Missing output files

If output files referenced in state have been deleted from disk, detect
this and offer to re-run the phase that produced them.

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
