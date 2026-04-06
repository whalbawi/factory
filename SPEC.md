# Factory — Specification

## Overview

- **One-liner**: A pipeline of Claude Code skills that systematically takes software products
  from idea to production.
- **Problem**: Using Claude to build products is ad-hoc — unstructured conversation, no
  prototyping phase, no structured QA, CI/CD and infra set up too late or not at all, no
  formalized agent team workflow. The user has gone from spec to app but through manual
  back-and-forth. Factory formalizes this into a repeatable, systematic pipeline.
- **Target user**: Engineers who use Claude Code. Initially the creator (a power user), but
  designed for adoption by any engineer.
- **Success criteria**:

  - A user can invoke `/genesis` and be guided through every phase from idea to deployed
    product
  - Each sub-skill (`/ideation`, `/spec`, `/prototype`, `/setup`, `/build`, `/retro`, `/qa`,
    `/security`, `/deploy`) is independently invokable and produces well-defined outputs
  - The pipeline has clear handoff points: each skill's output is the next skill's input,
    with no implicit context leakage
  - The existing `/spec` skill works unchanged within the pipeline
  - A user with no prior Factory experience can follow the workflow by reading skill
    instructions alone
  - Every skill updates `.factory/state.json` on invocation and completion, even when
    invoked standalone (not via `/genesis`)

## Scope

### In scope (v1)

1. **`/genesis` orchestrator skill** — Entry point that drives the full pipeline. Presents
   each phase, invokes the corresponding sub-skill, collects output, confirms with user
   before proceeding. Tracks pipeline state so the user can resume if interrupted. Supports
   backward navigation — the user can jump back to any prior phase if a gap or issue is
   discovered later in the pipeline.

   - *Example*: User types `/genesis`. Claude asks "Do you have an existing idea or want to
     brainstorm?" Based on answer, routes to `/ideation` or `/spec`. After spec completes,
     asks "Ready to prototype?" and invokes `/prototype`. Continues through the pipeline.
   - *Backward navigation*: If during `/build` a spec gap is discovered, the user can jump
     back to `/spec`. When jumping backward:
     - All phases after the target phase are reset to `pending` in the state file
     - The user is warned that going back may invalidate work from later phases
     - Outputs from later phases are preserved on disk but marked stale in state
   - *Edge cases*: User wants to skip a phase (e.g., already has a spec) — orchestrator
     must allow entry at any phase. User abandons mid-pipeline — state file records progress
     for later resumption.
   - *Error behavior*: If a sub-skill fails or the user rejects its output, the orchestrator
     loops on that phase rather than advancing.
   - *Claim mode*: `/genesis claim` deeply reads an existing codebase, infers which
     pipeline phases are already satisfied, writes `.factory/state.json` with
     confidence-tagged phase statuses (`completed`, `partial`, `pending`), and proposes a
     `CLAUDE.md` tailored to the project. Claim is the on-ramp for existing projects. It
     does not generate spec-level artifacts — it detects what exists and presents findings
     with confidence levels (high/medium/low). See `specs/SPEC-claim.md` for full details.

2. **`/ideation` skill** — Divergent brainstorming for new features on existing products or
   new product ideas. Structured exploration: problem space mapping, opportunity
   identification, idea generation, feasibility gut-check, prioritization.

   - *Example*: User has a deployed task manager and invokes `/ideation`. Claude explores:
     "What's the biggest friction point your users hit?" Generates 5-8 feature ideas with
     effort/impact assessment. User picks 2 to explore deeper. Output: `IDEATION.md` with
     selected ideas ready to feed into `/spec`.
   - *Edge cases*: No existing product (greenfield) — skill adapts to explore problem spaces
     rather than feature additions.
   - *Error behavior*: If ideation produces nothing the user finds compelling, explicitly
     acknowledge and suggest pivoting the problem framing.

3. **`/prototype` skill** — Quick throwaway implementations for early feedback. Generates 2-3
   alternative approaches (different UI patterns, different architectures, different
   interaction models). User picks a direction before committing to full build.

   - *Example*: Spec calls for a CLI tool. `/prototype` produces: (a) a single-file Python
     script with core functionality, (b) a TUI version with `textual`, (c) a hybrid CLI+web
     dashboard. User tries each, picks (b). Output: user's choice recorded, prototype code
     available as reference (not production code).
   - *Edge cases*: Spec is simple enough that only one approach makes sense — skill produces
     one prototype with explicit note that alternatives were considered but unnecessary.
     Prototype reveals spec gaps — skill flags them for `/spec` revision.
   - *Error behavior*: Prototype fails to run — fix it before presenting. Never present
     broken prototypes.

