# Factory

## Project Summary

Factory is a meta-framework implemented as a pipeline of Claude Code skills that takes
software products from idea to production. It formalizes the ad-hoc process of using Claude
to build software into a repeatable, systematic pipeline: ideation, specification,
prototyping, setup, build, retro, QA, security, deploy, and monitor. Each phase is a
standalone Claude Code skill that can be invoked independently or orchestrated by the
`/genesis` skill.

The "product" is a set of markdown skill files with YAML frontmatter, their contracts
(inputs/outputs), and the conventions they enforce. The existing `/spec` skill at
`~/.claude/skills/spec/SKILL.md` is the reference implementation.

## Architecture

**Tech stack:** Markdown (Claude Code skill files), JSON (pipeline state),
Bash (helper scripts)

**State tracking:** `.factory/state.json` is maintained by every skill, not just the
orchestrator. Each skill reads current state on entry and writes updated state on exit,
ensuring pipeline continuity regardless of how a skill is invoked.

**Components:**

- **`/genesis` orchestrator**: Pipeline sequencing, state management in
  `.factory/state.json`, phase transitions with user confirmation, resumption after
  interruption. Supports both forward progression and backward navigation to revisit
  earlier phases.
- **`/ideation`**: Divergent brainstorming skill. Conversational. Output: `IDEATION.md`.
- **`/spec`**: EXISTING — not modified. Discovery + architect orchestration + agent specs.
  Output: `SPEC.md`, `specs/SPEC-{domain}.md`, `CLAUDE.md`.
- **`/prototype`**: Quick throwaway implementations. 2-3 alternatives presented. Output:
  `prototypes/`, `PROTOTYPE-DECISION.md`.
- **`/setup`**: Project scaffolding, CI/CD (GitHub Actions), deployment (Fly.io bias),
  telemetry (OpenTelemetry). Creates three deployment environments: alpha, staging, and
  prod. Output: project scaffold, infra config.
- **`/build`**: Agent teams in git worktrees. Architect + specialists. PR workflow. CI
  inspection every 5 merges; opt-in alpha deploys for early validation. Output: source
  code, `PROGRESS.md`.
- **`/retro`**: Team retrospective (NOT code review). Reflects on the build phase, captures
  learnings, and feeds improvements forward. Output: `RETRO-{date}.md`.
- **`/qa`**: Test coverage, acceptance criteria, edge case hunting, test quality audit.
  Output: `QA-REPORT.md`.
- **`/security`**: Dependency audit, static analysis, threat model, auth review. Gate
  skill — blocks deploy on critical findings. Output: `SECURITY.md`.
- **`/deploy`**: Gate verification, Fly.io deployment, health checks, rollback.
  Three-environment promotion model: alpha -> staging -> prod. Output:
  `DEPLOY-RECEIPT.md`.
- **`/monitor`** (v1.1): Telemetry review, error triage, health assessment. Output:
  `MONITOR-REPORT.md`.

## Technical Standards

- **Markdown**: Line-wrap at 100 characters. Only use ASCII characters.
- **Skill files**: YAML frontmatter with `name` (string) and `description` (string).
  Markdown body. One `SKILL.md` per skill directory.
- **Output file naming**: UPPERCASE-HYPHENATED.md (e.g., `QA-REPORT.md`,
  `DEPLOY-RECEIPT.md`).
- **State files**: JSON in `.factory/` directory. Human-readable.
- **Skill naming**: Lowercase, no hyphens, no underscores (e.g., `ideation`, `prototype`).

## Quality Standards

Quality is non-negotiable. Every agent MUST uphold these standards at all times.

### Skill Quality

Every skill file must be:

- **Self-contained**: A Claude instance reading the skill for the first time can execute it
  correctly without external context.
- **Concrete**: Examples and output templates use actual names, types, and structures. No
  placeholders like "[insert here]" in the final skill file.
- **Consistent**: Same terminology, conventions, and patterns as the `/spec` reference
  skill.
- **Unambiguous**: Instructions that could be interpreted multiple ways must be clarified
  with examples or explicit "do this, not that" guidance.

### Contract Integrity

Every skill's declared inputs and outputs must be honored:

- If a skill says it produces `QA-REPORT.md`, it must always produce that file.
- If a skill says it requires `SPEC.md`, it must check for it and provide a clear error if
  missing.
- Output file formats must match the templates in the domain specs exactly.

### Test Strategy

Skills are markdown instructions, not executable code. Quality is verified through:

- **Manual invocation testing**: Run each skill in a real project and verify outputs.
- **Contract verification**: Check that each skill's outputs are valid inputs for
  downstream skills.
- **Consistency checking**: Cross-reference terminology, file names, and conventions across
  all skills.
- **Peer review**: Every skill reviewed against the `/spec` reference for pattern
  compliance.

## Key Features

- Full pipeline orchestration from idea to deployed product (`/genesis`):
  `/ideation` -> `/spec` -> `/prototype` -> `/setup` -> `/build` -> `/retro` -> `/qa`
  -> `/security` -> `/deploy`
- Independent skill invocation for any phase
- Pipeline state persistence and resumption
- Agent team model for parallel build execution
- Structured QA with test quality validation (not just coverage)
- Security gate that blocks deployment on critical findings
- Deployment with automatic health checking and rollback
- Telemetry native from day one via OpenTelemetry (v1.1: `/monitor`)

