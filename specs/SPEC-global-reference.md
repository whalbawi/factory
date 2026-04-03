# Global Reference System -- Domain Spec

## Overview

The global reference system eliminates instruction duplication across Factory's 10 skill
files by extracting shared conventions into a single `GLOBAL-REFERENCE.md` file in the
`skills/references/` directory. Each skill directory gets a symlink to the canonical file and
references only the sections it needs. Parameterized sections use placeholders that each
skill defines in its own `SKILL.md` before the reference directive.

This is an internal infrastructure change to Factory's skill files. It does not affect
target projects, pipeline state, or end-user behavior. It reduces maintenance burden and
eliminates drift between skills.

---

## Contract

| Field               | Value                                                          |
|---------------------|----------------------------------------------------------------|
| **Required inputs** | Existing skill files with duplicated sections to extract       |
| **Optional inputs** | None                                                           |
| **Outputs**         | `skills/references/GLOBAL-REFERENCE.md` (canonical file)       |
|                     | `skills/{skill}/GLOBAL-REFERENCE.md` (symlinks, one per skill) |
| **Side effects**    | Each SKILL.md is modified to reference the global file instead |
|                     | of inlining shared instructions                                |

---

## Scope

### In scope

1. Extract shared instructions into `skills/references/GLOBAL-REFERENCE.md`
2. Create symlinks in each skill directory pointing to the canonical file
3. Modify each SKILL.md to reference the global file with section selectors
4. Support parameterized placeholders for skill-specific values
5. Update `specs/INDEX.md` with the new spec entry

### Out of scope

- Target project CLAUDE.md generation (separate concern, tracked separately)
- Auto-propagation scripts (symlinks are static; new skills are rare)
- Version stamping (symlinks always resolve to the latest content)
- Multiple reference files (one file with sections is sufficient)

---

## File Layout

After implementation:

```text
skills/
  references/
    GLOBAL-REFERENCE.md          <-- canonical file (the only real copy)
  genesis/
    SKILL.md
    GLOBAL-REFERENCE.md          <-- symlink -> ../references/GLOBAL-REFERENCE.md
  build/
    SKILL.md
    GLOBAL-REFERENCE.md          <-- symlink -> ../references/GLOBAL-REFERENCE.md
  deploy/
    SKILL.md
    GLOBAL-REFERENCE.md          <-- symlink
  ideation/
    SKILL.md
    GLOBAL-REFERENCE.md          <-- symlink
  prototype/
    SKILL.md
    GLOBAL-REFERENCE.md          <-- symlink
  qa/
    SKILL.md
    GLOBAL-REFERENCE.md          <-- symlink
  retro/
    SKILL.md
    GLOBAL-REFERENCE.md          <-- symlink
  security/
    SKILL.md
    GLOBAL-REFERENCE.md          <-- symlink
  setup/
    SKILL.md
    GLOBAL-REFERENCE.md          <-- symlink
  spec/
    SKILL.md
    GLOBAL-REFERENCE.md          <-- symlink
```

---

## GLOBAL-REFERENCE.md Structure

The file is organized into named sections. Each section is self-contained and
independently referenceable. Sections that vary per skill use `{PLACEHOLDER}`
placeholders.

Sections marked `[MANDATORY]` apply to every skill unconditionally -- skills do
not need to opt into them. All other sections are opt-in: a skill follows them
only when its `SKILL.md` explicitly references them.

### Sections

#### 1. Settings Protocol [MANDATORY]

Identical across all 10 skills. No placeholders.

```markdown
## Settings Protocol

Before starting, read `.factory/settings.json` and resolve this skill's
settings against the declared schema in the `## Settings` section of this
skill file. Use stored values where present, defaults where not, and prompt
for any setting with no default and no stored value.
```

#### 2. State Tracking [MANDATORY]

Present in 9 skills (all except `/genesis` orchestrator, which manages state
differently -- it coordinates phases rather than reporting its own phase). Uses
placeholders:
`{PHASE_NAME}` and `{OUTPUT_FILES}`.

```markdown
## State Tracking

