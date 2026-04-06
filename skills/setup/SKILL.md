---
name: setup
description: Use when the user wants to "set up the project", "scaffold", "create project", "set up CI", "configure deployment", "project setup", or when a spec exists and the project needs its foundational structure, CI/CD pipeline, deployment infrastructure, and telemetry scaffold created before building.
---

# /setup — Project Scaffolding, CI/CD, and Infrastructure

Create the foundational project structure, CI pipeline, deployment infrastructure, and
telemetry scaffold. This skill runs BEFORE `/build` so that agents start with a working,
tested, deployable skeleton. Every file generated must pass linting, build, and test on
first run — a scaffold that does not verify is a scaffold that will be debugged during
`/build`.

## Contract

| Aspect              | Detail                                                    |
|---------------------|-----------------------------------------------------------|
| **Required inputs** | `SPEC.md`, `CLAUDE.md`                                    |
| **Optional inputs** | Prototype decisions in `SPEC.md`                          |
| **Outputs**         | Project scaffold, CI/CD pipeline, infra config            |
| **Failure mode**    | Partial scaffold with manual steps documented             |

**Required inputs** must exist before this skill runs. If `SPEC.md` is missing, abort
with a clear message directing the user to run `/spec` first. If `CLAUDE.md` is missing,
abort — you need build commands, conventions, and project context.

**Optional inputs** enhance the output. If `SPEC.md` contains a
`## Prototype Decisions` section, use the selected approach and its
architectural implications to inform scaffold structure.

**On success**: produce a fully functional project scaffold with source and test
directories, dependency manifests, linter/formatter/type-checker configuration, CI/CD
workflows, deployment configuration, telemetry initialization, and an updated `CLAUDE.md`
with concrete commands.

**On failure**: if any step cannot complete (e.g., dependency installation fails, Docker
build fails), write what you accomplished and document the remaining manual steps as a
checklist in the terminal output. Never leave a half-configured project without
explanation.

## Process

Follow these seven steps in order. Do not skip steps. Do not reorder.

### Skill Parameters

Read and execute ALL [MANDATORY] sections in [GLOBAL-REFERENCE.md](GLOBAL-REFERENCE.md):

- `{PHASE_NAME}` = `setup`
- `{OUTPUT_FILES}` = `["fly.toml", "fly.alpha.toml", "fly.staging.toml",
  "Dockerfile", ".github/workflows/ci.yml",
  ".github/workflows/deploy.yml", ".factory/deploy-config.json"]`

### Step 1: Read Inputs

Parse `SPEC.md` and `CLAUDE.md` to extract:

- Tech stack and language version
- Project name and structure
- Domain decomposition (maps to source directories)
- Deployment target and region
- External dependencies and services
- Architectural decisions from prototype phase (if any)

If the spec references multiple domains, the scaffold must mirror that decomposition in
its directory structure. Do not flatten what the spec separates.

### Step 2: Project Scaffold

Create the directory structure based on tech stack:

- **Source directories** matching domain decomposition from the spec
- **Test directories** mirroring source structure
- **Configuration files** for linter, formatter, type checker
- **Dependency manifest** (`package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`,
  etc.) with correct dependencies and versions
- **`.gitignore`** appropriate to the stack
- **`.env.example`** with all required environment variables documented — no real
  secrets, only placeholder values with comments explaining each variable

Every generated source file must be minimal but valid. Skeleton modules should export
placeholder types or functions that downstream code can import. Test files should contain
at least one passing test that verifies the skeleton compiles and runs.

### Step 3: CI/CD Pipeline

Generate two GitHub Actions workflow files.

#### `.github/workflows/ci.yml`

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install dependencies
        run: # stack-specific install command
      - name: Lint
        run: # stack-specific lint command
      - name: Type check
        run: # stack-specific type check command (if applicable)
      - name: Test
        run: # stack-specific test command with coverage
      - name: Build
        run: # stack-specific build command
