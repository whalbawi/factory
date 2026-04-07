# /prototype -- Quick Throwaway Implementations for Early Feedback

The `/prototype` skill generates throwaway implementations so the user can experience real
alternatives before committing to a full build. Prototype code is disposable -- it validates
the *approach*, not the *implementation*. Supports two independent sub-phases: functional
prototypes (architecture, interaction model) and visual prototypes (theme, colors, density).

## Contract

| Aspect | Details |
|--------|---------|
| **Required inputs** | `SPEC.md` |
| **Optional inputs** | `CLAUDE.md`, `specs/`, `design-tokens.json` |
| **Outputs** | `prototypes/` directory, updated `SPEC.md` (prototype decisions) |
| **Failure mode** | Partial prototypes with issues documented in each prototype's README |

## Category

Procedural skill -- executes a defined sequence of steps with user decision points. No
sub-agents are spawned. The skill runs as a single Claude Code session.

## Sub-Phases

Two independent sub-phases. The user picks either, both, or neither:

- **Functional**: 2-3 architecturally different implementations (e.g., CLI vs TUI vs web,
  monolith vs services). Explores *how it works*.
- **Visual**: 2-3 visual treatments of the chosen functional direction using different
  design token values. Explores *how it looks*.

## Process

### Step 1: Read Spec

Read `SPEC.md` and any domain specs in `specs/`. Read `CLAUDE.md` if it exists for project
conventions. Read `design-tokens.json` if it exists (needed for visual prototyping).

### Step 2: Choose Sub-Phases

Ask the user which prototype phases to run: functional, visual, or both. If the user
skips both, record the skip in state and exit.

### Step 3: Functional Prototype (if selected)

Determine 2-3 meaningfully different approaches. These must represent genuinely different
tradeoffs, not cosmetic variations:

- Different interaction models (CLI vs. TUI vs. web)
- Different architectural approaches (monolith vs. services)
- Different tech stack choices (when not constrained by the spec)
- Different feature emphasis (depth on A vs. breadth across A+B+C)

If the spec is simple enough that only one approach makes sense, produce one prototype with
an explicit note explaining why.

Prototypes are created under `prototypes/functional/`:

```text
prototypes/
  functional/
    option-a-cli/
      README.md
      main.py
    option-b-tui/
      README.md
      app.py
```

Each prototype must be single-file or minimal-file, cover the core happy path only, actually
run (verified before presenting), and include a `README.md`. Present tradeoffs neutrally.

### Step 4: Visual Prototype (if selected)

Takes the functional winner (or the current spec if functional was skipped) and produces 2-3
visual treatments by varying design token values. If `design-tokens.json` does not exist,
generates a baseline from the spec's Visual Identity section. Each variant lives under
`prototypes/visual/` with its own `design-tokens.json`. The chosen treatment's tokens are
written to the project's `design-tokens.json`.

### Step 5: Record Decision in SPEC.md

Prototype decisions are recorded directly in `SPEC.md` under a `## Prototype Decisions`
section with subsections for Functional Direction, Visual Direction, and Spec Gaps
Discovered. `PROTOTYPE-DECISION.md` is NOT created -- SPEC.md is the living source of
truth for all product decisions.

### Step 6: Spec Gap Detection

Check for interaction patterns that feel wrong when implemented, performance characteristics
that change the architectural approach, missing API contracts, and visual constraints that
conflict with functional requirements. If gaps are found, document them in the Spec Gaps
section and recommend re-running `/spec` for affected areas.

## State Tracking

State tracking is handled via the standard GLOBAL-REFERENCE.md template with
`{PHASE_NAME}` = `prototype` and `{OUTPUT_FILES}` = `["prototypes/"]`.

## Anti-Patterns

- **Polishing prototypes.** Prototypes are disposable. Adding error handling, tests, or
  input validation defeats the purpose.
- **Skipping the comparison.** Producing one prototype and asking "does this look good?" is
  a demo, not prototyping. Always produce at least two unless the spec genuinely admits only
  one approach.
- **Letting prototype code leak into production.** Prototype code was built without tests,
  error handling, or security considerations. Never copy it into production.
- **Presenting broken prototypes.** A prototype that does not run teaches nothing. Verify
  each one before presenting.
- **Advocating for an option.** Present tradeoffs neutrally. The user decides.
- **Treating minor variations as alternatives.** Functional alternatives must differ in
  architecture or interaction model. Visual alternatives must differ in design tokens -- not
  just a single color change.
- **Writing PROTOTYPE-DECISION.md.** Decisions go in SPEC.md. Do not create a separate
  decision file.
