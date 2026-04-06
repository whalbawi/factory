# Claim Mode: Deep-Read Protocol and Classification

## Step 1: Codebase Deep Read

Read the codebase systematically in five layers. Extract concrete facts
at each layer before moving to the next.

**Layer 1 -- Package Manifests** (tech stack, dependencies, scripts)

Read whichever of these exist: `package.json`, `go.mod`, `Cargo.toml`,
`pyproject.toml`, `requirements.txt`, `Gemfile`, `pom.xml`,
`build.gradle`, `mix.exs`, `composer.json`.

Extract: project name, language, language version, framework, package
manager, runnable scripts (test, build, lint, format, start, deploy).

**Layer 2 -- CI/CD Configuration** (automation, test commands, deploy
targets)

Read: `.github/workflows/*.yml`, `.gitlab-ci.yml`, `Jenkinsfile`,
`.circleci/config.yml`, `bitbucket-pipelines.yml`.

Extract: CI provider, test command (as run in CI), build command, deploy
target, environment secrets referenced.

**Layer 3 -- Deployment Configuration** (infrastructure, environments)

Read: `fly.toml`, `Dockerfile`, `docker-compose.yml`, `render.yaml`,
`vercel.json`, `netlify.toml`, `serverless.yml`, `terraform/` or
`*.tf`, `k8s/` or `kubernetes/`, `Procfile`.

Extract: deployment platform, number of environments, health check
endpoints, database/service dependencies.

**Layer 4 -- Test Infrastructure** (testing patterns, coverage)

Scan for: test directories (`__tests__/`, `test/`, `tests/`, `spec/`),
test file patterns (`*.test.ts`, `*.spec.ts`, `*_test.go`, `test_*.py`),
test runner configs (`jest.config.*`, `vitest.config.*`, `pytest.ini`,
`pyproject.toml [tool.pytest]`), coverage tooling (`.nycrc`,
`coverage/`), E2E frameworks (`cypress/`, `playwright/`, `e2e/`).

Extract: test runner, test command, test file pattern, approximate test
count, whether E2E tests exist, coverage tooling.

**Layer 5 -- Project Structure and Conventions**

Read: directory tree (depth 3), linter/formatter configs (`.eslintrc*`,
`.prettierrc*`, `biome.json`), `tsconfig.json`, `.editorconfig`,
version pinning (`.nvmrc`, `.python-version`, `.tool-versions`), git
hooks (`.husky/`, `.pre-commit-config.yaml`), `CLAUDE.md`, `README.md`,
`.env.example`, `CONTRIBUTING.md`.

Extract: code style tools, formatting conventions, version management,
documentation quality, environment variable requirements.

**Important**: Claim never executes code. It reads artifacts only. No
`npm test`, no `pytest`, no build commands. Side-effect-free analysis.
If the user wants test verification, that is `/qa`'s job.

## Step 2: Confidence Classification

Tag every finding with a confidence level. The level determines how it
is presented to the user.

**High confidence** -- multiple corroborating signals. Present as fact.

Examples:

- `npm test` in both `package.json` scripts AND `.github/workflows/ci.yml`
  -> "Test command: `npm test`"
- `jest.config.ts` + jest in devDependencies + test files use
  `describe`/`it` -> "Test runner: Jest"
- `tsconfig.json` + typescript in devDependencies + `.ts` source files
  -> "Language: TypeScript"

**Medium confidence** -- single authoritative signal. Present with caveat.

Examples:

- `npm test` in `package.json` but no CI config found
  -> "Test command appears to be `npm test` (from package.json; no CI
  found to confirm)"
- `Dockerfile` exists but no deployment config or CI deploy step
  -> "Dockerized, but deploy target unclear"
- Test files exist but no test runner config found
  -> "Tests exist but runner is unclear"

**Low confidence** -- indirect or ambiguous signal. Present as a question.

Examples:

- `.env.example` exists but no `dotenv` in dependencies and no env
  loading code -> "I see .env.example but no dotenv usage. Do you use
  environment variables?"
- A `deploy.sh` script exists but target is unclear
  -> "Found deploy.sh -- what platform does this deploy to?"

## Step 3: State Backfill

Map detected artifacts to pipeline phases and write
`.factory/state.json`. Always write this file -- no user confirmation
needed.

**Artifact-to-phase mapping**:

| Phase | Completed | Partial |
|-------|-----------|---------|
| ideation | Not detectable. Always `pending`. | N/A |
| spec | `SPEC.md` exists | `README.md` with project description |
| prototype | `prototypes/` + `PROTOTYPE-DECISION.md` | `prototypes/` but no decision doc |
| setup | Package manifest + CI + deploy config | Manifest exists but no CI, or CI but no deploy |
| build | Source code + tests exist | Source code but no tests, or tests but some missing |
| retro | `RETRO-*.md` exists | N/A |
| qa | `QA-REPORT.md` with passing status | `QA-REPORT.md` with failed status |
| security | `SECURITY.md` with no critical findings | `SECURITY.md` with unresolved findings |
| deploy | `DEPLOY-RECEIPT.md` + app accessible | `DEPLOY-RECEIPT.md` but status unknown |

Rules:

- Only mark `completed` with high-confidence findings.
- Medium-confidence findings -> `partial`.
- Low-confidence findings -> leave as `pending`.
- Include `confidence` and `findings` fields for non-pending phases.

Set `current_phase` to the earliest `partial` phase. If no partial
phases, set it to the earliest `pending` phase that follows a
`completed` phase.

## Step 4: Present Findings