Update `.factory/state.json` on invocation and completion. If no state file
or `.factory/` directory exists, create them. Read the existing file, merge
the `{PHASE_NAME}` phase state, and write back. Do not overwrite other
phases' state.

**On start** -- set the `{PHASE_NAME}` phase to `in_progress`:

\```json
{
  "phases": {
    "{PHASE_NAME}": {
      "status": "in_progress",
      "started_at": "<ISO-8601 timestamp>"
    }
  }
}
\```

**On completion** -- set the `{PHASE_NAME}` phase to `completed`:

\```json
{
  "phases": {
    "{PHASE_NAME}": {
      "status": "completed",
      "started_at": "<original start time>",
      "completed_at": "<ISO-8601 timestamp>",
      "outputs": {OUTPUT_FILES}
    }
  }
}
\```

**On failure** -- set the `{PHASE_NAME}` phase to `failed`:

\```json
{
  "phases": {
    "{PHASE_NAME}": {
      "status": "failed",
      "started_at": "<original start time>",
      "failed_at": "<ISO-8601 timestamp>",
      "failure_reason": "<what went wrong>"
    }
  }
}
\```
```

#### 3. Post-Merge Cleanup

Referenced by skills that manage worktrees and PRs (`/build`, `/spec`
CLAUDE.md template). No placeholders.

```markdown
## Post-Merge Cleanup

After a PR is merged to main, the merging agent MUST clean up immediately:

1. Delete the remote branch: `git push origin --delete <branch-name>`
2. Remove the local worktree: `git worktree remove <worktree-path>`
3. Delete the local branch: `git branch -D <branch-name>`

This prevents stale branches and worktrees from accumulating.
```

#### 4. Gate Verification

Referenced by `/deploy` and `/genesis`. No placeholders.

```markdown
## Gate Verification

Do NOT trust `.factory/state.json` for gate status -- always read the actual
report file. Verify that the `Tested commit` field in the report matches the
current `git rev-parse HEAD`. If it does not match, the report is stale --
halt and inform the user that the gate skill must be re-run.
```

#### 5. Secrets Handling [MANDATORY]

Applies to all skills as a defensive baseline. Primarily relevant to `/deploy`
(verification), `/security` (audit), and `/setup` (provisioning), but all
skills must follow the rule to prevent accidental secret exposure. No
placeholders.

```markdown
## Secrets Handling

Verify secrets exist but never echo or log their values. Use name-only
listing commands (e.g., `fly secrets list`), not value-revealing commands
(e.g., `fly secrets show`). Never include secret values in commit messages,
PR descriptions, logs, or output files.
```

#### 6. CLAUDE.md Drift Sync [MANDATORY]

Runs on every skill invocation after settings resolution. Checks whether
Factory-owned sections of the project's `CLAUDE.md` have drifted from the
canonical template and updates them based on the
`genesis.update_project_claude_md` setting. No placeholders.

```markdown
## CLAUDE.md Drift Sync

After resolving settings but before executing main logic, check whether
the project-level `CLAUDE.md` has drifted from the canonical content that
Factory owns. Factory-owned content is any block delimited by
`<!-- factory:*:start -->` / `<!-- factory:*:end -->` marker pairs.

Detection:
1. Read `CLAUDE.md` in the project root. If it does not exist or contains
   no Factory marker pairs, skip this check.
2. For each marker pair found, extract the content between the start and
   end markers.
3. Compare each extracted block against the corresponding canonical
   template from the `/genesis` skill file. Ignore leading/trailing
   whitespace when comparing.

Update:
If any block has drifted, gate on the `genesis.update_project_claude_md`
setting:
- "prompt" (default): Show a diff summary and ask the user to confirm.
- "auto": Replace stale blocks silently.
- "skip": Do nothing.

Constraints:
- Runs at most once per skill invocation.
- Do not create `CLAUDE.md` if it does not exist.
- Do not modify content outside Factory markers.
```

---

## Placeholder System

### Placeholder Format

