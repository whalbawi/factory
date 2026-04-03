# Core Skills — Domain Spec

## Overview

This domain owns all individual pipeline skills. Each skill is a self-contained Claude Code
skill file (markdown with YAML frontmatter). The existing `/spec` skill is the reference
implementation and is NOT part of this domain — it is already built and must not be modified.

Individual skill specifications live in their own files (linked below). This document covers
the shared structure, classification, contracts, and cross-cutting concerns that apply to all
skills.

## Skill Spec Index

### v1 Skills

| Skill | Spec file |
|-------|-----------|
| `/ideation` | [SPEC-ideation.md](SPEC-ideation.md) |
| `/prototype` | [SPEC-prototype.md](SPEC-prototype.md) |
| `/setup` | [SPEC-setup.md](SPEC-setup.md) |
| `/build` | [SPEC-build.md](SPEC-build.md) |
| `/qa` | [SPEC-qa.md](SPEC-qa.md) |
| `/security` | [SPEC-security.md](SPEC-security.md) |
| `/deploy` | [SPEC-deploy.md](SPEC-deploy.md) |
| `/retro` | [SPEC-retro.md](SPEC-retro.md) |

### v1.1 Deferred Skills

| Skill | Spec file |
|-------|-----------|
| `/monitor` | [SPEC-monitor.md](SPEC-monitor.md) |

---

## Internal Architecture

### Skill File Anatomy

Every skill follows the same structure, derived from the `/spec` reference:

```
---
name: <skill-name>
description: <trigger patterns — when this skill activates>
---

# [Skill Name]: [Purpose Statement]

[Dense description of what this skill does.]

## Agent Team
[Which agents are involved, if any. Not all skills need agents.]

## Process Overview
[Numbered phases the skill walks through.]

## Phase N: [Phase Name]
[Detailed instructions for each phase.]

## Output Files
[What files this skill produces.]

## Anti-Patterns
[What NOT to do.]
```

### Skill Categories

Skills fall into three categories based on their interaction model:

**Conversational skills** (heavy user interaction):

- `/ideation` — divergent exploration with the user

**Agentic skills** (spawn sub-agents for parallel work):

- `/build` — Architect + specialist agents in worktrees (the primary agentic skill)

**Hybrid skills** (procedural with optional agent escalation for multi-domain projects):

- `/qa` — runs procedurally for single-domain projects; for multi-domain projects,
  the QA agent may spawn per-domain sub-agents
- `/security` — runs procedurally for single-domain projects; for multi-domain projects,
  the Security agent may spawn per-domain sub-agents

**Procedural skills** (execute a defined sequence):

- `/prototype` — generate alternatives, present, collect choice
- `/setup` — scaffold, configure, verify
- `/deploy` — verify gates, deploy, health check
- `/retro` — synthesis and discussion (mandatory after `/build`)

**Deferred to v1.1**:

- `/monitor` — collect metrics, analyze, report

### Skill Contracts

Each skill must define:

1. **Required inputs**: Files/state that must exist before the skill can run
2. **Optional inputs**: Files that enhance the skill if present
3. **Outputs**: Files produced on successful completion
4. **Failure mode**: What happens when the skill cannot complete

#### Contract Table

| Skill | Required inputs | Optional inputs | Outputs | Failure output |
|-------|----------------|-----------------|---------|----------------|
| `/ideation` | None | Existing codebase, prior `IDEATION.md` | `IDEATION.md` | Partial `IDEATION.md` with `status: incomplete` |
| `/prototype` | `SPEC.md` | `CLAUDE.md`, `specs/` | `prototypes/`, `PROTOTYPE-DECISION.md` | Partial prototypes with issues documented |
| `/setup` | `SPEC.md`, `CLAUDE.md` | `PROTOTYPE-DECISION.md` | Project scaffold, CI/CD, infra config | Partial scaffold with manual steps documented |
| `/build` | `SPEC.md`, `CLAUDE.md`, `specs/`, project scaffold | `PROTOTYPE-DECISION.md` | Source code, PRs, `PROGRESS.md` | `PROGRESS.md` with incomplete tasks |
| `/qa` | Source code, `SPEC.md` | `specs/`, `CLAUDE.md` | `QA-REPORT.md` | `QA-REPORT.md` with `status: failed` and findings |
| `/security` | Source code, `SPEC.md` | `specs/`, `CLAUDE.md` | `SECURITY.md` | `SECURITY.md` with `status: blocked` and critical findings |
| `/deploy` | Source code (passing gates), infra config | `QA-REPORT.md`, `SECURITY.md` | `DEPLOY-RECEIPT.md` | `DEPLOY-RECEIPT.md` with `status: failed` and diagnostics |
| `/retro` | At least one completed phase | `PROGRESS.md`, all output files | `RETRO-{date}.md` | Retro summary with gaps noted |
| `/monitor` (v1.1) | Deployed application | Telemetry config, `DEPLOY-RECEIPT.md` | `MONITOR-REPORT.md` | `MONITOR-REPORT.md` with connectivity issues |

