# Core Skills — Domain Spec

## Overview

This domain owns all individual pipeline skills: `/ideation`, `/prototype`, `/setup`,
`/build`, `/qa`, `/security`, and `/deploy`. Each skill is a self-contained Claude Code
skill file (markdown with YAML frontmatter). The existing `/spec` skill is the reference
implementation and is NOT part of this domain — it is already built and must not be
modified. Two additional skills — `/monitor` and `/retro` — are defined but deferred to
v1.1.

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

**Deferred to v1.1**:

- `/monitor` — collect metrics, analyze, report
- `/retro` — synthesis and discussion

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
| `/monitor` (v1.1) | Deployed application | Telemetry config, `DEPLOY-RECEIPT.md` | `MONITOR-REPORT.md` | `MONITOR-REPORT.md` with connectivity issues |
| `/retro` (v1.1) | At least one completed phase | `PROGRESS.md`, all output files | `RETRO-{date}.md` | Retro summary with gaps noted |

---

## Skill Specifications

### `/ideation`

**Purpose**: Divergent brainstorming that produces structured, actionable feature ideas.

**Trigger patterns**: "brainstorm", "new feature", "what should I build next", "ideate",
"feature ideas", "explore ideas"

**Process**:

1. **Context gathering** — Read existing codebase (if any), existing spec, existing
   ideation docs. Understand the current product and its users.

2. **Problem space exploration** — Ask the user about:

   - Biggest friction points for users
   - Requests they've received
   - Competitive gaps
   - Technical debt that's blocking progress
   - Adjacent problems the product could solve

3. **Idea generation** — Generate 5-8 feature ideas. For each:

   - One-line description
   - Problem it solves
   - Effort estimate (S/M/L)
   - Impact estimate (S/M/L)
   - Technical feasibility notes
   - Dependencies on existing features

4. **Prioritization** — Present an effort/impact matrix. Help user select 1-3 ideas to
   pursue.

5. **Deep dive** — For selected ideas, flesh out:

   - User stories (concrete scenarios, not Agile boilerplate)
   - Technical approach sketch
   - Risks and unknowns
   - Relationship to existing features

6. **Output** — Write `IDEATION.md`:

   ```markdown
   # Ideation: [Product Name] — [Date]

   ## Context
   [Current product state, what prompted ideation]

   ## Ideas Explored
   ### [Idea Name]
   - **Description**: ...
   - **Problem**: ...
   - **Effort**: S/M/L
   - **Impact**: S/M/L
   - **Feasibility**: ...
   [Repeat for each idea]

   ## Selected for Development
   ### [Selected Idea]
   - **Scenarios**: ...
   - **Technical approach**: ...
   - **Risks**: ...
   - **Next step**: Feed into `/spec`

   ## Parked Ideas
   [Ideas not selected, preserved for future]
   ```

**Mindset**: Be generative, not critical. This is the one phase where wild ideas are
welcome. Critique comes later during `/spec`. But don't confuse generative with
unstructured — every idea must have a concrete problem it solves.

---

### `/prototype`

**Purpose**: Quick throwaway implementations for early feedback before committing to
full build.

**Trigger patterns**: "prototype", "quick demo", "try it out", "build a quick version",
"spike", "proof of concept"

**Process**:

1. **Read spec** — Understand core functionality, constraints, and user preferences
   from `SPEC.md`.

2. **Identify alternatives** — Determine 2-3 meaningfully different approaches. These
   are NOT minor variations — they should represent genuinely different tradeoffs:

   - Different interaction models (CLI vs. TUI vs. web)
   - Different architectural approaches (monolith vs. services)
   - Different tech stack choices (if not constrained)
   - Different feature emphasis (depth on feature A vs. breadth across A+B+C)

3. **Build prototypes** — For each alternative:

   - Single-file or minimal-file implementation
   - Core happy path only — no error handling, no edge cases, no tests
   - Must actually run. Broken prototypes are useless.
   - Include a `README` in each prototype directory with: what it demonstrates, how to
     run it, what's intentionally missing