## Mandatory Process Rules

The following rules MUST be followed by each Claude process/agent, for each change being
made. There are no exceptions.

### Lifecycle of a Change

#### Codebase Exploration

Each process/agent MUST read the existing skill files and reference implementation before
making changes. Understand the conventions before modifying them.

#### Worktree Isolation

Each Claude process/agent MUST work in a separate git worktree and associated branch.
Create the worktree as a sibling directory (`factory-wt-<name>`) to the project source
root, and prefix the branch name with `feat/`, `fix/`, or `docs/`.

#### Change Implementation Loop

Implement changes in small incremental commits. Each commit must be self-contained and
must not break any existing skill conventions. Before committing:

- Verify markdown linting passes (if markdownlint is available)
- Verify YAML frontmatter is valid (has `name` and `description`)
- Verify cross-references between skills are correct (file names match)

**Squash before merge**: Each PR MUST be merged as a single commit.

#### Pull Request

Once a branch is ready, rebase on main and create a GitHub PR. Monitor CI. Upon success,
notify the team lead for merge.

**No direct commits to main.** Every change — including renames, config tweaks, and
deployment receipts — must go through a PR. The only exception is the initial repository
setup before CI exists.

#### Gate Finality

Once `/qa` or `/security` has run, no further code changes may land on main without
re-running the affected gate. Gate reports include a `Tested commit` field that `/deploy`
verifies against HEAD. Any commit after a gate run invalidates the report.

### Deployment

Factory is deployed as a tagged release with a GitHub Pages landing page.
The `release.yml` GitHub Actions workflow automates the full flow. The
deployment manifest at `.factory/deploy-config.json` captures the
configuration.

#### Release Flow

Version bump first, tag second. This ensures the tagged commit always has
the correct version in `plugin.json`, the tag is never moved or deleted,
and `marketplace.json` only points to tags that already exist.

The release workflow (`.github/workflows/release.yml`) is triggered via
`workflow_dispatch` with a version and an action. Run the steps in order
with any verification between them:

1. **tag**: Go to Actions > Release > Run workflow. Enter the version
   (e.g., `0.5.0`) and select `tag`. This bumps `plugin.json` via PR,
   merges it, and tags the new HEAD as `vX.Y.Z`. The tagged commit has
   the correct version. The tag is never moved or deleted. The version
   in plugin.json is required for cache invalidation — Claude Code skips
   updates if the version hasn't changed.
2. *(pause)* Run `/qa`, `/security`, or any other verification.
3. **publish**: Run the workflow again with the same version and select
   `publish`. This updates `marketplace.json` ref via PR. This is the
   atomic "go live" moment — users now get the new version. The
   `publish` job requires the `production` environment approval.

Between steps 1 and 3, the tag exists but users still get the previous
version. This is safe — the new version is not discoverable until step 3.

Each action is idempotent — safe to re-run if interrupted. The workflow
checks if the tag/bump/ref already exists before acting.

#### Environments

- **GitHub Pages**: Served from `/docs` on the `main` branch at
  `https://whalbawi.github.io/factory/`.
- **Plugin marketplace**: Users add with `/plugin marketplace add whalbawi/factory`
  and install with `/plugin install factory@factory-marketplace`. Installs are
  pinned to the tagged release specified in `.claude-plugin/marketplace.json`.

#### Deployment Receipts

Every deployment produces a receipt at `deployments/DEPLOY-RECEIPT-{ISO-datetime}.md`.
Receipts are always committed to the repo via PR. They serve as the permanent
audit trail of what was deployed, when, and what gates were verified.

#### Rollback

Run the release workflow with the target version and select `rollback`.
Reverts `marketplace.json` ref to the specified tag via PR. No tag
deletion, no destructive operations. Idempotent. Requires `production`
environment approval.

**Manual fallback**:

- **Plugin**: Update `marketplace.json` ref to the previous tag via PR.
- **Pages**: `gh api repos/whalbawi/factory/pages -X DELETE` (if needed).

### Self-Updating Context (CLAUDE.md Auto-Amendment)

CLAUDE.md MUST be amended whenever a learning or course correction occurs:

- **Autonomous**: When any process/agent discovers a convention, gotcha, or pattern,
  update CLAUDE.md immediately.
- **User-directed**: When the user gives an instruction that changes how Factory works,
  update CLAUDE.md immediately.

### Progress Tracking

Every change MUST be tracked in the relevant `PROGRESS-<prefix>.md` file.

| Agent             | Prefix | Scope                                                                    |
|-------------------|--------|--------------------------------------------------------------------------|
| Skill Architect   | SA     | Skill internal structure, decision logic, agent orchestration,           |
|                   |        | cross-skill consistency                                                  |
| Pipeline Designer | PD     | UX flow, handoff patterns, state machine, information density,           |
|                   |        | phase transitions                                                        |
| Quality Engineer  | QE     | Acceptance criteria, contract verification, input/output consistency     |
| Security Reviewer | SR     | Trust model, security patterns baked into skills, gate behavior          |
| Technical Writer  | TW     | Skill clarity, help text, anti-patterns, naming conventions,             |
|                   |        | documentation                                                            |

## Agent Communication

Agents should DM each other directly (via SendMessage) for technical questions, contract
clarifications, and coordination. Route status updates and task completions through the
team lead.