4. **`/setup` skill** — Project scaffolding, CI/CD pipeline, deployment infrastructure,
   telemetry. Runs BEFORE `/build` so the foundation is solid. Bias toward Fly.io for
   deployment — creates three deployment environments: alpha, staging, prod. Telemetry
   is native from day one.

   - *Example*: For a Node.js/React project, `/setup` produces: project directory structure,
     `package.json` with scripts, GitHub Actions CI pipeline (lint, test, build, deploy),
     `fly.toml` for Fly.io deployment, OpenTelemetry instrumentation scaffold, Dockerfile,
     `.env.example`, and initial `CLAUDE.md` amendments for build/test/deploy commands.
   - *Edge cases*: User wants a different deployment target — skill asks and adapts. Project
     extends an existing repo — skill integrates rather than overwriting. Monorepo vs.
     polyrepo — skill asks and structures accordingly.
   - *Error behavior*: If Fly.io setup fails (auth, region, etc.), skill reports the issue
     with manual steps to resolve and continues with remaining setup.

5. **`/build` skill** — Main construction phase. Agent teams (Architect + specialists)
   working in git worktrees, submitting PRs. Uses the CLAUDE.md conventions for worktree
   isolation, change implementation loop, squash before merge, PR workflow, progress
   tracking.

   - *Example*: Architect reads `SPEC.md` and domain specs, creates task breakdown, assigns
     tasks to specialist agents (Skill Architect, Pipeline Designer, Quality Engineer,
     Security Reviewer, Technical Writer). Each agent creates a worktree, implements their
     tasks in small commits, runs tests, creates PRs. Architect reviews and merges in
     dependency order.
   - *CI hygiene*: Every 5 merged PRs, the DevOps agent inspects the CI pipeline for
     false positives and false negatives, tuning thresholds and test reliability.
   - *Alpha validation*: Agents can optionally deploy to the alpha environment to
     validate their work end-to-end, coordinating via SendMessage so multiple agents
     do not deploy simultaneously.
   - *Edge cases*: Merge conflicts between agents — Architect coordinates resolution.
     Agent's PR fails CI — agent fixes before re-requesting review. Spec ambiguity
     discovered during build — agent flags for Architect decision, Architect updates
     CLAUDE.md.
   - *Error behavior*: Build failure in one domain must not block independent domains.
     Architect tracks blocked vs. unblocked work.

6. **`/retro` skill** — Team retrospective/sync. Agents discuss progress, surface issues,
   course correct. NOT code review.

   - *Example*: `/retro` gathers status from all active agents (via progress files),
     identifies blockers, surfaces coordination issues. Produces a retro summary: what's
     done, what's blocked, what needs attention, proposed re-prioritization. User confirms
     or adjusts.
   - *Edge cases*: No active agents (used outside build phase) — skill adapts to general
     project health review. Single-agent project — skill still runs but focuses on progress
     vs. spec alignment.
   - *Error behavior*: Agent progress files missing or stale — skill flags the gap rather
     than guessing.

7. **`/qa` skill** — Structured quality control. Test coverage enforcement, acceptance
   testing, edge case hunting, test quality validation.

   - *Example*: `/qa` reads the spec's acceptance criteria, runs the full test suite,
     measures coverage, identifies untested paths. Produces a QA report: coverage numbers by
     domain, list of acceptance criteria with pass/fail, edge cases tested, test quality
     assessment (are tests meaningful or just coverage padding?).
   - *Edge cases*: Coverage target unreachable for certain code (generated code,
     platform-specific) — skill documents exclusions with justification. Flaky tests found —
     skill triages and fixes or flags.
   - *Error behavior*: If tests fail, QA skill does not just report — it investigates root
     cause and either fixes or provides a diagnosis.

8. **`/security` skill** — Security audit, threat modeling, hardening. Standalone gate after
   QA.

   - *Example*: `/security` performs: dependency audit (`npm audit`, `cargo audit`, etc.),
     static analysis for common vulnerabilities (SQL injection, XSS, SSRF), secrets
     scanning, auth flow review against spec, OWASP Top 10 checklist. Produces
     `SECURITY.md` with findings, severity ratings, and remediation steps. Critical findings
     block deployment.
   - *Edge cases*: Project has no auth — skill still audits input validation, dependency
     chain, secrets handling. False positives from scanners — skill triages and marks as
     false positive with reasoning.
   - *Error behavior*: Critical vulnerability found — skill attempts automated fix. If fix
     is non-trivial, produces detailed remediation guide and blocks `/deploy`.

9. **`/deploy` skill** — Push to production via a three-environment promotion model:
   alpha (opt-in by agents during `/build` to validate work) -> staging (promoted after
   `/qa` passes) -> prod (promoted after `/security` clears and user confirms). Handles
   deployment process with Fly.io bias.

   - *Example*: `/deploy` verifies all gates passed (QA green, security clear), promotes
     from staging to prod via `fly deploy`, verifies health checks pass, confirms the
     deployment is live. Produces deployment receipt: version, timestamp, environment,
     health check results.
   - *Edge cases*: First deploy vs. subsequent deploys — skill handles initial Fly.io app
     creation. Rollback needed — skill supports `fly releases rollback`. Multi-service
     deployment — skill deploys in dependency order.
   - *Error behavior*: Deploy fails — skill captures logs, diagnoses, suggests fix. Does
     not retry blindly. Health check fails post-deploy — skill initiates rollback
     automatically.

