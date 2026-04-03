# CLAUDE.md Ownership Transfer -- Build Task

> This is a staged task, not a full domain spec. It describes a bug fix:
> CLAUDE.md generation is misplaced in `/spec` and should be owned by
> `/genesis`.

## Problem

The `/spec` skill currently generates the entire `CLAUDE.md` for target
projects, including process rules (worktree isolation, PR workflow,
post-merge cleanup, gate finality, progress tracking) that are Factory
pipeline concerns, not specification concerns.

This means:

- `/spec` contains a large CLAUDE.md template (~160 lines) that is mostly
  process rules unrelated to specification
- `/genesis` has no way to set up a target project's CLAUDE.md before
  `/spec` runs
- In claim mode, `/genesis` should be able to write process rules to an
  existing project's CLAUDE.md without running `/spec`

## What to Change

### 1. Split the CLAUDE.md template

The current template in `skills/spec/SKILL.md` (lines ~720-877) has two
distinct halves:

**Factory-owned sections (move to `/genesis`):**

- `## Mandatory Process Rules` and all subsections:
  - Lifecycle of a Change (codebase exploration, worktree isolation, change
    implementation loop, pull request, post-merge cleanup)
  - Mandatory Retro After Build
  - Self-Updating Context (CLAUDE.md Auto-Amendment)
  - Progress Tracking
- `## Agent Communication`

**Spec-owned sections (keep in `/spec`):**

- `## Project Summary`
- `## Architecture` (tech stack, components)
- `## Technical Standards`
- `## Quality Standards` (code coverage, test quality, CI health, CI
  pipeline inspection, code review rigor)
- `## Key Features`

### 2. Add CLAUDE.md generation to `/genesis`

In `skills/genesis/SKILL.md`, add a CLAUDE.md generation step that runs:

- **Bootstrap mode**: After `/setup` completes (or before `/spec` if no
  setup is needed). Generates a fresh CLAUDE.md with the process rules
  sections. Uses HTML comment markers for section boundaries.
- **Claim mode**: Reads the existing CLAUDE.md. If Factory process sections
  exist (detected by markers), updates them in place. If not, appends them.

### 3. Modify `/spec` to append, not overwrite

In `skills/spec/SKILL.md`, change the CLAUDE.md generation instructions:

- If CLAUDE.md exists, read it and append/update only the spec-owned
  sections below the Factory sections
- If CLAUDE.md does not exist (standalone `/spec` invocation without
  `/genesis`), generate the full file as today (backward compatibility)
- Use HTML comment markers to delimit spec-owned sections:
  `<!-- spec:start -->` / `<!-- spec:end -->`

### 4. Section markers

```markdown
<!-- factory:process-rules:start -->
## Mandatory Process Rules
...
## Agent Communication
...
<!-- factory:process-rules:end -->

<!-- spec:project:start -->
## Project Summary
...
## Key Features
...
<!-- spec:project:end -->
```

### 5. Respect the `update_project_claude_md` setting

The setting `update_project_claude_md` (enum: prompt/auto/skip) controls
how Factory-owned sections are written and kept in sync. This applies during
`/genesis claim`, bootstrap mode, and the drift-sync check that every skill
runs on entry. `/spec` always writes its sections when it runs.

## Acceptance Criteria

- [ ] `/genesis` generates CLAUDE.md with process rules in bootstrap mode
- [ ] `/genesis claim` updates existing CLAUDE.md with process rules,
      respecting the `update_project_claude_md` setting
- [ ] `/spec` appends project-specific sections without overwriting process
      rules
- [ ] Standalone `/spec` (no prior `/genesis` run) still generates the full
      CLAUDE.md for backward compatibility
- [ ] Section markers are present and correctly delimit owned regions
- [ ] The CLAUDE.md template is removed from `/spec`'s SKILL.md (replaced
      with the append-only version)
