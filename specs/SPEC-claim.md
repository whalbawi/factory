# /factory claim — Codebase Onboarding for Existing Projects

`/factory claim` is a mode of the `/factory` orchestrator skill (not a separate skill)
that deeply reads an existing codebase, infers what Factory pipeline phases have already
been completed, writes `.factory/state.json` with confidence-tagged phase statuses, and
proposes a `CLAUDE.md` tailored to the project. It is the on-ramp for bringing an existing
project into the Factory pipeline.

## Contract

| Field | Value |
|-------|-------|
| **Required inputs** | An existing codebase (at least one source file) |
| **Optional inputs** | Existing `CLAUDE.md`, `README.md`, `.env.example` |
| **Outputs** | `.factory/state.json`, proposed `CLAUDE.md` (user-confirmed) |
| **Failure output** | `.factory/state.json` with `claimed: false` and diagnostics |

The skill reads the codebase non-destructively. It never modifies existing files without
explicit user confirmation. The only file it writes unconditionally is
`.factory/state.json`.

If `CLAUDE.md` already exists, the skill proposes modifications and asks the user to
confirm. If the user declines, `CLAUDE.md` is not touched.

If `CLAUDE.md` does not exist, the skill proposes full content and writes it only after
user confirmation.

---

## Category

**Conversational mode** of the `/factory` orchestrator — interactive, with a
read-analyze-propose-confirm loop. No sub-agents are spawned. The orchestrator itself
executes claim logic inline because claim is a mode of `/factory`, not a delegated phase.

---

## Process

### Step 1: Detect Claim Invocation