### Cross-Cutting Requirements

- **State tracking from day 1**: Every skill updates `.factory/state.json` on invocation
  (setting `status: "in_progress"` and `started_at`) and on completion (setting
  `status: "completed"` and `completed_at`). This applies even when a skill is invoked
  standalone outside the `/genesis` orchestrator. If `.factory/state.json` does not exist,
  the skill creates it. This ensures pipeline state is always accurate regardless of how
  skills are used.

### Deferred to v1.1

10. **`/monitor` skill** — Dashboard monitoring, telemetry review, bug triage.

    - *Example*: `/monitor` connects to telemetry (OpenTelemetry backend, Fly.io metrics),
      presents a summary: error rates, latency percentiles, resource usage, recent errors
      with stack traces. If anomalies are found, triages and suggests action: "Error rate
      spiked 3x in the last hour. Top error: NullPointerException in
      UserService.getProfile. Likely related to PR #47 merged 2 hours ago."
    - *Edge cases*: No telemetry configured — skill guides setup rather than failing
      silently. Metrics look normal — skill confirms and suggests proactive checks.
    - *Error behavior*: Cannot connect to monitoring — reports connectivity issue with
      troubleshooting steps.

### Out of scope (v1)

- **Persistent state across sessions**: Pipeline state is file-based (`.factory/state.json`
  and markdown files in the repo). No database, no external service for state management.
- **Multi-user coordination**: v1 assumes a single user driving the pipeline. No concurrent
  user support.
- **Custom agent roles**: The agent team is fixed (Skill Architect, Pipeline Designer,
  Quality Engineer, Security Reviewer, Technical Writer). Users cannot define custom
  specialist roles in v1.
- **Plugin/extension system**: Skills are not pluggable in v1. The set is fixed.
- **GUI/dashboard**: All interaction is through Claude Code CLI. No web dashboard for
  pipeline visualization.
- **Billing/cost tracking**: No tracking of Claude API usage or costs across the pipeline.

### Future considerations

- Visual pipeline dashboard showing phase progress
- Custom agent roles defined by users
- Skill marketplace for community-contributed skills
- Multi-user support with role-based access
- Cost estimation before each phase
- Branching pipelines (e.g., parallel QA + security instead of sequential)
- Integration with external project management tools (Linear, Jira)

## Scenarios

**Scenario: Greenfield product, full pipeline**

1. User invokes `/genesis` with no prior context
2. Orchestrator detects greenfield, asks "Do you have an idea or want to brainstorm?"
3. User says "I have an idea for a habit tracker"
4. Orchestrator invokes `/ideation` to explore the idea space — user refines to "CLI habit
   tracker with streaks and analytics"
5. Orchestrator invokes `/spec` — full discovery, architect orchestration, produces SPEC.md,
   domain specs, CLAUDE.md
6. User reviews spec, confirms. Orchestrator invokes `/prototype`
7. `/prototype` produces 2 alternatives: pure CLI vs. CLI+TUI. User picks TUI.
8. Orchestrator invokes `/setup` — scaffolds project, CI/CD, creates three Fly.io apps
   (alpha, staging, prod) for the API backend, telemetry
9. Orchestrator invokes `/build` — agent teams build in worktrees, submit PRs, Architect
   coordinates. Agents optionally deploy to alpha to validate work end-to-end.
10. Orchestrator invokes `/retro` — gathers agent status, surfaces blockers, produces retro
    summary
11. Orchestrator invokes `/qa` — full test pass, coverage report, acceptance criteria
    verification. On success, promotes build to staging.
12. Orchestrator invokes `/security` — audit, threat model against staging environment, no
    critical findings
13. Orchestrator invokes `/deploy` — promotes staging to prod after user confirmation,
    CLI published as binary
14. Pipeline complete. User has a deployed product across three environments.

**Scenario: Existing product, new feature ideation**

1. User has an existing deployed product in their repo
2. User invokes `/ideation`
3. Claude reads the codebase and existing spec, asks about pain points and opportunities
4. Generates 6 feature ideas with effort/impact matrix
5. User selects 2 features. Output: `IDEATION.md`
6. User later invokes `/spec` to formalize one feature, then `/build` to implement it

**Scenario: Mid-pipeline interruption and resumption**

1. User runs `/genesis`, completes through `/setup`
2. User closes terminal, comes back the next day
3. User invokes `/genesis` again
4. Orchestrator reads pipeline state file, detects `/setup` completed, asks "You left off
   after setup. Ready to start building?"
5. User confirms. Pipeline resumes at `/build`.

**Scenario: Skipping phases**