Present findings grouped by category with confidence-appropriate
framing:

```text
I've analyzed your codebase. Here's what I found:

## Tech Stack
- Language: TypeScript (high confidence)
- Framework: Express.js (high confidence)
- Database: PostgreSQL (medium -- DATABASE_URL in .env.example)

## Commands
- Test: `npm test` (confirmed in CI)
- Build: `npm run build` (confirmed in CI)
- Lint: `npm run lint` (confirmed in CI)

## Infrastructure
- CI: GitHub Actions
- Deploy: Fly.io (fly.toml + deploy workflow)

## Pipeline Status
- Setup: COMPLETE (high confidence)
- Build: PARTIAL (source + tests exist, not executed)
- All other phases: PENDING

## Questions (low-confidence findings)
- .env.example lists REDIS_URL but no Redis client in dependencies.
  Do you use Redis?
```

Rules:

- High-confidence findings: stated as facts, no hedging.
- Medium-confidence findings: stated with caveats.
- Low-confidence findings: stated as questions to the user.
- Do NOT dump raw file contents -- summarize.

## Step 5: CLAUDE.md Generation

Claim mode CLAUDE.md generation has two parts: (a) Factory-owned
process rules, and (b) claim-specific project sections derived from
the codebase analysis.

### Part A: Process Rules

Write the Factory-owned process-rules sections using the template in
`process-rules-template.md` and the marker logic described in the main
SKILL.md's "CLAUDE.md Generation (Process Rules)" section. Gate on the
`update_project_claude_md` setting:

- **`prompt`** (default): Present the process-rules content and ask the
  user to confirm.
- **`auto`**: Write without confirmation.
- **`skip`**: Skip process-rules entirely. Proceed to Part B.

If `update_project_claude_md` is `skip`, Part B still runs -- only the
Factory-owned process rules are skipped.

### Part B: Claim-Specific Project Sections

After writing (or skipping) process rules, propose claim-specific
project sections derived from the codebase analysis. These sections
capture what was discovered about the project and are placed outside
the Factory markers.

**If no CLAUDE.md exists** (and Part A was skipped): Create the file
with a `# [Project Name]` heading, then append the claim-specific
sections.

**If CLAUDE.md already exists**: Read it, identify gaps, and propose
changes using this format:

```text
Your CLAUDE.md already has [X sections]. I'd like to propose:

ADD:
- Commands section with test/build/lint commands
- Deployment section with Fly.io config

UPDATE:
- Architecture section: add database component

KEEP AS-IS:
- Project Summary (looks accurate)
- Code Conventions (already comprehensive)

Apply these changes? [Y / show diff / edit / skip]
```

If the user says "show diff", present the full proposed content with
change markers. If "edit", enter the feedback loop. If "skip", do not
touch CLAUDE.md. If "Y", apply changes.

**Claim-specific sections structure**:

```markdown
## Development

### Commands
- **Test**: `[command]`
- **Build**: `[command]`
- **Lint**: `[command]`
- **Format**: `[command]`
- **Start (dev)**: `[command]`

### Code Conventions
- [Convention from linter/formatter config]

## Deployment
- **Platform**: [platform]
- **Environments**: [list]
- **Deploy command**: `[command]`

## Environment Variables
| Variable | Purpose | Required |
|----------|---------|----------|
| [VAR] | [purpose] | [yes/no] |
```

Content rules:

- Every section must have concrete values, not placeholders. If unknown,
  omit the section.
- Commands must be verified against the package manifest or CI config.
  Do not guess commands.
- Code conventions extracted from tooling config, not invented.
- Environment variables from `.env.example` if it exists.
- Do NOT write project summary, architecture, technical standards, quality
  standards, or key features -- those are `/spec`'s responsibility.

## Step 6: Feedback Loop

After proposing CLAUDE.md, iterate with the user:

1. User provides feedback ("add X", "remove Y", "change Z").
2. Incorporate feedback into the proposal.
3. Present the updated proposal.
4. Ask for confirmation.
5. Repeat until user confirms.

If the user has provided feedback 3+ times, ask: "Are we close, or
should we take a different approach?"

## Step 7: Write and Handoff

1. Write `CLAUDE.md` if confirmed (new or modified).
2. Update `.factory/state.json` with `claimed: true`, `claimed_at`,
   and `claim_confidence` summary.
3. Present the handoff:

```text
Claim complete. Your project is ready for the Factory pipeline.

Pipeline status:
- Setup: COMPLETE
- Build: PARTIAL (source exists, tests not verified)
- All other phases: PENDING

Recommended next step: /genesis to continue from [current_phase].
Or run any skill independently: /qa, /security, /spec, etc.
```

## Claim Anti-Patterns

- **Running test suites or build commands.** Claim reads files, never
  executes code. No `npm test`, `pytest`, `go build`. Test verification
  is `/qa`'s job.
- **Writing CLAUDE.md without confirmation.** Always present, get
  explicit user approval, then write.
- **Marking phases `completed` without high confidence.** Medium
  confidence -> `partial`. Low confidence -> `pending`.
- **Inventing commands.** If you cannot find a test command in the
  manifest or CI config, do not guess. Ask the user or omit it.
- **Reading every file in the repo.** Read specific files and patterns
  per the five layers. Directory tree at depth 3 and targeted reads are
  sufficient.
- **Backfilling spec artifacts.** Claim does NOT generate `SPEC.md`,
  `IDEATION.md`, or any skill output. It only detects whether they
  exist.
- **Treating `partial` as `completed`.** A partial phase has gaps. The
  orchestrator should surface them and let the user decide.