4. **Present and compare** — Show each prototype to the user. For each:

   - What it demonstrates well
   - What it sacrifices
   - Tradeoffs vs. alternatives

5. **Collect decision** — User picks a direction. Record in `PROTOTYPE-DECISION.md`:

   ```markdown
   # Prototype Decision

   ## Alternatives Explored
   1. [Name]: [One-line summary]
   2. [Name]: [One-line summary]
   3. [Name]: [One-line summary]

   ## Decision
   Selected: [Name]
   Rationale: [Why the user chose this]

   ## Implications for Build
   - [What this choice means for architecture]
   - [What this choice means for tech stack]
   - [Features or patterns to carry forward from the prototype]

   ## What to Discard
   Prototype code is throwaway. Do not copy-paste into production.
   The prototype validates the *approach*, not the *implementation*.
   ```

6. **Spec gap detection** — If prototyping reveals gaps in the spec, document them and
   recommend re-running `/spec` for the affected areas before proceeding.

**Anti-patterns**:

- Don't polish prototypes. They are disposable.
- Don't skip the comparison. The value is in weighing alternatives.
- Don't let prototype code leak into production. It was built without tests, error
  handling, or security.

---

### `/setup`

**Purpose**: Project scaffolding, CI/CD, deployment infrastructure, telemetry. Runs
BEFORE build so the foundation is solid.

**Trigger patterns**: "set up the project", "scaffold", "create project", "set up CI",
"configure deployment", "project setup"

**Process**:

1. **Read inputs** — Parse `SPEC.md`, `CLAUDE.md`, and `PROTOTYPE-DECISION.md`
   (if exists) for tech stack, project structure, deployment target.

2. **Project scaffold** — Create directory structure based on tech stack:

   - Source directories matching domain decomposition
   - Test directories mirroring source structure
   - Configuration files (linter, formatter, type checker)
   - `package.json` / `Cargo.toml` / `pyproject.toml` / etc. with correct dependencies
   - `.gitignore` appropriate to the stack
   - `.env.example` with all required environment variables (no secrets)

3. **CI/CD pipeline** — GitHub Actions workflow:

   ```yaml
   # .github/workflows/ci.yml
   - Trigger: push to main, PRs
   - Steps: install deps, lint, type-check, test, build
   - Coverage reporting
   - Artifact upload
   ```

   ```yaml
   # .github/workflows/deploy.yml
   - Trigger: push to main (after CI passes)
   - Steps: build, deploy to Fly.io
   - Health check verification
   ```

4. **Deployment infrastructure** (Fly.io bias):

   - `fly.toml` with app name, region, scaling config
   - `Dockerfile` (multi-stage build)
   - Health check endpoint in the application scaffold
   - Secrets management via `fly secrets`

5. **Telemetry scaffold** (OpenTelemetry bias):

   - OTel SDK initialization in the application entry point
   - Trace context propagation setup
   - Metric collection for key operations
   - Structured logging configuration
   - Export configuration (stdout for dev, collector for prod)

6. **Update CLAUDE.md** — Append concrete commands:

   - Build, test, lint, format, type-check commands
   - Deployment commands
   - Environment setup instructions
   - Telemetry verification commands

7. **Verify** — Run the scaffold:

   - Dependencies install successfully
   - Linter passes on generated code
   - Tests pass (initial skeleton tests)
   - Build produces an artifact
   - Docker builds successfully (if applicable)

**Stack-specific patterns**: The setup skill must handle at minimum:

- Node.js/TypeScript (npm/pnpm, ESLint, Prettier, Vitest/Jest)
- Python (uv/pip, ruff, pytest)
- Rust (cargo, clippy, rustfmt)
- Go (go modules, golangci-lint, go test)

For other stacks, the skill adapts based on spec constraints.

---

### `/build`

**Purpose**: Main construction phase with agent teams working in git worktrees.

**Trigger patterns**: "build it", "start building", "implement", "construct",
"let's build"