1. User already has a spec (wrote it manually or ran `/spec` independently)
2. User invokes `/genesis`
3. Orchestrator detects `SPEC.md` exists, asks "I see an existing spec. Want to use it, or
   start fresh?"
4. User says "use it." Orchestrator skips `/ideation` and `/spec`, proceeds to `/prototype`.

**Scenario: Phase rejection and iteration**

1. User reaches `/prototype` phase
2. Neither prototype feels right. User says "these don't capture what I want"
3. Orchestrator stays on `/prototype`, asks what's missing, generates revised prototypes
4. After 2 iterations, user approves. Pipeline advances.

**Scenario: Backward navigation during build**

1. User reaches `/build` phase, agents begin implementation
2. A spec gap is discovered — a key API contract is underspecified
3. User tells the orchestrator "I need to go back to spec"
4. Orchestrator warns: "Going back to /spec will reset /prototype, /setup, /build, and
   /retro to pending. Existing outputs will be preserved on disk but marked stale.
   Continue?"
5. User confirms. Orchestrator resets later phases in state, re-enters `/spec`
6. After spec is updated, user proceeds forward through the pipeline again

**Scenario: Standalone skill invocation with state tracking**

1. User invokes `/qa` directly, without running the full pipeline
2. `/qa` checks for `.factory/state.json` — if it does not exist, creates it
3. `/qa` records `status: "in_progress"` and `started_at` in state
4. `/qa` runs its full workflow, produces `QA-REPORT.md`
5. `/qa` records `status: "completed"` and `completed_at` in state
6. If the user later invokes `/genesis`, the orchestrator sees `/qa` was already completed

**Scenario: Claiming an existing project**

1. User has a Node.js/Express project with CI, tests, and Fly.io deployment
2. User invokes `/genesis claim`
3. Orchestrator enters claim mode, reads package.json, CI config, fly.toml, test files,
   directory structure, .env.example
4. Findings are classified by confidence: "Test command: `npm test`" (high — confirmed in
   both package.json and CI), "Database: PostgreSQL" (medium — DATABASE_URL in .env.example,
   pg in dependencies), ".env.example lists REDIS_URL but no Redis client found" (low —
   presented as question)
5. Pipeline state backfilled: setup = completed (high), build = partial (source exists,
   tests not executed), deploy = partial (fly.toml exists, status unknown)
6. Orchestrator proposes a CLAUDE.md with tech stack, commands, deployment info,
   environment variables
7. User reviews, asks to add a section about the database migration workflow
8. Orchestrator incorporates feedback, presents updated CLAUDE.md
9. User confirms. CLAUDE.md is written, state.json finalized with `claimed: true`
10. User later runs `/genesis` — orchestrator reads state, offers to continue from the
    build phase

## Data Model

Factory's "data" is entirely file-based — markdown files and a JSON state file in the
project repository. No database, no external state.

### Pipeline State

- **File**: `.factory/state.json`
- **Format**: JSON
- **Content**: Current phase, phase completion timestamps, user decisions at each handoff
  point, stale markers for phases invalidated by backward navigation, claim metadata
  (when project was onboarded via `/genesis claim`)
- **Ownership**: Every skill reads and writes this file. The orchestrator manages phase
  transitions, but standalone skill invocations also update their own phase entry. If the
  file does not exist, any skill that runs will create it.

- **Example**:

  ```json
  {
    "pipeline": "factory",
    "current_phase": "build",
    "phases": {
      "ideation": {
        "status": "completed",
        "completed_at": "2026-04-03T10:00:00Z"
      },
      "spec": {
        "status": "completed",
        "completed_at": "2026-04-03T11:30:00Z"
      },
      "prototype": {
        "status": "completed",
        "completed_at": "2026-04-03T12:00:00Z",
        "decision": "option_b_tui"
      },
      "setup": {
        "status": "completed",
        "completed_at": "2026-04-03T13:00:00Z"
      },
      "build": {
        "status": "in_progress",
        "started_at": "2026-04-03T13:30:00Z"
      }
    }
  }
  ```

- **Example (after backward navigation to `/spec`)**:

  ```json
  {
    "pipeline": "factory",
    "current_phase": "spec",
    "phases": {
      "ideation": {
        "status": "completed",
        "completed_at": "2026-04-03T10:00:00Z"
      },
      "spec": {
        "status": "in_progress",
        "started_at": "2026-04-03T15:00:00Z"
      },
      "prototype": {
        "status": "pending",
        "stale": true,
        "previous_completed_at": "2026-04-03T12:00:00Z"
      },
      "setup": {
        "status": "pending",
        "stale": true,
        "previous_completed_at": "2026-04-03T13:00:00Z"
      },
      "build": {
        "status": "pending",
        "stale": true,
        "previous_started_at": "2026-04-03T13:30:00Z"
      },
      "retro": {
        "status": "pending",
        "stale": true
      }
    }
  }
  ```