When the user invokes `/factory claim` (or `/factory` with an argument like "claim this
project", "onboard this codebase", "take over this project"), the orchestrator enters
claim mode instead of the normal pipeline flow.

If `.factory/state.json` already exists with `claimed: true`, warn the user:

```text
This project was already claimed on [timestamp]. Re-running claim will
overwrite the existing state. Continue? [Y/n]
```

### Step 2: Codebase Deep Read

Read the codebase systematically. The goal is to extract concrete facts about the
project's architecture, conventions, tech stack, test commands, deploy setup, and
development workflow. Read files in the following order, stopping to extract findings
at each layer.

#### Layer 1: Package Manifests (tech stack, dependencies, scripts)

| File | What to extract |
|------|----------------|
| `package.json` | name, scripts (test, build, lint, start, dev), dependencies, devDependencies, engines |
| `go.mod` | module name, Go version, dependencies |
| `Cargo.toml` | package name, edition, dependencies, workspace members |
| `pyproject.toml` | project name, Python version, dependencies, scripts, build system |
| `requirements.txt` | Python dependencies (less authoritative than pyproject.toml) |
| `Gemfile` | Ruby dependencies, Ruby version |
| `pom.xml` / `build.gradle` | Java/Kotlin project config |
| `mix.exs` | Elixir project config |
| `composer.json` | PHP project config |

Extract: project name, language, language version, framework, package manager, runnable
scripts (test, build, lint, format, start, deploy).

#### Layer 2: CI/CD Configuration (automation, test commands, deploy targets)

| File / Pattern | What to extract |
|----------------|----------------|
| `.github/workflows/*.yml` | Jobs, steps, test commands, deploy targets, environment variables |
| `.gitlab-ci.yml` | Stages, scripts, deploy targets |
| `Jenkinsfile` | Pipeline stages |
| `.circleci/config.yml` | Jobs, steps |
| `bitbucket-pipelines.yml` | Pipeline steps |

Extract: CI provider, test command (as run in CI), build command, deploy target, branch
protection rules, environment secrets referenced.

#### Layer 3: Deployment Configuration (infrastructure, environments)

| File / Pattern | What to extract |
|----------------|----------------|
| `fly.toml` | App name, region, build config, services, environment |
| `Dockerfile` | Base image, build steps, exposed ports, entrypoint |
| `docker-compose.yml` | Services, ports, volumes, environment |
| `render.yaml` | Render deployment config |
| `vercel.json` | Vercel config |
| `netlify.toml` | Netlify config |
| `serverless.yml` | Serverless framework config |
| `terraform/` or `*.tf` | Infrastructure-as-code |
| `pulumi/` or `Pulumi.yaml` | IaC config |
| `k8s/` or `kubernetes/` | Kubernetes manifests |
| `Procfile` | Heroku-style process types |

Extract: deployment platform, number of environments, health check endpoints, scaling
config, database/service dependencies.

#### Layer 4: Test Infrastructure (testing patterns, coverage)

Scan for test files and configuration:

| Signal | What it tells you |
|--------|------------------|
| `__tests__/`, `test/`, `tests/`, `spec/` directories | Test directory convention |
| `*.test.ts`, `*.spec.ts`, `*_test.go`, `test_*.py` | Test file naming pattern |
| `jest.config.*`, `vitest.config.*` | JS/TS test runner |
| `pytest.ini`, `setup.cfg [tool:pytest]`, `pyproject.toml [tool.pytest]` | Python test runner |
| `.nycrc`, `istanbul.yml`, `coverage/` | Coverage tooling |
| `cypress/`, `playwright/`, `e2e/` | E2E test framework |
| Number of test files vs source files | Test coverage density (rough) |

Extract: test runner, test command, test file pattern, approximate test count, whether
E2E tests exist, coverage tooling.

#### Layer 5: Project Structure and Conventions

| Signal | What it tells you |
|--------|------------------|
| Directory tree (depth 3) | Project organization pattern (monorepo, domain-driven, flat) |
| `.eslintrc*`, `.prettierrc*`, `biome.json` | Linting and formatting tools |
| `tsconfig.json` | TypeScript configuration, path aliases, strictness |
| `.editorconfig` | Editor conventions |
| `.nvmrc`, `.node-version`, `.python-version`, `.tool-versions` | Version pinning |
| `.husky/`, `.pre-commit-config.yaml` | Git hooks |
| `CLAUDE.md` | Existing Claude Code instructions |
| `README.md` | Project documentation, setup instructions |
| `.env.example` | Required environment variables |
| `CONTRIBUTING.md` | Contribution guidelines |

Extract: code style tools, formatting conventions, version management approach,
documentation quality, environment variable requirements.

### Step 3: Confidence Classification

Every finding from Step 2 is tagged with a confidence level. The confidence level
determines how the finding is presented to the user in Step 5.

#### High Confidence

Multiple corroborating signals confirm the finding. Present as fact.

Examples:

- `npm test` appears in both `package.json` scripts AND `.github/workflows/ci.yml`
  -> "Test command: `npm test`" (high)
- `fly.toml` exists AND `.github/workflows/deploy.yml` references `fly deploy`
  -> "Deploys to Fly.io" (high)
- `jest.config.ts` exists AND `package.json` devDependencies includes `jest` AND
  test files use `describe`/`it` syntax
  -> "Test runner: Jest" (high)
- `tsconfig.json` exists AND `package.json` devDependencies includes `typescript` AND
  source files use `.ts`/`.tsx` extensions
  -> "Language: TypeScript" (high)

#### Medium Confidence

Single authoritative signal. Present with caveat.

Examples:

- `npm test` in `package.json` but no CI config found
  -> "Test command appears to be `npm test` (from package.json; no CI found to confirm)"
  (medium)
- `Dockerfile` exists but no deployment config or CI deploy step
  -> "Dockerized, but deploy target unclear" (medium)
- `.env.example` references `DATABASE_URL` but no ORM/database driver in dependencies
  -> "May use a database (DATABASE_URL in .env.example)" (medium)
- Test files exist but no test runner config found
  -> "Tests exist but runner is unclear" (medium)

#### Low Confidence

Indirect or ambiguous signal. Present as a question to the user.

Examples:

- `.env.example` exists but no `dotenv` in dependencies and no env loading code found
  -> "I see .env.example but no dotenv usage. Do you use environment variables?" (low)
- A `deploy.sh` script exists but it is unclear what it deploys to
  -> "Found deploy.sh — what platform does this deploy to?" (low)
- Source files import a framework but no config file exists
  -> "Are you using [framework]? I see imports but no config." (low)

### Step 4: State Backfill

Map detected artifacts to pipeline phases and write `.factory/state.json`. Each phase
is marked `completed`, `partial`, or `pending`.

#### Artifact-to-Phase Mapping

| Phase | Completed signals | Partial signals |
|-------|------------------|-----------------|
| ideation | Not detectable from artifacts. Always `pending`. | N/A |
| spec | `SPEC.md` exists | `README.md` exists with project description (partial substitute) |
| prototype | `prototypes/` directory exists, `PROTOTYPE-DECISION.md` exists | `prototypes/` exists but no decision doc |
| setup | Package manifest + CI config + deployment config all exist | Package manifest exists but no CI, or CI exists but no deploy config |
| build | Source code exists AND tests exist AND tests pass | Source code exists but no tests, or tests exist but some fail |
| retro | `RETRO-*.md` exists | Not applicable — retro is binary |
| qa | `QA-REPORT.md` exists with `status: passed` | `QA-REPORT.md` exists with `status: failed` or partial findings |
| security | `SECURITY.md` exists with no critical findings | `SECURITY.md` exists with unresolved critical findings |
| deploy | `DEPLOY-RECEIPT.md` exists AND app is accessible | `DEPLOY-RECEIPT.md` exists but app health unknown |

Important: `partial` means "some work has been done but the phase is not fully
satisfied." It is distinct from both `completed` and `pending`. A partial phase still
needs attention before downstream phases can rely on it.

For phases marked `completed` or `partial`, include a `confidence` field and a
`findings` array explaining what was detected:

```json
{
  "pipeline": "factory",
  "project_name": "my-existing-app",
  "started_at": "2026-04-03T10:00:00Z",
  "current_phase": "build",
  "claimed": true,
  "claimed_at": "2026-04-03T10:00:00Z",
  "phases": {
    "ideation": {
      "status": "pending"
    },
    "spec": {
      "status": "pending",
      "note": "No SPEC.md found. README.md exists but is not a substitute."
    },
    "prototype": {
      "status": "pending"
    },
    "setup": {
      "status": "completed",
      "confidence": "high",
      "findings": [
        "package.json with build/test/lint scripts",
        ".github/workflows/ci.yml with test and lint jobs",
        "fly.toml with production deployment config"
      ],
      "completed_at": "2026-04-03T10:00:00Z"
    },
    "build": {
      "status": "partial",
      "confidence": "medium",
      "findings": [
        "Source code exists across 3 directories (src/api, src/web, src/shared)",
        "47 test files found, but test suite not executed during claim",
        "No PROGRESS.md found"
      ]
    },
    "retro": {
      "status": "pending"
    },
    "qa": {
      "status": "pending"
    },
    "security": {
      "status": "pending"
    },
    "deploy": {
      "status": "partial",
      "confidence": "medium",
      "findings": [
        "fly.toml exists with app name 'my-existing-app'",
        "No DEPLOY-RECEIPT.md — unclear if currently deployed"
      ]
    }
  }
}
```

The `current_phase` is set to the first phase that is `pending` or `partial`, scanning
in pipeline order. In the example above, `ideation` is pending, but since `setup` and
`build` show existing work, `current_phase` is set to `build` — the earliest phase
that is `partial` and has meaningful work to continue.

**Rule for current_phase**: Set `current_phase` to the earliest `partial` phase if one
exists. If no partial phases, set it to the earliest `pending` phase that follows a
`completed` phase. The intent is to point the user at where they should resume work.

### Step 5: Present Findings to User

Present findings grouped by category, with confidence-appropriate framing.

#### Presentation Format

```text
I've analyzed your codebase. Here's what I found:

## Tech Stack
- Language: TypeScript (high confidence)
- Framework: Express.js (high confidence)
- Test runner: Jest (high confidence)
- Package manager: npm

## Commands
- Test: `npm test` (confirmed in CI)
- Build: `npm run build` (confirmed in CI)
- Lint: `npm run lint` (confirmed in CI)
- Start: `npm start`

## Infrastructure
- CI: GitHub Actions (.github/workflows/ci.yml)
- Deploy: Fly.io (fly.toml)
- Docker: Yes (Dockerfile)

## Pipeline Status
- Setup: COMPLETE (package.json + CI + fly.toml)
- Build: PARTIAL (source code exists, tests not verified)
- Deploy: PARTIAL (fly.toml exists, deployment status unknown)
- All other phases: PENDING

## Questions (low-confidence findings)
- I see .env.example references REDIS_URL but no Redis client in
  dependencies. Do you use Redis?
- Found a deploy.sh script — is this used alongside Fly.io or is it
  legacy?
```

**Rules for presentation**:

- High-confidence findings: stated as facts, no hedging.
- Medium-confidence findings: stated with a caveat ("appears to be", "likely",
  "from package.json but not confirmed in CI").
- Low-confidence findings: stated as questions to the user.
- Group findings by category (tech stack, commands, infrastructure, pipeline status,
  questions).
- Do NOT dump raw file contents. Summarize what was found.

### Step 6: CLAUDE.md Generation

After presenting findings, propose a `CLAUDE.md` for the project. This is the key
deliverable — it gives every future Claude session (and every Factory skill) the context
needed to work effectively in this codebase.

#### CLAUDE.md Structure

The proposed `CLAUDE.md` follows this structure:

```markdown
# [Project Name]

## Project Summary

[1-3 sentences: what this project is, who it's for, what it does]

## Architecture

**Tech stack:** [language], [framework], [database], [key libraries]

**Components:**

- [Component 1]: [description]
- [Component 2]: [description]

## Development

### Commands

- **Test**: `[test command]`
- **Build**: `[build command]`
- **Lint**: `[lint command]`
- **Format**: `[format command]`
- **Start (dev)**: `[dev command]`
- **Start (prod)**: `[prod/start command]`

### Code Conventions

- [Convention 1 extracted from linter/formatter config]
- [Convention 2 extracted from existing code patterns]

## Deployment

- **Platform**: [platform]
- **Environments**: [list]
- **Deploy command**: `[command]`

## Environment Variables

| Variable | Purpose | Required |
|----------|---------|----------|
| [VAR_1]  | [purpose] | [yes/no] |
```

**Content rules**:

- Every section must have concrete values, not placeholders. If a value cannot be
  determined, omit the section entirely rather than writing "[unknown]".
- The Commands section is the most important. Every command must be verified against
  the package manifest or CI config. Do not guess commands.
- Code Conventions should be extracted from actual tooling config (eslint rules,
  prettier config, tsconfig strictness) not invented.
- Environment Variables are extracted from `.env.example` if it exists.

#### If CLAUDE.md Already Exists

1. Read the existing `CLAUDE.md`.
2. Identify sections that are missing, incomplete, or inconsistent with what claim
   detected.
3. Propose a diff — show what would be added, changed, or removed.
4. Ask the user:

```text
Your CLAUDE.md already has [X sections]. I'd like to propose these changes:

ADD:
- Commands section with test/build/lint commands
- Deployment section with Fly.io config

UPDATE:
- Architecture section: add database component (PostgreSQL detected)

KEEP AS-IS:
- Project Summary (looks accurate)
- Code Conventions (already comprehensive)

Apply these changes? [Y / show diff / edit / skip]
```

5. If the user says "show diff", present the full proposed content with markers
   indicating additions, changes, and preserved sections.
6. If the user says "edit", enter the feedback loop (Step 7).
7. If the user says "skip", do not touch `CLAUDE.md`.
8. If the user says "Y", apply the changes.

#### If No CLAUDE.md Exists

1. Present the full proposed content.
2. Ask the user to confirm or provide feedback.
3. On confirmation, write `CLAUDE.md`.

### Step 7: Feedback/Improvement Loop

After presenting the proposed `CLAUDE.md`, the user may want changes. Handle this as
an iterative loop:

1. User provides feedback ("add X", "remove Y", "change Z").
2. Incorporate the feedback into the proposal.
3. Present the updated proposal.
4. Ask for confirmation again.
5. Repeat until the user confirms.

The loop has no fixed iteration limit — it runs until the user is satisfied. However,
if the user has provided feedback 3+ times, ask: "Are we close, or should we take a
different approach?"

### Step 8: Write Outputs

1. Write `.factory/state.json` (always — this was already written in Step 4, but
   update it with the final `claimed: true` status).
2. Write `CLAUDE.md` if the user confirmed (new file or modifications).
3. Update `.factory/state.json` to record claim completion:

```json
{
  "claimed": true,
  "claimed_at": "2026-04-03T10:15:00Z",
  "claim_confidence": {
    "high": 8,
    "medium": 3,
    "low": 2
  }
}
```

### Step 9: Handoff to Pipeline

After claim completes, the orchestrator transitions to normal pipeline mode:

```text
Claim complete. Your project is ready for the Factory pipeline.

Pipeline status:
- Setup: COMPLETE
- Build: PARTIAL (source exists, tests not verified)
- All other phases: PENDING

Recommended next step: /factory to continue from [current_phase].
Or run any skill independently: /qa, /security, /spec, etc.
```

The user can then invoke `/factory` (which will read the state file and resume from
the appropriate phase) or invoke individual skills directly.

---

## State Tracking Protocol

Claim mode follows the same state tracking contract as all other Factory skills:

1. **On entry**: Create or update `.factory/state.json`. Set `claimed: false` and
   `claim_started_at` to the current timestamp.
2. **During execution**: Update phase statuses as findings are classified.
3. **On completion**: Set `claimed: true` and `claimed_at`. Record confidence
   summary.
4. **On failure**: Set `claimed: false` with a `claim_error` field describing what
   went wrong.

Claim does NOT set any phase to `in_progress` — it only sets `completed`, `partial`,
or `pending`. The `in_progress` status is reserved for phases that are actively being
executed by their respective skills.

---

## Anti-Patterns

- **Running test suites during claim.** Claim reads artifacts but does not execute
  code. Running `npm test` or `pytest` could have side effects (database migrations,
  network calls, file writes). Claim infers test existence from files, not from
  execution. If the user wants test verification, that is `/qa`'s job.

- **Overwriting CLAUDE.md without confirmation.** Claim NEVER writes to `CLAUDE.md`
  without the user explicitly confirming. Even if the existing `CLAUDE.md` is clearly
  incomplete, the user decides.

- **Marking phases as `completed` without high confidence.** A phase should only be
  `completed` if claim has high confidence in the finding. Medium-confidence findings
  result in `partial` status. Low-confidence findings leave the phase as `pending`.

- **Inventing commands.** If claim cannot find a test command in the package manifest
  or CI config, it does not guess. It asks the user or omits the command from
  `CLAUDE.md`.

- **Reading every file in the repo.** Claim reads specific files and patterns (see
  Step 2), not the entire codebase. For large repos, reading every file would be
  slow and wasteful. The directory tree (depth 3) and targeted file reads are
  sufficient.

- **Backfilling spec-level artifacts.** Claim does NOT generate `SPEC.md`,
  `IDEATION.md`, `PROTOTYPE-DECISION.md`, or any other skill output. It only
  detects whether they exist. Generating them is the job of their respective skills.

- **Treating `partial` as `completed`.** A `partial` phase has gaps. The orchestrator
  should not skip a partial phase — it should surface the gaps and let the user
  decide whether to complete it or move forward.

---

## Examples

### Example 1: Node.js project with CI and Fly.io deployment

**Codebase contents**:

- `package.json` with `test`, `build`, `lint`, `start` scripts
- `src/` with 30+ TypeScript files
- `tests/` with 20+ test files using Jest
- `.github/workflows/ci.yml` running `npm test` and `npm run lint`
- `.github/workflows/deploy.yml` running `fly deploy`
- `fly.toml` with app name and region
- `Dockerfile`
- `.env.example` with `DATABASE_URL`, `SESSION_SECRET`
- `README.md` with setup instructions
- No `CLAUDE.md`

**Claim output**:

```text
I've analyzed your codebase. Here's what I found:

## Tech Stack
- Language: TypeScript (high — tsconfig.json + .ts files + typescript in devDependencies)
- Framework: Express.js (high — express in dependencies + src/server.ts)
- Database: PostgreSQL (medium — DATABASE_URL in .env.example, pg in dependencies)
- Test runner: Jest (high — jest.config.ts + jest in devDependencies + test files)

## Commands
- Test: `npm test` (confirmed: package.json + ci.yml)
- Build: `npm run build` (confirmed: package.json + ci.yml)
- Lint: `npm run lint` (confirmed: package.json + ci.yml)
- Start: `npm start` (from package.json)

## Infrastructure
- CI: GitHub Actions (ci.yml + deploy.yml)
- Deploy: Fly.io (fly.toml + deploy.yml)
- Docker: Yes (Dockerfile, multi-stage build)
- Environments: 1 detected (fly.toml references 'my-app')

## Pipeline Status
- Setup: COMPLETE (high confidence)
- Build: PARTIAL (source + tests exist, not executed)
- Deploy: PARTIAL (fly.toml exists, deployment status unknown)
- Spec, Ideation, Prototype, Retro, QA, Security: PENDING

## Questions
- .env.example lists SESSION_SECRET — are you using session-based auth?
- README mentions a staging environment but I only see one fly.toml.
  Do you have separate staging config?
```

**Proposed CLAUDE.md**:

```markdown
# my-app

## Project Summary

Express.js API server with TypeScript. Serves a REST API with PostgreSQL
for persistence.

## Architecture

**Tech stack:** TypeScript, Express.js, PostgreSQL, Jest

**Components:**

- **API server** (src/server.ts): Express HTTP server
- **Routes** (src/routes/): API endpoint handlers
- **Models** (src/models/): Database models
- **Tests** (tests/): Jest test suite

## Development

### Commands

- **Test**: `npm test`
- **Build**: `npm run build`
- **Lint**: `npm run lint`
- **Start (dev)**: `npm run dev`
- **Start (prod)**: `npm start`

### Code Conventions

- Strict TypeScript (tsconfig.json: strict: true)
- ESLint with @typescript-eslint
- Prettier for formatting

## Deployment

- **Platform**: Fly.io
- **Deploy command**: `fly deploy`

## Environment Variables

| Variable | Purpose | Required |
|----------|---------|----------|
| DATABASE_URL | PostgreSQL connection string | Yes |
| SESSION_SECRET | Session signing key | Yes |
```

### Example 2: Python project with minimal tooling

**Codebase contents**:

- `pyproject.toml` with project name, Python 3.12, dependencies
- `src/` with 10 Python files
- No test directory, no test files
- No CI config
- No deployment config
- `.env.example` with `API_KEY`
- No `CLAUDE.md`, no `README.md`

**Claim output**:

```text
I've analyzed your codebase. Here's what I found:

## Tech Stack
- Language: Python 3.12 (high — pyproject.toml)
- Framework: FastAPI (high — fastapi in dependencies + main.py imports)
- Package manager: pip (medium — no poetry.lock or pdm.lock found)

## Commands
- Test: unknown (no test config or test files found)
- Build: N/A (no build step detected)
- Lint: unknown (no linter config found)
- Start: `uvicorn src.main:app` (medium — uvicorn in dependencies, main.py exists)

## Infrastructure
- CI: None detected
- Deploy: None detected
- Docker: No

## Pipeline Status
- Setup: PARTIAL (pyproject.toml exists, no CI or deploy config)
- Build: PARTIAL (source code exists, no tests)
- All other phases: PENDING

## Questions
- No tests found. Do you have tests elsewhere, or is this pre-testing?
- .env.example has API_KEY — what service is this for?
- How do you run this project locally?
- Do you have a preferred test framework (pytest, unittest)?
- Where do you plan to deploy this?
```

### Example 3: Project with existing CLAUDE.md

**Codebase contents**:

- Full Go project with `go.mod`, source code, tests
- `.github/workflows/ci.yml`
- Existing `CLAUDE.md` with Project Summary and Architecture sections
- `CLAUDE.md` is missing Commands and Deployment sections

**Claim behavior**:

```text
Your CLAUDE.md already has 2 sections. I'd like to propose these changes:

ADD:
- Commands section: `go test ./...`, `go build ./cmd/server`,
  `golangci-lint run`
- Deployment section: Fly.io (detected from fly.toml)
- Environment Variables section: from .env.example

UPDATE:
- Architecture section: add "Database: PostgreSQL" (detected from
  go.mod dependency on pgx)

KEEP AS-IS:
- Project Summary (looks accurate)

Apply these changes? [Y / show diff / edit / skip]
```

---

## Architect Review

### Decisions Made

1. **`partial` as a new phase status.** The existing state model uses `pending`,
   `in_progress`, `completed`, and `skipped`. Claim introduces `partial` because
   existing projects often have incomplete phase coverage (e.g., CI exists but no
   deploy step). This is a data model change that affects the orchestrator and
   potentially all skills that read state. Decision: `partial` is valid only when
   written by claim mode. Normal pipeline execution does not produce `partial` — a
   phase is either completed or not.

2. **Claim does not execute code.** This is a deliberate safety boundary. Running
   test suites, build commands, or deploy checks during claim could have side effects.
   Claim infers from artifacts only. `/qa` handles test execution.

3. **Confidence levels are presentation guidance, not schema.** The `confidence` field
   in state.json is `"high"`, `"medium"`, or `"low"` — a simple string. It does not
   affect pipeline logic. It exists so the orchestrator (and the user reading
   state.json) can understand how much to trust the backfilled status.

4. **Claim is inline in the orchestrator.** Unlike other phases that are separate
   skills, claim is executed directly by the `/factory` orchestrator. This is because
   claim is a mode of `/factory`, not a pipeline phase. It does not appear in the
   pipeline sequence and does not have its own `SKILL.md`.

5. **`current_phase` after claim.** Set to the earliest `partial` phase, or the
   earliest `pending` phase that follows a `completed` phase. This gives the user a
   sensible starting point without requiring them to manually figure out where to
   begin.

6. **CLAUDE.md generation scope.** Claim generates a project-level `CLAUDE.md` for
   the target codebase, not for Factory itself. This is the same `CLAUDE.md` that
   `/spec` would generate for a greenfield project. The content is narrower (no spec
   output, no domain decomposition) because claim is working from existing code, not
   from a spec.

### Open Questions

1. **Should claim detect monorepo structure?** A monorepo with multiple packages
   (e.g., `packages/api`, `packages/web`) would benefit from per-package analysis.
   Current spec treats the repo as a single project. Monorepo support could be added
   later without breaking the claim contract.

2. **Should claim verify deployment status?** Currently claim does not make network
   requests (no `curl` to health endpoints, no `fly status`). Adding deployment
   verification would give higher confidence for the deploy phase but introduces
   network dependencies. Recommendation: defer to `/deploy` or a future enhancement.

3. **How should claim handle `.factory/state.json` written by a previous claim with
   different findings?** Current spec says warn and overwrite. An alternative is to
   show a diff of what changed since last claim. This could be valuable for projects
   that have evolved, but adds complexity. Recommendation: overwrite for v1, diff
   for v1.1.

4. **Should `partial` status be visible to all skills or only the orchestrator?**
   If `/build` reads state and sees `setup: partial`, should it refuse to run? Current
   recommendation: skills treat `partial` the same as `pending` — they check for their
   required input files, not phase status. The orchestrator surfaces `partial` to the
   user for decision-making.