Placeholders use single curly braces: `{PLACEHOLDER_NAME}`. Names are
UPPER_SNAKE_CASE.

### Defined Placeholders

| Placeholder      | Type   | Description                                        |
|------------------|--------|----------------------------------------------------|
| `{PHASE_NAME}`   | string | The skill's pipeline phase name (e.g., `qa`)       |
| `{OUTPUT_FILES}` | JSON   | JSON array of output file paths                    |

### How Skills Define Parameters

Each SKILL.md defines placeholder values **immediately before** the reference
directive. This ensures Claude has the values in context when it reads the
referenced section.

Example from `/qa`'s SKILL.md:

```markdown
### Skill Parameters

For the sections referenced in [GLOBAL-REFERENCE.md](GLOBAL-REFERENCE.md):

- `{PHASE_NAME}` = `qa`
- `{OUTPUT_FILES}` = `["QA-REPORT.md"]`

Read and follow the **Settings Protocol** and **State Tracking** sections in
[GLOBAL-REFERENCE.md](GLOBAL-REFERENCE.md).
```

### Placement in SKILL.md

The parameter block and reference directive replace the existing inlined
sections. The reference directive MUST appear where the inlined content
previously was -- not at the top or bottom of the file. This preserves the
logical flow of the skill's instructions.

---

## Reference Directive Format

The reference directive is a markdown paragraph that tells Claude which
sections to read and follow. It uses a markdown link to the symlinked file.

### Full Directive (all sections)

```markdown
Read and follow the **Settings Protocol**, **State Tracking**, and
**Post-Merge Cleanup** sections in
[GLOBAL-REFERENCE.md](GLOBAL-REFERENCE.md).
```

### Selective Directive (subset of sections)

```markdown
Read and follow the **Settings Protocol** and **State Tracking** sections in
[GLOBAL-REFERENCE.md](GLOBAL-REFERENCE.md).
```

### Section Applicability Matrix

Sections marked `[M]` are mandatory and apply to all skills unconditionally.

| Section              | genesis | build | deploy | ideation | prototype | qa  | retro | security | setup | spec |
|----------------------|---------|-------|--------|----------|-----------|-----|-------|----------|-------|------|
| Settings Protocol [M]|    Y    |   Y   |   Y    |    Y     |     Y     |  Y  |   Y   |    Y     |   Y   |  Y   |
| State Tracking [M]   |   (1)   |   Y   |   Y    |    Y     |     Y     |  Y  |   Y   |    Y     |   Y   |  Y   |
| Post-Merge Cleanup   |         |   Y   |        |          |           |     |       |          |       |      |
| Gate Verification    |    Y    |       |   Y    |          |           |     |       |          |       |      |
| Secrets Handling [M] |    Y    |   Y   |   Y    |    Y     |     Y     |  Y  |   Y   |    Y     |   Y   |  Y   |
| Drift Sync [M]       |    Y    |   Y   |   Y    |    Y     |     Y     |  Y  |   Y   |    Y     |   Y   |  Y   |

Notes:

1. `/genesis` does not use the standard State Tracking template because the
   orchestrator manages state differently (it coordinates phases, not reports
   its own phase). Although State Tracking is [MANDATORY], genesis is exempt
   because it has its own state management logic.
2. `/build` is the only skill that directly references Post-Merge Cleanup
   because it orchestrates the worktree-based PR workflow for agent teams.
3. Secrets Handling is [MANDATORY] as a defensive baseline. It is primarily
   relevant to `/deploy` (verification), `/security` (audit), and `/setup`
   (provisioning), but all skills must follow the rule to prevent accidental
   secret exposure.
4. Drift Sync (CLAUDE.md Drift Sync) runs on every skill invocation after
   settings resolution. It is skipped if the project has no `CLAUDE.md` or
   no Factory marker pairs.

---

## Symlink Creation

### Command

From the project root:

```bash
for skill in genesis build deploy ideation prototype qa retro security setup spec; do
  ln -sf ../references/GLOBAL-REFERENCE.md "skills/$skill/GLOBAL-REFERENCE.md"
done
```