**Process**:

1. **Task decomposition** — Architect reads `SPEC.md`, `specs/`, and `CLAUDE.md`.
   Produces a task breakdown:

   - Each task maps to a domain spec item
   - Tasks are sized for a single PR
   - Dependencies between tasks are explicit
   - Priority matches the spec's priority ordering

2. **Agent assignment** — Architect assigns tasks to specialist agents based on:

   - Domain ownership
   - Agent role match (Backend for API, Frontend for UI, etc.)
   - Dependency ordering (agents working on foundational tasks start first)

3. **Parallel execution** — Agents work simultaneously in git worktrees:

   - Each agent creates a worktree: `{project}-wt-{agent-prefix}-{task}`
   - Branch naming: `feat/{task-description}` or `bug/{fix-description}`
   - Small, incremental commits following CLAUDE.md conventions
   - Tests must pass before committing
   - Lint and format must pass before committing

4. **PR workflow** — When an agent completes a task:

   - Squash commits on the branch
   - Rebase on main
   - Create PR via `gh pr create`
   - Monitor CI. If CI fails, fix and re-push.
   - Notify Architect that PR is ready

5. **Architect coordination** — The Architect:

   - Merges PRs in dependency order (rebase+merge strategy)
   - Resolves merge conflicts
   - Updates CLAUDE.md with new learnings
   - Updates `PROGRESS.md` with task status
   - Notifies agents to rebase when main advances

6. **Progress tracking** — Per CLAUDE.md conventions:

   - Each agent maintains `PROGRESS-{PREFIX}.md`
   - Architect maintains `PROGRESS.md` (rolled up)
   - Format: Task ID, Description, Difficulty, Acceptance Criteria, Status, Notes

**Agent team for `/build`**:

- Software Architect (orchestrator) — PREFIX: ARC
- Backend — PREFIX: BE
- Frontend — PREFIX: FE
- DevOps — PREFIX: OPS
- Security — PREFIX: SEC
- QA — PREFIX: QA
- Product Design — PREFIX: PD
- Tech Writing — PREFIX: TW

Not all agents are active for every project. The Architect assigns based on the
project's domain decomposition and agent assignment matrix from the spec.

**Communication**: Agents use SendMessage for direct coordination. Status updates route
through the Architect. Agents must not wait for the Architect to relay technical
questions — DM the relevant agent directly.

---

### `/qa`

**Purpose**: Structured quality control that goes beyond "tests pass."

**Trigger patterns**: "run QA", "quality check", "test everything", "acceptance testing",
"QA pass"

**Process**:

1. **Coverage analysis** — Run test suite with coverage instrumentation:

   - Measure line, branch, and function coverage per domain
   - Identify untested code paths
   - Compare against 100% target from CLAUDE.md

2. **Test quality audit** — Review existing tests for:

   - Meaningful assertions (not just "it doesn't throw")
   - Edge case coverage (null inputs, empty collections, boundary values,
     concurrent access)
   - Error path testing (not just happy path)
   - Integration test isolation (proper stubs, no test interdependency)
   - Mutation testing if tooling supports it — do tests actually catch bugs?

3. **Acceptance criteria verification** — For each acceptance criterion in the spec:

   - Map to specific test(s) that verify it
   - Run those tests and confirm pass
   - For criteria without tests, write them
   - Document any criteria that can't be automatically tested (manual verification
     needed)

4. **Edge case hunting** — Systematically probe:

   - All input validation boundaries
   - Concurrent operations (race conditions, deadlocks)
   - Resource exhaustion (memory, disk, network timeouts)
   - State transitions (invalid transitions, interrupted operations)
   - External dependency failures (API down, malformed response, timeout)

5. **Regression check** — Verify that all previously passing functionality still works
   after the build phase.