---

## DevOps Perspective

### Skill Development Workflow

Since skills are markdown files, there is no traditional build pipeline. However,
quality still matters:

- **Linting**: Markdown linting for consistent formatting (markdownlint)
- **Link checking**: Ensure cross-references between skills are valid
- **Frontmatter validation**: Verify YAML frontmatter has required fields (`name`,
  `description`)
- **Contract consistency**: Verify that skill input/output declarations match across
  the pipeline

### Skill Installation

Skills can be installed by:

1. Copying skill files to `~/.claude/skills/{skill-name}/SKILL.md`
2. Or placing them project-locally where Claude Code discovers them

### Versioning

Skills are versioned with the Factory repo. The repo at `/Users/wael/repos/factory` is
the canonical source. Skills are copied to `~/.claude/skills/` for use.

---

## Security Perspective

### Skill Security Considerations

- Skills execute arbitrary Claude instructions. The security boundary is Claude Code's
  sandboxing, not the skill files themselves.
- Skills that invoke `Bash` (e.g., `/setup`, `/deploy`) must not execute user-supplied
  strings without validation.
- `/setup` generates `.env.example` — must never contain real secrets.
- `/deploy` handles secrets via `fly secrets` — must never log secret values.
- `/security` skill itself must be thorough enough to catch issues that other skills
  might introduce.

### Trust Model

- Skills are authored by the Factory maintainer (the user). They are trusted code.
- The products built by Factory are untrusted — that's why `/qa` and `/security`
  phases exist.
- Agent-generated code during `/build` is untrusted until reviewed and merged.

---

## QA Perspective

### Skill Acceptance Criteria

Each skill is considered complete when:

1. **Invocation works**: Trigger patterns in the `description` field correctly activate
   the skill
2. **Inputs validated**: Skill checks for required inputs and provides clear error
   messages if missing
3. **Outputs produced**: All declared output files are created with correct structure
4. **Standalone operation**: Skill works when invoked independently (not only via
   `/factory`)
5. **Pipeline operation**: Skill works when invoked by `/factory` orchestrator with
   prior phase outputs present
6. **Edge cases handled**: Missing optional inputs, empty/malformed prior outputs,
   user rejection of results
7. **Instructions are unambiguous**: Another Claude instance following the skill
   instructions produces consistent results

### Testing Strategy

Skills cannot be unit-tested in the traditional sense (they are instructions for
Claude). Quality assurance is:

- **Manual invocation testing**: Run each skill and verify outputs
- **Contract verification**: Check that each skill's outputs match the next skill's
  required inputs
- **Regression testing**: After modifying a skill, re-run it to verify it still
  produces correct outputs
- **Cross-reference checking**: Ensure skills reference the same file names, formats,
  and conventions

---

## Product Design Perspective

### User Experience of the Pipeline

The pipeline should feel like a guided conversation, not a form to fill out. Key UX
principles:

1. **Progressive disclosure**: Don't overwhelm with the full pipeline upfront. Present
   one phase at a time.
2. **Confidence at handoffs**: At each phase transition, the user should feel confident
   about what just happened and what's coming next. Summaries, not just "moving on."
3. **Escape hatches**: The user can always skip, go back, or bail out. No phase should
   feel like a trap.
4. **Transparency**: When agents are working (during `/build`), surface progress
   regularly. Silent periods breed anxiety.
5. **Respect existing work**: If the user has already done something (has a spec, has
   CI set up), detect it and acknowledge it rather than overwriting.

### Handoff UX Pattern

Every phase transition follows this pattern:

```
1. Skill completes and presents its output
2. Summary of what was produced (2-3 sentences, not a dump)
3. Key decisions or findings highlighted
4. "Ready to proceed to [next phase]?" with option to review, revise, or skip
5. User confirms -> orchestrator advances
```

---

## Tech Writing Perspective

### Skill Documentation Requirements

Each skill file IS its own documentation — the instructions are the docs. This means:

- **Clarity is paramount**: A Claude instance reading the skill for the first time must
  be able to execute it correctly.
- **No jargon without definition**: If a term is used (e.g., "worktree," "gate"), it
  must be defined or linked on first use.
- **Examples over descriptions**: Show the expected output format, don't just
  describe it.
- **Anti-patterns section**: Every skill must document what NOT to do. This prevents
  common misinterpretations.

### User-Facing Documentation

Factory itself needs:

- `README.md` in the repo: What Factory is, how to install, how to use, skill reference
- Each skill's `description` frontmatter serves as the quick-reference help text
- `CHANGELOG.md`: Track skill additions and modifications

### Naming Conventions

- Skill names: lowercase, no hyphens, no underscores (e.g., `ideation`, `spec`,
  `prototype`)
- Output files: UPPERCASE, hyphenated (e.g., `SPEC.md`, `QA-REPORT.md`,
  `DEPLOY-RECEIPT.md`)
- State files: lowercase in `.factory/` directory
- Spec subdirectory: `specs/SPEC-{domain}.md`