```

Replace every `# stack-specific` comment with the actual command for the project's tech
stack. Do not leave placeholder comments in generated workflow files.

#### `.github/workflows/deploy.yml`

```yaml
name: Deploy

on:
  workflow_dispatch:
    inputs:
      target:
        description: "Deployment target environment"
        required: true
        type: choice
        options:
          - alpha
          - staging
          - prod
  repository_dispatch:
    types: [deploy-alpha, deploy-staging, deploy-prod]

jobs:
  deploy-alpha:
    if: >
      (github.event_name == 'workflow_dispatch'
        && github.event.inputs.target == 'alpha')
      || (github.event_name == 'repository_dispatch'
        && github.event.action == 'deploy-alpha')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: superfly/flyctl-actions/setup-flyctl@master
      - name: Deploy to alpha
        run: flyctl deploy --remote-only -c fly.alpha.toml
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
      - name: Health check
        run: |
          sleep 5
          curl -sf https://$APP_NAME-alpha.fly.dev/health \
            || echo "::warning::Alpha health check failed"

  deploy-staging:
    if: >
      (github.event_name == 'workflow_dispatch'
        && github.event.inputs.target == 'staging')
      || (github.event_name == 'repository_dispatch'
        && github.event.action == 'deploy-staging')
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4
      - uses: superfly/flyctl-actions/setup-flyctl@master
      - name: Deploy to staging
        run: flyctl deploy --remote-only -c fly.staging.toml
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
      - name: Health check
        run: |
          sleep 5
          curl -sf https://$APP_NAME-staging.fly.dev/health

  deploy-prod:
    if: >
      (github.event_name == 'workflow_dispatch'
        && github.event.inputs.target == 'prod')
      || (github.event_name == 'repository_dispatch'
        && github.event.action == 'deploy-prod')
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - uses: superfly/flyctl-actions/setup-flyctl@master
      - name: Deploy to prod
        run: flyctl deploy --remote-only -c fly.toml
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
      - name: Health check
        run: |
          sleep 5
          curl -sf https://$APP_NAME.fly.dev/health
      - name: Auto-rollback on failure
        if: failure()
        run: |
          PREV=$(flyctl releases -c fly.toml --json \
            | jq -r '.[1].Version')
          flyctl deploy --image-ref "$PREV" -c fly.toml --remote-only
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

Replace `$APP_NAME` with the actual project name from the spec. The `staging` and
`production` environments should be configured in GitHub repository settings with
appropriate protection rules (required reviewers, wait timers).

Adapt all commands to the actual tech stack. These templates are starting points — the
real commands come from Step 1.

### Step 4: Deployment Infrastructure

Default deployment target is Fly.io. If the spec specifies a different target, adapt
accordingly. The Fly.io configuration below is the default, not a mandate.

#### 4a. Create Fly Apps

Provision three separate Fly apps:

```bash
fly apps create {app}-alpha
fly apps create {app}-staging
fly apps create {app}
```

Where `{app}` is the project name from the spec. If any app already exists, skip it with
a warning rather than failing.

#### 4b. Generate Deployment Configs

Generate three `fly.toml` variants sharing a common base structure:

```toml
app = "{app}"
primary_region = "iad"

[build]

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = "stop"
  auto_start_machines = true
  min_machines_running = 1

[[vm]]
  size = "shared-cpu-1x"
  memory = "256mb"

[checks]
  [checks.health]
    type = "http"
    port = 8080
    path = "/health"
    interval = "15s"
    timeout = "5s"
