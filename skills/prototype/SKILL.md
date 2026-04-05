---
name: prototype
description: >
  Use when the user wants to "prototype", "quick demo", "try it out",
  "build a quick version", "spike", "proof of concept", or when they want to
  explore implementation alternatives before committing to a full build.
  Supports two independent sub-phases: functional prototypes (architecture,
  interaction model) and visual prototypes (theme, colors, density). User
  picks either, both, or neither.
---

# /prototype

Generate throwaway implementations so the user can experience real
alternatives before committing to a full build. Prototype code is
disposable -- it validates the *approach*, not the *implementation*.

Two independent sub-phases:

- **Functional**: 2-3 architecturally different implementations (e.g., CLI
  vs TUI vs web, monolith vs services). Explores *how it works*.
- **Visual**: 2-3 visual treatments of the chosen functional direction
  using different design token values. Explores *how it looks*.

Either sub-phase can be run independently or skipped entirely.

## Required Inputs

- `SPEC.md` -- the product specification. Must exist before this skill runs.

## Optional Inputs

- `CLAUDE.md` -- project conventions, build commands, preferred tooling.
- `specs/` -- additional domain-specific specs.
- `design-tokens.json` -- design tokens (used by visual sub-phase).

## Outputs

- `prototypes/` -- directory containing each prototype in its own
  subdirectory.
- Updated `SPEC.md` -- prototype decisions recorded directly in the spec.

---

## Process

Follow these steps in order.

### Skill Parameters

Read and execute ALL [MANDATORY] sections in [GLOBAL-REFERENCE.md](GLOBAL-REFERENCE.md):

- `{PHASE_NAME}` = `prototype`
- `{OUTPUT_FILES}` = `["prototypes/"]`

### Step 1: Read Spec

1. Read `SPEC.md` in the project root. If it does not exist, stop and tell
   the user to run `/spec` first.
2. Read any files in `specs/` if that directory exists.
3. Read `CLAUDE.md` if it exists.
4. Read `design-tokens.json` if it exists (needed for visual prototyping).

### Step 2: Choose Sub-Phases

Ask the user:

```text
Which prototype phases do you want to run?
  1. Functional -- explore different architectures/interaction models
  2. Visual -- explore different visual treatments (theme, colors, density)
  3. Both (functional first, then visual)
```

If the user skips both, record the skip in state and exit.

### Step 3: Functional Prototype (if selected)

Determine 2-3 meaningfully different approaches. These must represent
genuinely different tradeoffs, not cosmetic variations:

- Different interaction models (CLI vs. TUI vs. web)
- Different architectural approaches (monolith vs. services)
- Different tech stack choices (when not constrained by the spec)
- Different feature emphasis (depth on A vs. breadth across A+B+C)

If the spec is simple enough that only one approach makes sense, produce
one prototype with an explicit note explaining why.

**"React with Tailwind" vs. "React with vanilla CSS" is NOT a meaningful
alternative.** Alternatives must differ in architecture, interaction model,
or fundamental approach.

For each alternative, create a directory under `prototypes/functional/`:

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

Each prototype MUST:

- Be a single-file or minimal-file implementation.
- Cover the core happy path only -- no error handling, no edge cases, no
  tests.
- **Actually run.** Verify each prototype executes before presenting.
- Include a `README.md` with what it demonstrates, run commands, and what
  is intentionally missing.

Present each prototype to the user. Explain tradeoffs neutrally -- do not
advocate for one option. The user picks a direction.

### Step 4: Visual Prototype (if selected)

Takes the functional winner (or the current spec if functional was skipped)
and produces 2-3 visual treatments by varying design token values.

If `design-tokens.json` does not exist, generate a baseline from the spec's
Visual Identity section and the design tokens schema at
`skills/references/design-tokens-schema.json`.

Create each visual variant under `prototypes/visual/`:

```text
prototypes/
  visual/
    option-a-minimal/
      README.md
      design-tokens.json
      [implementation files]
    option-b-vibrant/
      README.md
      design-tokens.json
      [implementation files]
```

Each visual prototype:

- Uses the same functional skeleton.
- Applies a different set of design tokens (different color palette,
  typography, spacing, density).
- Includes its own `design-tokens.json` showing the token values used.
- Must run and be visually distinguishable.

Present each treatment to the user. The user picks one. Update the project's
`design-tokens.json` to match the chosen treatment.

### Step 5: Record Decision in SPEC.md

Update `SPEC.md` directly with the prototype decisions. Add or update a
`## Prototype Decisions` section:

```markdown
## Prototype Decisions

### Functional Direction
- **Selected**: [Name]
- **Rationale**: [User's words]
- **Alternatives explored**: [Brief list of what was tried and rejected]
- **Implications**: [What this means for architecture and build]

### Visual Direction
- **Selected**: [Name]
- **Design tokens**: See `design-tokens.json`
- **Alternatives explored**: [Brief list]

### Spec Gaps Discovered
- [Gap 1: description and affected spec section]
- (or "None")
```

Do NOT create `PROTOTYPE-DECISION.md`. SPEC.md is the living source of
truth for all product decisions.

### Step 6: Spec Gap Detection

Prototyping often reveals problems in the spec that were invisible on paper.
Check for:

- Interaction patterns that feel wrong when implemented.
- Performance characteristics that change the architectural approach.
- Missing API contracts discovered when wiring things together.
- Visual constraints that conflict with functional requirements.

If gaps are found, document them in the Spec Gaps section above and
recommend re-running `/spec` for affected areas before proceeding to
`/build`.

---

## Settings

```yaml
settings:
  - name: prototype_count
    type: number
    default: 3
    min: 2
    max: 4
    description: >
      Target number of alternatives per sub-phase. Must be at least 2
      unless the spec genuinely admits only one approach.
  - name: auto_run_prototypes
    type: boolean
    default: true
    description: >
      Automatically execute each prototype to verify it runs before
      presenting to the user.
```

## Anti-Patterns

- **Polishing prototypes.** Prototypes are disposable. Adding error
  handling, tests, or input validation defeats the purpose.
- **Skipping the comparison.** Producing one prototype and asking "does
  this look good?" is a demo, not prototyping. Always produce at least
  two unless the spec genuinely admits only one approach.
- **Letting prototype code leak into production.** Prototype code was built
  without tests, error handling, or security considerations. Never copy it
  into production.
- **Presenting broken prototypes.** A prototype that does not run teaches
  nothing. Verify each one before presenting.
- **Advocating for an option.** Present tradeoffs neutrally. The user
  decides.
- **Treating minor variations as alternatives.** Functional alternatives
  must differ in architecture or interaction model. Visual alternatives
  must differ in design tokens -- not just a single color change.
- **Writing PROTOTYPE-DECISION.md.** Decisions go in SPEC.md. Do not
  create a separate decision file.