- **Phase status values**: `pending`, `in_progress`, `completed`, `skipped`, `partial`.
  The `partial` status is used exclusively by `/genesis claim` to indicate that a phase
  has some artifacts present but is not fully satisfied. Normal pipeline execution does
  not produce `partial` — phases are either completed or not. Skills reading state should
  treat `partial` the same as `pending` for gating purposes (check for required input
  files, not phase status).

- **Claim-specific fields**: When a project is onboarded via `/genesis claim`, the state
  file includes additional top-level fields:

  - `claimed` (boolean) — whether claim completed successfully
  - `claimed_at` (ISO 8601 timestamp) — when claim finished
  - `claim_confidence` (object) — count of findings at each confidence level:
    `{"high": N, "medium": N, "low": N}`

  Phases backfilled by claim include:

  - `confidence` (string: `"high"`, `"medium"`, `"low"`) — how certain claim is about
    the status
  - `findings` (array of strings) — what artifacts were detected

### Skill Outputs

| Skill | Output files |
|-------|-------------|
| `/ideation` | `IDEATION.md` |
| `/spec` | `SPEC.md`, `specs/SPEC-{domain}.md`, `CLAUDE.md` |
| `/prototype` | `prototypes/` directory with throwaway implementations, `PROTOTYPE-DECISION.md` |
| `/setup` | Project scaffold, CI/CD configs, `fly.toml`, Dockerfile, telemetry config |
| `/build` | Source code, PRs, `PROGRESS.md`, `PROGRESS-{PREFIX}.md` |
| `/retro` | `RETRO-{date}.md` |
| `/qa` | `QA-REPORT.md` |
| `/security` | `SECURITY.md` |
| `/deploy` | `DEPLOY-RECEIPT.md` |
| `/genesis claim` | `.factory/state.json` (always), `CLAUDE.md` (user-confirmed) |
| `/monitor` (v1.1) | `MONITOR-REPORT.md` |

### Skill Files (the Framework Itself)

- **Location**: User chooses during installation: global (`~/.claude/skills/`), repo-local
  (`./skills/`), or repo-local with symlink to global
- **Format**: Markdown files with YAML frontmatter (`name`, `description`)
- **Convention**: One `SKILL.md` file per skill, following the pattern established by `/spec`

## External Interfaces

### Claude Code Skill System

- **Mechanism**: Markdown files with YAML frontmatter loaded by Claude Code
- **Frontmatter fields**: `name` (string, skill trigger name), `description` (string,
  trigger matching patterns)
- **Body**: Markdown instructions that Claude follows when the skill is invoked

### Claude Code Agent Tool

- **Mechanism**: Subagent spawning via the Agent tool
- **Parameters**: name, mode (`auto`), prompt (full context for the agent)
- **Usage**: Architect launches specialist agents; orchestrator launches phase skills when
  they need agent teams

### Claude Code SendMessage Tool

- **Mechanism**: Direct inter-agent messaging
- **Usage**: Agents coordinate during `/build` — API contract questions, blocking dependency
  notifications

### Claude Code Worktree Tools

- **Mechanism**: `EnterWorktree` / `ExitWorktree` tools for git worktree management
- **Usage**: Each agent in `/build` works in an isolated worktree

### GitHub CLI (`gh`)

- **Mechanism**: Shell commands via Bash tool
- **Usage**: PR creation, CI status monitoring, issue management during `/build`

### Fly.io CLI (`fly`)

- **Mechanism**: Shell commands via Bash tool
- **Usage**: `/setup` configures, `/deploy` deploys

### Task/Team Management Tools

- **Mechanism**: `TaskCreate`, `TaskGet`, `TaskList`, `TaskUpdate`, `TeamCreate` tools
- **Usage**: `/build` orchestrator manages tasks and team coordination

## Constraints

- **Runtime**: Claude Code CLI environment. All skills must work within Claude's tool
  calling capabilities (Bash, Read, Write, Edit, Grep, Glob, Agent, SendMessage, worktree
  tools).
- **No persistent server**: Factory itself runs no long-lived process. It is a set of
  instructions that Claude follows. State persists in files only.
- **Skill file format**: Must conform to Claude Code's skill loading conventions — YAML
  frontmatter with `name` and `description`, markdown body.
- **Single-user**: v1 assumes one user at a time. No concurrent pipeline execution.
- **Existing skill compatibility**: The `/spec` skill already exists and must not be
  modified. Factory wraps it, does not fork it.
- **Stack-agnostic**: Factory itself prescribes no tech stack for the product being built.
  Stack decisions happen during `/spec` phase per project. Factory does have deployment bias
  toward Fly.io (three apps per project: alpha, staging, prod) and telemetry bias toward
  OpenTelemetry.
- **State tracking**: Every skill must read and update `.factory/state.json` on invocation
  and completion. This is non-negotiable — state must be maintained regardless of whether
  the skill is invoked via `/genesis` or standalone.