6. **Output** — Write `QA-REPORT.md`:

   ```markdown
   # QA Report — [Date]

   ## Summary
   - **Overall status**: PASS / FAIL / PASS WITH WARNINGS
   - **Coverage**: X% line, Y% branch, Z% function
   - **Acceptance criteria**: N/M passing

   ## Coverage by Domain
   | Domain | Lines | Branches | Functions | Gaps |
   |--------|-------|----------|-----------|------|

   ## Acceptance Criteria
   | Criterion | Test(s) | Status | Notes |
   |-----------|---------|--------|-------|

   ## Issues Found
   ### Critical
   ### Major
   ### Minor

   ## Test Quality Assessment
   [Findings from the test quality audit]

   ## Recommendations
   [What to fix before deploying]
   ```

---

### `/security`

**Purpose**: Security audit, threat modeling, and hardening.

**Trigger patterns**: "security audit", "security check", "threat model",
"security review", "harden"

**Process**:

1. **Dependency audit** — Run stack-appropriate tools:

   - `npm audit` / `pip-audit` / `cargo audit` / `govulncheck`
   - Flag critical and high severity vulnerabilities
   - Produce remediation steps (version bump, patch, or replacement)

2. **Static analysis** — Scan for common vulnerability patterns:

   - SQL injection, XSS, SSRF, path traversal
   - Hardcoded secrets, API keys, credentials
   - Insecure deserialization
   - Improper error handling that leaks information
   - Use stack-appropriate tools (semgrep, bandit, clippy security lints)

3. **Threat model** — For each domain:

   - Enumerate attack surfaces (inputs, endpoints, file access, network)
   - Identify threats per surface (STRIDE or equivalent)
   - Assess risk (likelihood x impact)
   - Document mitigations (existing and needed)

4. **Auth flow review** — If the product has auth:

   - Verify auth implementation matches spec
   - Check token handling (storage, transmission, expiration, rotation)
   - Verify authorization checks on every protected operation
   - Test permission boundary edge cases

5. **Secrets management review** — Verify:

   - No secrets in code, configs, or git history
   - `.env` files gitignored
   - Secrets accessed via environment variables or secret management service
   - Rotation strategy documented

6. **Output** — Write `SECURITY.md`:

   ```markdown
   # Security Report — [Date]

   ## Summary
   - **Overall status**: CLEAR / WARNINGS / BLOCKED
   - **Critical findings**: N
   - **High findings**: N

   ## Dependency Audit
   | Package | Vulnerability | Severity | Remediation |
   |---------|--------------|----------|-------------|

   ## Static Analysis Findings
   | File | Line | Issue | Severity | Fix |
   |------|------|-------|----------|-----|

   ## Threat Model
   ### [Domain]
   | Surface | Threat | Risk | Mitigation | Status |
   |---------|--------|------|------------|--------|

   ## Auth Review
   [Findings]

   ## Secrets Management
   [Findings]

   ## Deployment Blockers
   [Critical/high findings that must be fixed before deploy]

   ## Recommendations
   [Non-blocking improvements]
   ```

**Gate behavior**: If any CRITICAL finding exists, `/security` outputs
`status: BLOCKED` and the orchestrator must not advance to `/deploy`.

---

### `/deploy`

**Purpose**: Push to production with verification.

**Trigger patterns**: "deploy", "ship it", "push to production", "go live", "release"

**Process**:

1. **Gate verification** — Check that prerequisites are met:

   - `QA-REPORT.md` exists with status PASS or PASS WITH WARNINGS
   - `SECURITY.md` exists with status CLEAR or WARNINGS (not BLOCKED)
   - All CI checks passing on main branch
   - No unmerged PRs that are blocking

2. **Pre-deploy checklist**:

   - Environment variables set in production
   - Secrets configured (via `fly secrets` or equivalent)
   - Database migrations ready (if applicable)
   - Rollback plan documented

3. **Deploy** (Fly.io default):

   - `fly deploy` from the project root
   - Monitor deployment progress
   - Wait for health checks to pass
   - Verify the application is accessible

4. **Post-deploy verification**:

   - Hit health check endpoint
   - Run smoke tests (subset of acceptance tests against production)
   - Verify telemetry is flowing
   - Check error rates are normal

