# /prototype — Quick Throwaway Implementations for Early Feedback

The `/prototype` skill generates 2-3 meaningfully different throwaway implementations of a
spec'd product so the user can experience real alternatives before committing to a full build.
Prototype code is disposable — it validates the *approach*, not the *implementation*.

## Contract

| Aspect | Details |
|--------|---------|
| **Required inputs** | `SPEC.md` |
| **Optional inputs** | `CLAUDE.md`, `specs/` |
| **Outputs** | `prototypes/` directory, `PROTOTYPE-DECISION.md` |
| **Failure mode** | Partial prototypes with issues documented in each prototype's README |

## Category

Procedural skill — executes a defined sequence of steps with user decision points. No
sub-agents are spawned. The skill runs as a single Claude Code session.

## Process

### Step 1: Read Spec

Read `SPEC.md` and any domain specs in `specs/` to understand core functionality, constraints,
user preferences, and tech stack decisions. If `CLAUDE.md` exists, read it for project
conventions and build commands.

Update `.factory/state.json` to record that `/prototype` has started (see State Tracking
below).

### Step 2: Identify Alternatives

Determine 2-3 meaningfully different approaches. These are NOT minor variations — they must
represent genuinely different tradeoffs:

- Different interaction models (CLI vs. TUI vs. web)
- Different architectural approaches (monolith vs. services)
- Different tech stack choices (if not constrained by spec)
- Different feature emphasis (depth on feature A vs. breadth across A+B+C)

If the spec is simple enough that only one approach makes sense, produce one prototype with an
explicit note that alternatives were considered but unnecessary.

### Step 3: Build Prototypes

For each alternative, create a directory under `prototypes/`:

```
prototypes/
  option-a-cli/
    README.md
    main.py         # (or whatever the implementation file is)
  option-b-tui/
    README.md
    app.py
  option-c-web/
    README.md
    server.py
```

Each prototype must:

- Be a single-file or minimal-file implementation
- Cover the core happy path only — no error handling, no edge cases, no tests
- Actually run. Broken prototypes are useless. Verify execution before presenting.
- Include a `README.md` with: what it demonstrates, how to run it, what is intentionally
  missing

### Step 4: Present and Compare

Show each prototype to the user. For each, explain:

- What it demonstrates well
- What it sacrifices
- Tradeoffs vs. the other alternatives

Do not advocate for one option. Present the tradeoffs neutrally and let the user decide.

### Step 5: Collect Decision

The user picks a direction. Record the decision in `PROTOTYPE-DECISION.md` at the project
root (see Output Template below).

### Step 6: Spec Gap Detection

If prototyping reveals gaps, ambiguities, or contradictions in the spec, document them
explicitly. Recommend re-running `/spec` for the affected areas before proceeding to `/setup`
or `/build`.

Common spec gaps surfaced by prototyping:

- Interaction patterns that feel wrong when implemented
- Performance characteristics that change the architectural approach
- Missing API contracts discovered when wiring things together
- Assumptions about data shape that do not hold

Update `.factory/state.json` to record completion (see State Tracking below).

## State Tracking

Every skill must update `.factory/state.json` on invocation and completion, even when run
standalone (outside the `/factory` orchestrator). Create the `.factory/` directory and
`state.json` file if they do not exist.

### On Start

Set the `prototype` phase to `in_progress` with a `started_at` timestamp:

```json
{
  "phases": {
    "prototype": {
      "status": "in_progress",
      "started_at": "2026-04-03T12:00:00Z"
    }
  }
}
```

If `.factory/state.json` does not exist, create it:

```json
{
  "pipeline": "factory",
  "current_phase": "prototype",
  "phases": {
    "prototype": {
      "status": "in_progress",
      "started_at": "2026-04-03T12:00:00Z"
    }
  }
}
```

### On Completion

Set the phase to `completed` with `completed_at` and `outputs`:

```json
{
  "phases": {
    "prototype": {
      "status": "completed",
      "started_at": "2026-04-03T12:00:00Z",
      "completed_at": "2026-04-03T12:45:00Z",
      "outputs": ["prototypes/", "PROTOTYPE-DECISION.md"]
    }
  }
}
```

### On Failure

Set the phase to `failed` with `failed_at` and `failure_reason`:

```json
{
  "phases": {
    "prototype": {
      "status": "failed",
      "started_at": "2026-04-03T12:00:00Z",
      "failed_at": "2026-04-03T12:30:00Z",
      "failure_reason": "Could not produce a runnable prototype — dependency X unavailable"
    }
  }
}
```

## Output Template

`PROTOTYPE-DECISION.md` at the project root:

```markdown
# Prototype Decision

## Alternatives Explored

1. [Name]: [One-line summary of approach and key tradeoff]
2. [Name]: [One-line summary of approach and key tradeoff]
3. [Name]: [One-line summary of approach and key tradeoff]

## Decision

Selected: [Name]
Rationale: [Why the user chose this — in their words, not paraphrased]

## Implications for Build

- [What this choice means for architecture]
- [What this choice means for tech stack]
- [Features or patterns to carry forward from the prototype]

## Spec Gaps Discovered

- [Gap 1: description and affected spec section]
- [Gap 2: description and affected spec section]
- (or "None" if prototyping confirmed the spec is complete)

## What to Discard

Prototype code is throwaway. Do not copy-paste into production.
The prototype validates the *approach*, not the *implementation*.
```

## Anti-Patterns

- **Polishing prototypes.** Prototypes are disposable. Adding error handling, tests, input
  validation, or documentation beyond the README defeats the purpose. The moment you start
  polishing, you are building — not prototyping.

- **Skipping the comparison.** The value of `/prototype` is in weighing alternatives against
  each other. Producing one prototype and asking "does this look good?" is not prototyping —
  it is a demo. Always produce at least two unless the spec genuinely admits only one approach.

- **Letting prototype code leak into production.** Prototype code was built without tests,
  error handling, security considerations, or maintainability. It must never be copied into
  the production codebase. The prototype validates the direction; `/build` implements it
  properly.

- **Presenting broken prototypes.** A prototype that does not run teaches nothing. Always
  verify that each prototype executes its happy path before presenting it to the user.

- **Advocating for an option.** The skill presents tradeoffs neutrally. The user decides.
  Pushing toward a preferred option undermines the purpose of exploring alternatives.

- **Treating minor variations as alternatives.** "React with Tailwind" vs. "React with
  vanilla CSS" is not a meaningful alternative. Alternatives must represent different
  architectural or interaction tradeoffs — different enough that the user learns something
  new from each one.