## Domain Decomposition

### Domains

Factory's natural domain boundaries are the skills themselves. However, skills cluster into
logical groups that share conventions and interfaces:

#### orchestration

- **Owns**: `/genesis` orchestrator skill — pipeline sequencing, state management, phase
  transitions (forward and backward), resumption
- **Tech stack**: Claude Code skill (markdown)
- **Build order**: Can start after `core-skills` contracts are defined (needs to know what
  each skill expects as input/output)

#### core-skills

- **Owns**: `/ideation`, `/prototype`, `/setup`, `/build`, `/retro`, `/qa`, `/security`,
  `/deploy` — the individual pipeline phase skills (v1). `/monitor` is deferred to v1.1.
- **Tech stack**: Claude Code skills (markdown), possible helper shell scripts
- **Build order**: Can start immediately. `/spec` already exists and is the reference
  implementation.
- **Per-skill specs**: Each skill has its own spec file under `specs/` rather than a single
  monolithic document:

  | Skill | Spec file |
  |-------|-----------|
  | `/ideation` | `specs/SPEC-ideation.md` |
  | `/prototype` | `specs/SPEC-prototype.md` |
  | `/setup` | `specs/SPEC-setup.md` |
  | `/build` | `specs/SPEC-build.md` |
  | `/retro` | `specs/SPEC-retro.md` |
  | `/qa` | `specs/SPEC-qa.md` |
  | `/security` | `specs/SPEC-security.md` |
  | `/deploy` | `specs/SPEC-deploy.md` |
  | `/genesis` | `specs/SPEC-genesis.md` |
  | `/genesis claim` | `specs/SPEC-claim.md` |
  | `/genesis settings` | `specs/SPEC-settings.md` |
  | `/spec` | `specs/SPEC-spec.md` |
  | `/monitor` (v1.1) | `specs/SPEC-monitor.md` |

  See `specs/INDEX.md` for a navigable index of all domain specs.

### Interface Contracts

#### orchestration -> core-skills: Skill Invocation