```

Per-environment overrides:

| File | `app` | `min_machines_running` | `interval` | Notes |
|---|---|---|---|---|
| `fly.alpha.toml` | `{app}-alpha` | 0 | 30s | Auto-stops when idle to save costs |
| `fly.staging.toml` | `{app}-staging` | 1 | 15s | Mirrors prod exactly |
| `fly.toml` | `{app}` | 1 | 15s | Production config |

Replace `{app}` with the actual project name. Adjust `primary_region`, `internal_port`,
and VM sizing based on what the spec requires.

#### 4c. Dockerfile

Generate a `Dockerfile` using multi-stage build pattern (builder stage + minimal runtime
stage). A single Dockerfile is shared across all three environments — the `fly.*.toml`
files control which app the image deploys to. See `references/stack-patterns.md` for
base image and build command details per language.

#### 4d. Health Check Endpoint

Add a health check endpoint in the application scaffold: `GET /health` returning
`200 OK` with a JSON body including `version`, `environment`, and `uptime`. This
endpoint is referenced by the Fly.io health checks and the deploy workflow.

#### 4e. Secrets Management

Set up separate secrets per environment. Each environment gets its own set so that
staging and alpha never touch prod credentials:

```bash
# Alpha
fly secrets set -a {app}-alpha DATABASE_URL="..." SOME_API_KEY="..."

# Staging (mirrors prod values where possible)
fly secrets set -a {app}-staging DATABASE_URL="..." SOME_API_KEY="..."

# Prod
fly secrets set -a {app} DATABASE_URL="..." SOME_API_KEY="..."
```

Document the required secrets list in `CLAUDE.md` with placeholder values and
instructions for each environment.

#### 4f. Three-Environment Promotion Path

The environments form a linear promotion pipeline:

```text
alpha  -->  staging  -->  prod
        QA passes     security clears + user confirms
```

- **Alpha to staging**: Promote after `/qa` passes. The staging deploy uses the same
  image/commit that was validated in alpha.
- **Staging to prod**: Promote after `/security` clears. Requires explicit user
  confirmation before the deploy workflow runs. Prod deploys include automatic rollback
  if the health check fails.

Document this promotion path in `CLAUDE.md` so agents and users understand the flow.
Direct-to-prod deploys bypass QA and security checks and are never acceptable.

#### 4g. Deployment Manifest

Write `.factory/deploy-config.json` capturing all deployment configuration in a
single machine-readable file. This is the source of truth that `/deploy` reads
to know what to deploy, where, and how. The CLAUDE.md deployment section is
derived from this file.

```json
{
  "platform": "fly.io",
  "project_name": "{app}",
  "internal_port": 8080,
  "health_check_path": "/health",
  "environments": {
    "alpha": {
      "app_name": "{app}-alpha",
      "region": "iad",
      "config_file": "fly.alpha.toml",
      "deploy_command": "fly deploy -c fly.alpha.toml",
      "url": "https://{app}-alpha.fly.dev"
    },
    "staging": {
      "app_name": "{app}-staging",
      "region": "iad",
      "config_file": "fly.staging.toml",
      "deploy_command": "fly deploy -c fly.staging.toml",
      "url": "https://{app}-staging.fly.dev"
    },
    "prod": {
      "app_name": "{app}",
      "region": "iad",
      "config_file": "fly.toml",
      "deploy_command": "fly deploy -c fly.toml",
      "url": "https://{app}.fly.dev"
    }
  },
  "rollback_command": "fly releases rollback --app {app_name}",
  "secrets_command": "fly secrets list --app {app_name}"
}
```

Replace all `{app}` placeholders with the actual project name. Adjust region,
port, and URLs based on what the spec requires. If the deployment platform is
not Fly.io, adapt the schema to the actual platform (the structure stays the
same — platform, environments, commands, URLs).

This file must be written before Step 6 (Update CLAUDE.md) so that the
CLAUDE.md deployment section can reference it.

### Step 5: Telemetry Scaffold

Default bias is OpenTelemetry. Set up:

- **OTel SDK initialization** in the application entry point
- **Trace context propagation** configuration
- **Metric collection** for key operations (request duration, error count, active
  connections)
- **Structured logging** configuration (JSON format with trace correlation)
- **Export configuration**: stdout exporter for development, OTLP exporter for
  production (switchable via `OTEL_EXPORTER_OTLP_ENDPOINT` environment variable)

The telemetry scaffold must not add overhead to development. In dev mode, traces and
metrics should print to stdout in a human-readable format. In production, they export
to a collector endpoint configured via environment variable.

### Step 6: Update CLAUDE.md

Append concrete, copy-pasteable commands to `CLAUDE.md`. Do not overwrite existing
content. Append a `## Commands` section (or update it if one already exists).