5. **Output** — Write `DEPLOY-RECEIPT.md`:

   ```markdown
   # Deployment Receipt — [Date]

   ## Deployment
   - **Status**: SUCCESS / FAILED / ROLLED BACK
   - **Version**: [git commit hash]
   - **Environment**: production
   - **Platform**: Fly.io
   - **Region**: [region]
   - **Timestamp**: [ISO 8601]

   ## Health Checks
   | Check | Status | Response Time |
   |-------|--------|---------------|

   ## Smoke Tests
   | Test | Status | Notes |
   |------|--------|-------|

   ## Rollback
   - **Previous version**: [commit hash]
   - **Rollback command**: `fly releases rollback`
   ```

**Rollback**: If health checks fail post-deploy, automatically rollback and report. Do
not leave a broken deployment live.

---

## Deferred to v1.1

The following skills are planned for v1.1 and are not included in the initial release.

### `/monitor`

**Purpose**: Ongoing application health monitoring and bug triage.

**Trigger patterns**: "check status", "how's it running", "any errors", "monitor",
"check health", "triage bugs"

**Process**:

1. **Collect metrics** — From available sources:

   - Fly.io metrics (`fly status`, `fly logs`)
   - Application telemetry (OpenTelemetry data)
   - Error tracking (if configured)
   - Uptime/health checks

2. **Analyze** — Look for:

   - Error rate spikes
   - Latency degradation (p50, p95, p99)
   - Resource exhaustion (memory, CPU, disk)
   - Unusual traffic patterns
   - Recurring errors

3. **Triage** — For each anomaly:

   - Correlate with recent deployments or code changes
   - Identify root cause if possible
   - Classify severity (critical, major, minor)
   - Suggest action (hotfix, rollback, investigate, monitor)

4. **Output** — Write `MONITOR-REPORT.md`:

   ```markdown
   # Monitor Report — [Date]

   ## Overall Health
   - **Status**: HEALTHY / DEGRADED / DOWN
   - **Uptime**: [percentage over period]

   ## Metrics
   | Metric | Current | Baseline | Status |
   |--------|---------|----------|--------|

   ## Errors
   | Error | Count | First Seen | Last Seen | Likely Cause | Action |
   |-------|-------|------------|-----------|-------------|--------|

   ## Recommendations
   [Proactive suggestions]
   ```

---

### `/retro`

**Purpose**: Team retrospective and sync. NOT code review.

**Trigger patterns**: "team sync", "standup", "retrospective", "retro",
"how's the team", "status check", "review progress"

**Process**:

1. **Gather status** — Read all `PROGRESS-{PREFIX}.md` files and `PROGRESS.md`.
   Identify:

   - Completed tasks since last retro
   - In-progress tasks and their status
   - Blocked tasks and blockers
   - Overdue tasks

2. **Surface issues** — Identify:

   - Coordination failures (agents stepping on each other)
   - Scope creep (tasks not in the spec)
   - Quality concerns (patterns of test failures, repeated CI issues)
   - Velocity trends (accelerating, decelerating, steady)

3. **Cross-agent alignment** — Check:

   - Are interface contracts being honored?
   - Are naming conventions consistent?
   - Are there duplicate efforts across agents?
   - Are CLAUDE.md updates happening?

4. **Recommend actions** — Based on findings:

   - Re-prioritize tasks
   - Reassign work
   - Update spec if requirements have evolved
   - Schedule focused fixes for systemic issues

5. **Output** — Write `RETRO-{date}.md`:

   ```markdown
   # Team Retro — [Date]

   ## Progress Since Last Retro
   | Agent | Tasks Completed | Tasks In Progress | Tasks Blocked |
   |-------|----------------|-------------------|---------------|

   ## Issues Surfaced
   ### Blockers
   ### Coordination Issues
   ### Quality Concerns

   ## Recommendations
   [Prioritized actions]

   ## Next Retro
   [When and what to focus on]
   ```

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