- **Mechanism**: The orchestrator invokes each skill by presenting its instructions to
  Claude (since skills are loaded automatically by Claude Code based on user triggers, the
  orchestrator's role is to guide the user to invoke each skill in order, passing context)
- **Contract**:

  - Orchestrator maintains `.factory/state.json` with pipeline state
  - Each skill reads its required inputs from the filesystem (e.g., `/build` reads
    `SPEC.md`, `specs/`, `CLAUDE.md`)
  - Each skill writes its outputs to well-known file paths (see Skill Outputs table above)
  - Each skill updates `.factory/state.json` on invocation and completion
  - Orchestrator verifies outputs exist before advancing to the next phase
  - On backward navigation, orchestrator resets downstream phases to `pending` with
    `stale: true`

- **Owner**: orchestration (defines the sequence and state format)

#### core-skills internal: Skill-to-Skill Data Flow

- **Mechanism**: Filesystem (markdown files in the project repo)
- **Contract** (pipeline order, each skill's input -> output):

  - `/ideation`: input = existing codebase (optional), user conversation -> output =
    `IDEATION.md`
  - `/spec`: input = idea (from ideation or user) -> output = `SPEC.md`,
    `specs/SPEC-{domain}.md`, `CLAUDE.md`
  - `/prototype`: input = `SPEC.md` -> output = `prototypes/`, `PROTOTYPE-DECISION.md`
  - `/setup`: input = `SPEC.md`, `CLAUDE.md`, prototype decision -> output = project
    scaffold, CI/CD, infra config
  - `/build`: input = `SPEC.md`, `specs/`, `CLAUDE.md`, project scaffold -> output =
    source code, PRs, `PROGRESS.md`
  - `/retro`: input = `PROGRESS.md`, agent status -> output = `RETRO-{date}.md`
  - `/qa`: input = source code, `SPEC.md` (acceptance criteria) -> output =
    `QA-REPORT.md`
  - `/security`: input = source code, `SPEC.md` -> output = `SECURITY.md`
  - `/deploy`: input = source code (passing QA + security), infra config -> output =
    `DEPLOY-RECEIPT.md`
  - `/monitor` (v1.1): input = deployed application, telemetry config -> output =
    `MONITOR-REPORT.md`

  All skills additionally read and write `.factory/state.json`.

### Shared Definitions

- **Skill file format**: YAML frontmatter (`name`, `description`) + markdown body.
  Reference: `/spec` skill at `~/.claude/skills/spec/SKILL.md`
- **State file format**: `.factory/state.json` — JSON with `pipeline`, `current_phase`,
  `phases` (map of phase name to status object). Supports `stale` marker for
  backward-navigated phases. Updated by every skill, not just the orchestrator.
- **Output file naming**: Uppercase, hyphenated: `SPEC.md`, `QA-REPORT.md`, `SECURITY.md`,
  `DEPLOY-RECEIPT.md`, `MONITOR-REPORT.md`, `RETRO-{date}.md`, `IDEATION.md`,
  `PROTOTYPE-DECISION.md`
- **Agent team roster**: Skill Architect (SA), Pipeline Designer (PD), Quality Engineer
  (QE), Security Reviewer (SR), Technical Writer (TW) — same across all skills that use
  agents

### Build Order

1. `core-skills` — can start immediately; `/spec` exists as reference. Skills can be built
   in any order since they are independent files. Suggested order follows the pipeline:
   `/ideation` -> `/prototype` -> `/setup` -> `/build` -> `/retro` -> `/qa` -> `/security`
   -> `/deploy`
2. `orchestration` — after core skills have defined contracts (input/output files), build
   the orchestrator that sequences them

## Agent Assignments

| Domain | Skill Architect (SA) | Pipeline Designer (PD) | Quality Engineer (QE) | Security Reviewer (SR) | Technical Writer (TW) |
|--------|---------------------|----------------------|----------------------|----------------------|----------------------|
| orchestration | | ✓ | ✓ | | ✓ |
| core-skills | ✓ | ✓ | ✓ | ✓ | ✓ |

**Rationale**: Factory is a framework of skill files (markdown), not a traditional
application. There is no frontend or backend code in the conventional sense. The Skill
Architect (SA) focuses on the internal structure of each skill — decision logic, agent
orchestration patterns, and cross-skill consistency. The Pipeline Designer (PD) covers UX
flow, handoff patterns, state machine design, information density, and phase transitions.
The Quality Engineer (QE) covers acceptance criteria, contract verification, and
input/output consistency across skills. The Security Reviewer (SR) covers the trust model,
security patterns baked into skills, and gate behavior. The Technical Writer (TW) covers
skill clarity, help text, anti-patterns, naming conventions, and documentation.

### Execution Plan

**Parallel batch 1** (no dependencies):

- core-skills x [Skill Architect, Pipeline Designer, Quality Engineer, Security Reviewer,
  Technical Writer]

**Parallel batch 2** (depends on core-skills contracts):

- orchestration x [Pipeline Designer, Quality Engineer, Technical Writer]

## Decision Log

| Decision | Rationale | Reversible |
|----------|-----------|------------|
| Skills are individual markdown files, one per skill | Matches existing `/spec` convention and Claude Code's skill loading mechanism | No |
| Pipeline state stored in `.factory/state.json` | Lightweight, inspectable, no external dependencies. JSON chosen over markdown for structured state that needs programmatic reading | Yes |
| `/spec` skill is not modified | It already works well. Factory wraps it, doesn't fork it. Avoids maintaining two copies. | No |
| Deployment biased toward Fly.io | User's stated preference. `/setup` and `/deploy` default to Fly.io but can adapt. | Yes |
| Telemetry biased toward OpenTelemetry | Vendor-neutral standard. `/setup` scaffolds OTel instrumentation. | Yes |
| Agent team roster is fixed | Same 5 Factory-specific roles used across all skills. Simplifies coordination. Custom roles deferred to future. | Yes |
| `/retro` is NOT code review | Code review happens within `/build` PR workflow. `/retro` is a team sync/retrospective. Renamed from `/review` to avoid confusion. | No |
| Sequential pipeline by default with backward navigation | Simplest mental model for forward flow. Backward jumps supported to handle discovered gaps. Parallel phases (e.g., QA + security simultaneously) deferred to future. | Yes |
| Each skill is independently invokable | User can run `/qa` without running the full pipeline. Skills must handle missing prior context gracefully. | No |
| Prototypes are throwaway | `/prototype` output is for feedback only, not production code. Prevents "prototype becomes production" anti-pattern. | No |
| `/monitor` deferred to v1.1 | Reduces v1 scope. Monitoring is valuable but not essential for the initial release. `/retro` is included in v1 as a mandatory post-build step. | Yes |
| Skill installation offers three options | User chooses: global, repo-local, or repo-local + symlink. Balances versioning with availability. | Yes |
| Backward navigation resets downstream phases | When jumping back, later phases are set to `pending` with `stale: true`. Outputs preserved on disk for reference. Simplest safe behavior. | Yes |
| State tracking from day 1 | Every skill updates `.factory/state.json` on invocation and completion, even standalone. Ensures pipeline state is always accurate. | No |
| Per-skill spec files | Individual spec files (`specs/SPEC-{skill}.md`) instead of monolithic `SPEC-core-skills.md`. Easier to navigate, review, and update independently. | Yes |
| `partial` phase status for claim mode | Existing projects often have incomplete phase coverage (CI but no deploy). `partial` is written only by `/genesis claim`, not by normal pipeline execution. Skills treat `partial` as `pending` for gating. | Yes |
| Claim mode is inline in orchestrator | `/genesis claim` is a mode of `/genesis`, not a separate skill. Claim logic runs inside the orchestrator because it is not a pipeline phase — it is a pre-pipeline onboarding step. | No |
| Claim does not execute code | Claim reads artifacts but never runs test suites, build commands, or deploy checks. Side-effect-free analysis only. Test execution is `/qa`'s job. | No |
| Claim proposes CLAUDE.md, never auto-writes | Claim always presents proposed CLAUDE.md content to the user and requires explicit confirmation before writing. Respects existing CLAUDE.md files. | No |

## Open Questions

- **Agents decide during spec generation**:

  - Exact structure of `IDEATION.md` — should follow a consistent format but specific
    sections TBD by the Pipeline Designer agent
  - How `/build` coordinates multiple parallel agents at scale — the Architect agent within
    `/build` handles this, but the precise task decomposition strategy is per-project

- **Requires experimentation**:

  - How does the `/genesis` orchestrator actually trigger sub-skills? Options: (a) embed
    sub-skill instructions inline in the orchestrator prompt, (b) instruct the user to type
    the sub-skill command, (c) use the Agent tool to spawn a sub-agent with the sub-skill's
    instructions. Option (c) is most robust but most expensive. Recommend (c) for agentic
    skills (`/build`) and (a) for simpler skills.

## Architect Review

### Issues Found and Resolutions

1. **Skill invocation mechanism unclear.** The orchestrator cannot directly "invoke" a
   sub-skill — Claude Code loads skills based on user input matching trigger patterns.
   Resolution: The orchestrator guides the conversation so that the user's intent triggers
   the appropriate skill, or the orchestrator embeds the skill's instructions inline when
   needed. This is a fundamental design question that needs experimentation during build.
   Documented in Open Questions.

2. **`/qa` and `/security` agent model inconsistency.** Initially classified as "agentic"
   (spawning sub-agents per domain), but the detailed specs describe procedural workflows.
   Resolution: Reclassified as "hybrid" — procedural for single-domain projects, optionally
   agentic for multi-domain projects. Updated in per-skill spec files under `specs/`.

3. **`/retro` is now part of the v1 pipeline.** The v1 pipeline is: `/ideation` -> `/spec`
   -> `/prototype` -> `/setup` -> `/build` -> `/retro` -> `/qa` -> `/security` -> `/deploy`.
   `/retro` runs after `/build` as a mandatory retrospective step before quality gates.
   The state machine and orchestration spec reflect this.

4. **State file schema uses `skipped` alongside `status`.** The `skipped` boolean and
   `status: "skipped"` were redundant. Resolution: `skipped` is now a valid `status` value;
   the separate `skipped` boolean is kept for quick filtering, and `skip_reason` provides
   context. Consistent in the orchestration spec.

5. **`/setup` modifies `CLAUDE.md` but `/spec` generates it.** Both skills write to
   CLAUDE.md. Resolution: `/spec` creates the initial CLAUDE.md. `/setup` appends to it
   (adding concrete build/test/deploy commands). `/build` further amends it as learnings
   emerge. This append-not-overwrite convention is documented in both domain specs.

6. **Contract completeness.** All skill input/output contracts are specified in the
   core-skills contract table. Cross-referenced against the orchestration spec's state
   machine. No gaps found — every pipeline phase has declared inputs that are outputs of a
   prior phase.

7. **State tracking is universal.** Every skill updates `.factory/state.json` on invocation
   and completion, even when invoked standalone. This cross-cutting requirement is enforced
   in every per-skill spec file.

### Cross-Cutting Consistency Check

- **File naming**: All output files follow UPPERCASE-HYPHENATED.md convention. Consistent
  across all per-skill spec files.
- **Agent roster**: Same 5 Factory-specific specialists (SA, PD, QE, SR, TW) referenced in
  SPEC.md and all per-skill spec files. No discrepancies.
- **Skill file format**: YAML frontmatter with `name` and `description` + markdown body.
  Matches `/spec` reference implementation. Consistent.
- **Error handling pattern**: Every skill defines failure output (file with status field
  indicating failure + diagnostics). Consistent across all skills.
- **State tracking**: Every skill reads and writes `.factory/state.json`. Verified across
  all per-skill spec files.

### Open Items for User

1. **Skill invocation mechanism**: How does the `/genesis` orchestrator actually trigger
   sub-skills? Options: (a) embed sub-skill instructions inline in the orchestrator prompt,
   (b) instruct the user to type the sub-skill command, (c) use the Agent tool to spawn a
   sub-agent with the sub-skill's instructions. Option (c) is most robust but most
   expensive. Recommend (c) for agentic skills (`/build`) and (a) for simpler skills.

2. **CLAUDE.md ownership**: The spec skill generates CLAUDE.md for the target product, not
   for Factory itself. The CLAUDE.md below is for Factory's own development. These are
   different files for different purposes — must not be confused.
