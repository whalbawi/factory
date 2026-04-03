---
name: prototype
description: >
  Use when the user wants to "prototype", "quick demo", "try it out",
  "build a quick version", "spike", "proof of concept", or when they want to
  explore implementation alternatives before committing to a full build.
  Generates 2-3 throwaway implementations for early feedback.
---

# /prototype

Generate 2-3 meaningfully different throwaway implementations of a spec'd product so the user
can experience real alternatives before committing to a full build. Prototype code is
disposable — it validates the *approach*, not the *implementation*.

## Required Inputs

- `SPEC.md` — the product specification. Must exist before this skill runs.

## Optional Inputs

- `CLAUDE.md` — project conventions, build commands, preferred tooling.
- `specs/` — additional domain-specific specs.

## Outputs

- `prototypes/` — directory containing each prototype in its own subdirectory.
- `PROTOTYPE-DECISION.md` — recorded decision at the project root.

---

## Process

Follow these six steps in order. Do not skip steps. Do not reorder.

### Step 1: Read Spec

1. Read `SPEC.md` in the project root. If it does not exist, stop and tell the user to run
   `/spec` first.
2. Read any files in `specs/` if that directory exists.
3. Read `CLAUDE.md` if it exists — note project conventions, build commands, and tech stack
   constraints.
4. Update `.factory/state.json` to record that `/prototype` has started (see State Tracking
   below).

### Step 2: Identify Alternatives

Determine 2-3 meaningfully different approaches. These must represent genuinely different
tradeoffs, not cosmetic variations. Examples of meaningful differences:

- Different interaction models (CLI vs. TUI vs. web)
- Different architectural approaches (monolith vs. services)
- Different tech stack choices (when not constrained by the spec)
- Different feature emphasis (depth on feature A vs. breadth across A+B+C)

If the spec is simple enough that only one approach makes sense, produce one prototype with an
explicit note explaining why alternatives were considered but unnecessary.

**"React with Tailwind" vs. "React with vanilla CSS" is NOT a meaningful alternative.**
Alternatives must differ in architecture, interaction model, or fundamental approach — different
enough that the user learns something new from each one.

### Step 3: Build Prototypes

For each alternative, create a directory under `prototypes/`. Name each directory
`option-{letter}-{short-descriptor}`:

```text
prototypes/
  option-a-cli/
    README.md
    main.py
  option-b-tui/
    README.md
    app.py
  option-c-web/
    README.md
    server.py
```

Each prototype MUST:

- Be a single-file or minimal-file implementation.
- Cover the core happy path only — no error handling, no edge cases, no tests.
- **Actually run.** Broken prototypes are useless. Before moving to Step 4, execute each
  prototype and verify it works. If a prototype fails to run, fix it or discard it.
- Include a `README.md` containing:
  - What the prototype demonstrates.
  - Exact commands to run it (install steps, run command, expected output).
  - What is intentionally missing (error handling, tests, edge cases, etc.).

### Step 4: Present and Compare

Show each prototype to the user. For each one, explain:

- What it demonstrates well.
- What it sacrifices.
- Tradeoffs compared to the other alternatives.

**Do not advocate for one option.** Present tradeoffs neutrally and let the user decide. Never
say "I recommend" or "the best option is." State facts and tradeoffs only.

### Step 5: Collect Decision

The user picks a direction. Record their decision in `PROTOTYPE-DECISION.md` at the project
root using the output template below.

When recording the rationale, use the user's own words. Do not paraphrase or editorialize.

### Step 6: Spec Gap Detection

Prototyping often reveals problems in the spec that were invisible on paper. Review what you
learned while building and check for:

- Interaction patterns that feel wrong when implemented.
- Performance characteristics that change the architectural approach.
- Missing API contracts discovered when wiring things together.
- Assumptions about data shape that do not hold.

If gaps are found, document them in the "Spec Gaps Discovered" section of
`PROTOTYPE-DECISION.md` and recommend re-running `/spec` for affected areas before proceeding
to `/setup` or `/build`.

Update `.factory/state.json` to record completion (see State Tracking below).

---

## PROTOTYPE-DECISION.md Template

Write this file at the project root after the user makes their choice:

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

---

## State Tracking

Read and write `.factory/state.json` to track progress. Create the `.factory/` directory and
`state.json` file if they do not exist.

### On Start (Step 1)

If `.factory/state.json` does not exist, create it:

```json
{
  "pipeline": "factory",
  "current_phase": "prototype",
  "phases": {
    "prototype": {
      "status": "in_progress",
      "started_at": "<ISO-8601 timestamp>"
    }
  }
}
```

If it already exists, merge the `prototype` phase into the existing `phases` object and set
`current_phase` to `"prototype"`. Preserve all other phase data.

### On Completion (Step 6)

Update the `prototype` phase:

```json
{
  "phases": {
    "prototype": {
      "status": "completed",
      "started_at": "<original start timestamp>",
      "completed_at": "<ISO-8601 timestamp>",
      "outputs": ["prototypes/", "PROTOTYPE-DECISION.md"]
    }
  }
}
```

### On Failure

If you cannot produce a runnable prototype, set the phase to `failed`:

```json
{
  "phases": {
    "prototype": {
      "status": "failed",
      "started_at": "<original start timestamp>",
      "failed_at": "<ISO-8601 timestamp>",
      "failure_reason": "<what went wrong>"
    }
  }
}
```

Document partial results in each prototype's README if any prototypes were partially built.

---

## Anti-Patterns

**Do not do any of the following.**

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

- **Advocating for an option.** Present tradeoffs neutrally. The user decides. Pushing toward
  a preferred option undermines the purpose of exploring alternatives.

- **Treating minor variations as alternatives.** Alternatives must represent different
  architectural or interaction tradeoffs — different enough that the user learns something
  new from each one.