Every command must be exact. "Run the tests" is not a command. `pnpm test` is.

Required entries:

- **Build**: exact command to compile/build the project
- **Test**: exact command to run tests (with and without coverage)
- **Lint**: exact command to run the linter
- **Format**: exact command to run the formatter
- **Type check**: exact command to run the type checker (if applicable)
- **Dev server**: exact command to start the development server
- **Deploy alpha**: `fly deploy -c fly.alpha.toml`
- **Deploy staging**: `fly deploy -c fly.staging.toml`
- **Deploy prod**: `fly deploy -c fly.toml`
- **Promote alpha to staging**: instructions or command to trigger staging deploy after
  QA passes
- **Promote staging to prod**: instructions or command to trigger prod deploy after
  security clears (including user confirmation step)
- **Environment setup**: step-by-step instructions to go from clone to running
- **Secrets management**: commands to set secrets per environment
  (`fly secrets set -a {app}-alpha ...`, etc.)
- **Telemetry verification**: command to verify traces/metrics are flowing

### Step 7: Verify

Run the scaffold end-to-end. Every check must pass before reporting success:

1. Dependencies install successfully (no resolution errors)
2. Linter passes on all generated code
3. Formatter reports no changes needed
4. Type checker passes (if applicable)
5. All skeleton tests pass
6. Build produces an artifact
7. Docker builds successfully (if Dockerfile was generated)

If any verification step fails, fix it before reporting success. The scaffold must be
green on first checkout. Report all verification results to the user.

## Stack-Specific Patterns

For stack-specific tooling choices, read `references/stack-patterns.md`.

## Settings

This skill has no configurable settings. Deployment platform,
environment provisioning, and telemetry are project-level decisions
configured in SPEC.md and CLAUDE.md.

## Anti-Patterns

Do not do any of the following:

- **Over-scaffold.** Generate what the spec calls for, not a kitchen-sink template. If
  the spec describes a CLI tool, do not scaffold a web server with React frontend.

- **Hardcode secrets.** The `.env.example` file must contain only placeholder values.
  Real secrets go into deployment platform secret management (e.g., `fly secrets set`).
  Each environment gets its own secrets — never share prod credentials with alpha or
  staging.

- **Skip verification.** A scaffold that does not pass its own linter, tests, and build
  is worse than no scaffold — it teaches agents to ignore failures.

- **Ignore the spec's domain decomposition.** If the spec defines three domains, the
  scaffold must have three corresponding source directories, not a flat `src/` folder.

- **Generate dead configuration.** Every config file must be referenced by a script or
  command in `CLAUDE.md`. If nobody runs it, do not generate it.

- **Copy prototype code.** If `SPEC.md` has prototype decisions, use the
  architectural direction, not prototype source code. Prototype code was
  built without tests, error handling, or security considerations.

- **Leave CLAUDE.md commands vague.** Every command must be exact and copy-pasteable.
  "Run the tests" is not a command. `pnpm test` is.

- **Write unsafe commands in CLAUDE.md.** Commands must be simple and
  single-line. Never write commands that pipe to shell interpreters
  (`curl ... | bash`), download from untrusted URLs, or chain
  destructive operations. CLAUDE.md commands are executed by agents
  without manual review — they must be safe by construction.

- **Deploy to prod without the full promotion path.** Code must flow through alpha and
  staging before reaching prod. Direct-to-prod deploys bypass QA and security checks
  and are never acceptable.
