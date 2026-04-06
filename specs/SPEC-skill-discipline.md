# Skill Discipline — Domain Spec

Enforce skill size limits, add CI linting, and restructure oversized skills. Three
changes bundled into one deliverable because they are interdependent: limits without
linting are unenforceable, restructuring without limits has no target.

## Contract

| Field | Value |
|-------|-------|
| **Required inputs** | All `skills/*/SKILL.md` files, `.github/workflows/ci.yml` |
| **Outputs** | Restructured `/spec` and `/genesis`, `scripts/check-skill-size.sh`, updated CI |

---

## Change 1: Skill Size Limits

**Rule**: Every `SKILL.md` must be 500 lines or fewer.

Content that pushes a skill over the limit moves to `skills/{name}/references/` as
separate markdown files. The SKILL.md retains all process logic and decision flow.
Only templates, verbose examples, and agent prompts move.

**Reference pattern**: SKILL.md includes a directive at the exact step where the
content is needed:

```text
Read `references/spec-template.md` now. Use the template structure defined there.
```

Directives appear inline at the step, not in a preamble. This matches the progressive
disclosure pattern already used by `skills/references/GLOBAL-REFERENCE.md`.

**What qualifies as reference material** (moves out):

- Large templates (spec structure, CLAUDE.md sections, process-rules)
- Role-specific agent prompt blocks
- Multi-layer enumeration lists (claim mode deep-read layers)

**What stays in SKILL.md** (never moves out):

- Process flow (phases, steps, transitions)
- Decision logic and branching rules
- Settings, parameters, anti-patterns
- Contract and category sections

---

## Change 2: Skill Linting in CI

### Script: `scripts/check-skill-size.sh`

A bash script that finds all `SKILL.md` files and runs three checks on each.

**Check 1 — Line count**

- Maximum: 500 lines per SKILL.md.
- On failure: `FAIL: skills/{name}/SKILL.md is {N} lines (max 500). Extract to
  references/.`

**Check 2 — Required sections**

Every SKILL.md must contain:

- YAML frontmatter with `name` and `description` fields (already validated by
  `validate-frontmatter.sh`, but duplicated here for standalone use)
- A `## Settings` or `## Skill Parameters` section (one or both)
- An `## Anti-Patterns` section

On failure: `FAIL: skills/{name}/SKILL.md missing required section: {section}`

**Check 3 — No placeholder text**

Scan for patterns that indicate unfinished content:

- `[insert here]`, `[TODO]`, `[TBD]`, `[placeholder]` (case-insensitive)
- `XXX`, `FIXME` outside of code blocks

On failure: `FAIL: skills/{name}/SKILL.md contains placeholder: "{match}" at line {N}`

### CI integration

Add a new job to `.github/workflows/ci.yml`:

```yaml
skill-lint:
  name: Skill Lint
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4

    - name: Check skill size and structure
      run: |
        chmod +x scripts/check-skill-size.sh
        bash scripts/check-skill-size.sh .
```

The script exits 0 if all checks pass, 1 if any fail. All failures are reported
before exiting (do not exit on first failure).

---

## Change 3: Restructure /spec and /genesis

### /spec (currently 1,117 lines)

Three reference files created under `skills/spec/references/`:

**`spec-template.md`** — Master Spec Structure template (lines 325-422).
The markdown template starting from `# [Product Name] -- Specification` through the
closing code fence after `## Open Questions`. Includes the Writing Principles section
that follows it.

SKILL.md retains Phase 2a heading and the instruction "Write the spec to `SPEC.md`".
Insert directive: `Read references/spec-template.md now. Use this structure.`

**`agent-prompts.md`** — Agent base prompt and all role-specific instructions
(lines 577-736). Includes the base prompt template and all seven role blocks
(Backend, Frontend, DevOps, Security, QA, Product Design, Tech Writing).

SKILL.md retains Phase 2c heading and the description of how the Architect launches
agents. Insert directive: `Read references/agent-prompts.md now. Use these prompts
when launching agents.`

**`claude-template.md`** — CLAUDE.md generation templates (lines 829-996). Includes
the spec-owned sections template and the standalone fallback process-rules template.
Also includes the Generation Rules that follow.

SKILL.md retains Phase 2e heading, the description of what the Architect reviews,
and the Normal Flow / Standalone Fallback logic. Insert directive:
`Read references/claude-template.md now. Use these templates for CLAUDE.md generation.`

**Target**: /spec SKILL.md drops from ~1,117 to ~400-450 lines.

### /genesis (currently 1,107 lines)

Two reference files created under `skills/genesis/references/`:

**`process-rules-template.md`** — The full process-rules markdown template
(lines 361-463). Everything between the `### Process Rules Template` heading's code
fence markers, inclusive.

SKILL.md retains the CLAUDE.md Generation section heading and the description of
when and how to write process rules. Insert directive:
`Read references/process-rules-template.md now. Write this content inside the
Factory markers.`

**`claim-layers.md`** — The five deep-read layers for claim mode (lines 573-624).
Layers 1 through 5 with their file lists and extraction instructions.

SKILL.md retains the Claim Mode section, Step 1 heading, and the instruction to
read systematically in five layers. Insert directive:
`Read references/claim-layers.md now. Execute each layer in order.`

**Target**: /genesis SKILL.md drops from ~1,107 to ~450-500 lines.

### Reference file format

Each reference file is plain markdown with no YAML frontmatter. First line is an H1
title describing the content. No skill metadata — these are not standalone skills.

---

## Acceptance Criteria

1. Every `SKILL.md` in the repo is 500 lines or fewer after restructuring.
2. `scripts/check-skill-size.sh` passes on the entire repo with exit code 0.
3. CI `skill-lint` job runs on every PR and catches violations.
4. `/spec` SKILL.md retains complete process flow — no phase logic moved to references.
5. `/genesis` SKILL.md retains complete pipeline sequencing — no transition logic moved.
6. Reference directives appear at the exact step where content is needed, not in a
   preamble or table of contents.
7. Running `/spec` and `/genesis` after restructuring produces identical outputs to
   before (behavioral equivalence).
8. No placeholder text exists in any SKILL.md (check 3 passes).

---

## Decision Log

| # | Decision | Rationale | Reversible |
|---|----------|-----------|------------|
| 1 | 500-line limit, not 300 or 1000 | 500 keeps core process readable in one pass while allowing enough detail. /spec at ~400 and /genesis at ~450 fit comfortably. | Yes |
| 2 | Reference files have no frontmatter | They are not skills. Adding frontmatter would confuse tooling that scans for SKILL.md. | Yes |
| 3 | Duplicate frontmatter check in skill-lint | Allows `check-skill-size.sh` to run standalone without depending on `validate-frontmatter.sh`. CI runs both; redundancy is cheap. | Yes |
| 4 | "Read X now" not "See X for details" | "Read now" is an imperative that Claude follows. "See" is a suggestion that gets skimmed. Matches GLOBAL-REFERENCE pattern. | No |
| 5 | Report all failures before exiting | Developers fix all issues in one pass instead of playing whack-a-mole with one error at a time. | No |
| 6 | Settings/Skill Parameters check accepts either name | Historical inconsistency in section naming. Accept both rather than force a rename across all skills. | Yes |