The canonical file lives in `skills/references/GLOBAL-REFERENCE.md`. Every
skill directory (including `/genesis`) gets a symlink pointing to it.

### Git Behavior

Git stores symlinks as text files containing the relative target path. This
works across clones on macOS and Linux. On Windows, git may check out
symlinks as regular files containing the path text -- this is acceptable
since Factory targets macOS/Linux environments (Claude Code runtime).

---

## Migration: Removing Inlined Content

For each skill, the builder MUST:

1. Identify the existing inlined sections that correspond to global reference
   sections (settings protocol block, state tracking JSON blocks, etc.)
2. Replace them with the parameter block and reference directive
3. Preserve any skill-specific additions that extend the shared pattern

### Skill-Specific Extensions

Some skills add fields to the shared state tracking pattern. These
extensions stay in the SKILL.md, below the reference directive.

Examples of skill-specific state tracking extensions:

- `/deploy` adds `target_environment` to the on-start state
- `/prototype` adds prototype metadata to the on-completion state
- `/qa` includes `outputs` in the on-failure state (partial report)

Format for extensions:

```markdown
Read and follow the **State Tracking** section in
[GLOBAL-REFERENCE.md](GLOBAL-REFERENCE.md).

**Additional state fields for this skill:**

On start, also include:
- `"target_environment": "<alpha|staging|prod>"`

On failure, also include:
- `"outputs": ["QA-REPORT.md"]` (partial report is still produced)
```

---

## Scenarios

### Scenario 1: Adding a New Shared Convention

1. Developer edits `skills/references/GLOBAL-REFERENCE.md`, adds a new section
   `## Output File Naming`
2. Developer updates the Section Applicability Matrix in this spec
3. For each skill that should follow the new section, developer adds it to
   the reference directive in that skill's SKILL.md
4. Next time any updated skill runs, Claude reads the symlinked file and
   follows the new section

### Scenario 2: Modifying an Existing Convention

1. Developer edits the `## Post-Merge Cleanup` section in
   `skills/references/GLOBAL-REFERENCE.md` (e.g., adds step 4: "Prune remote
   tracking branches")
2. No changes needed in any SKILL.md -- all symlinks resolve to the updated
   content automatically

### Scenario 3: Adding a New Skill

1. Developer creates `skills/newskill/SKILL.md`
2. Developer creates the symlink:
   `ln -sf ../references/GLOBAL-REFERENCE.md skills/newskill/GLOBAL-REFERENCE.md`
3. Developer adds the parameter block and reference directive to the new
   SKILL.md, selecting the appropriate sections

### Scenario 4: Skill Needs Custom Override

A skill needs behavior that differs from the global reference for a specific
section. The skill does NOT reference that section from the global file.
Instead, it keeps custom instructions inline in its own SKILL.md. The
reference directive simply omits that section name.

---

## Constraints

- Factory targets macOS and Linux. Symlink behavior on Windows is not
  guaranteed but is not a blocking concern.
- The global reference file must not exceed ~300 lines to keep it readable
  and fast for Claude to process.
- Placeholder names must be UPPER_SNAKE_CASE and wrapped in single curly
  braces.
- The global reference file has no YAML frontmatter -- it is a supporting
  file, not a skill file.

---

## Decision Log

| Decision | Rationale | Reversible |
|----------|-----------|------------|
| Single file, not multiple | One file with sections is simpler than a directory of topic files. Sections are small enough that loading the full file is cheap. | Yes |
| Symlinks, not copies | Symlinks ensure a single source of truth. Git tracks them natively. | Yes |
| Placeholders in content, not a template engine | Claude reliably substitutes named values from context. No build step needed. | Yes |
| Extensions stay in SKILL.md | Skill-specific state fields are too varied to parameterize. Keeping them local is clearer. | Yes |
| Neutral `references/` directory for canonical file | The canonical file lives in `skills/references/`, decoupled from any skill. All skill directories (including `/genesis`) symlink to it. | Yes |

---

## Open Questions

None. The design is fully resolved from the ideation deep-dive.
