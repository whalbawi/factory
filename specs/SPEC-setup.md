# /setup — Project Scaffolding, CI/CD, and Infrastructure

The `/setup` skill creates the foundational project structure, continuous integration
pipeline, deployment infrastructure, and telemetry scaffold. It runs BEFORE `/build` so
that agents have a working, tested, deployable skeleton from the start. Every file it
generates must pass linting, build, and test on first run — a scaffold that does not
verify is a scaffold that will be debugged during `/build`.

## Contract

| Aspect | Detail |
|--------|--------|
| **Required inputs** | `SPEC.md`, `CLAUDE.md` |
| **Optional inputs** | `PROTOTYPE-DECISION.md` |
| **Outputs** | Project scaffold, CI/CD pipeline, infra config |
| **Failure mode** | Partial scaffold with manual steps documented |

**Required inputs** must exist before the skill runs. If `SPEC.md` is missing, the skill
aborts with a clear message directing the user to run `/spec` first. If `CLAUDE.md` is
missing, the skill aborts — it needs build commands, conventions, and project context.

**Optional inputs** enhance the output. If `PROTOTYPE-DECISION.md` exists, the skill
uses the selected approach and its architectural implications to inform scaffold
structure.

**Outputs** on success: a fully functional project scaffold with source and test
directories, dependency manifests, linter/formatter/type-checker configuration, CI/CD
workflows, deployment configuration, telemetry initialization, and an updated
`CLAUDE.md` with concrete commands.

**Failure mode**: if any step cannot complete (e.g., dependency installation fails,
Docker build fails), the skill writes what it accomplished and documents the remaining
manual steps as a checklist in the terminal output. It does not leave a half-configured
project without explanation.

## Category

Procedural skill — executes a defined sequence of steps without user interaction beyond
the initial invocation. No sub-agents are spawned. The skill reads its inputs, generates
all artifacts, verifies them, and reports the result.

## Process

### Step 1: Read Inputs

Parse `SPEC.md`, `CLAUDE.md`, and `PROTOTYPE-DECISION.md` (if present) to extract:

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

- Source directories matching domain decomposition from the spec
- Test directories mirroring source structure
- Configuration files (linter, formatter, type checker)
- Dependency manifest (`package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, etc.)
  with correct dependencies and versions
- `.gitignore` appropriate to the stack
- `.env.example` with all required environment variables documented — no real secrets,
  only placeholder values with comments explaining each variable

Every generated source file must be minimal but valid. Skeleton modules should export
placeholder types or functions that downstream code can import. Test files should contain
at least one passing test that verifies the skeleton compiles and runs.

### Step 3: CI/CD Pipeline

Generate GitHub Actions workflows:

```yaml
# .github/workflows/ci.yml
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

```yaml
# .github/workflows/deploy.yml
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

Adapt the workflow to the specific stack. The examples above are templates — the actual
commands come from the tech stack identified in Step 1. The `staging` and `production`
environments should be configured in GitHub repository settings with appropriate
protection rules (required reviewers, wait timers, etc.).

### Step 4: Deployment Infrastructure

Default bias is Fly.io. Create **three deployment environments** with separate Fly apps
and config files:

#### 4a. Create Fly Apps

Run the following to provision all three apps:

```bash
fly apps create {app}-alpha
fly apps create {app}-staging
fly apps create {app}
```

Where `{app}` is the project name from the spec. If any app already exists, skip it
with a warning rather than failing.

#### 4b. Generate Deployment Configs

Generate three `fly.toml` variants — one per environment. Each shares the same base
structure but differs in app name, scaling, and auto-stop behavior.

**Alpha** — `fly.alpha.toml`:

```toml
app = "{app}-alpha"
primary_region = "iad"

[build]

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = "stop"
  auto_start_machines = true
  min_machines_running = 0

[[vm]]
  size = "shared-cpu-1x"
  memory = "256mb"

[checks]
  [checks.health]
    type = "http"
    port = 8080
    path = "/health"
    interval = "30s"
    timeout = "5s"
```

Key differences from prod: `min_machines_running = 0` so the app auto-stops when idle
to save costs, and a longer health check interval.

**Staging** — `fly.staging.toml`:

```toml
app = "{app}-staging"
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

Staging mirrors prod configuration: same region, same VM size, same scaling. This
ensures that anything that passes staging will behave identically in prod.

**Prod** — `fly.toml`:

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

#### 4c. Dockerfile

Generate a `Dockerfile` using multi-stage build pattern (builder stage + minimal
runtime stage). A single Dockerfile is shared across all three environments — the
`fly.*.toml` files control which app the image deploys to.

#### 4d. Health Check Endpoint

Add a health check endpoint in the application scaffold (e.g., `GET /health` returning
`200 OK` with a JSON body including version, environment, and uptime).

#### 4e. Secrets Management

Set up separate secrets per environment. Each environment gets its own set of secrets
so that staging and alpha never touch prod credentials:

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

#### 4f. Promotion Path

The environments form a linear promotion pipeline:

```
alpha  →  staging  →  prod
       /qa passes   /security clears + user confirms
```

- **Alpha to staging**: Promote after `/qa` passes. The staging deploy uses the same
  image/commit that was validated in alpha.
- **Staging to prod**: Promote after `/security` clears. Requires explicit user
  confirmation before the deploy workflow runs. Prod deploys include automatic
  rollback if the health check fails.

Document this promotion path in `CLAUDE.md` so agents and users understand the flow.

If the spec specifies a different deployment target, adapt accordingly. The Fly.io
configuration is the default, not a mandate.

### Step 5: Telemetry Scaffold

Default bias is OpenTelemetry. Set up:

- OTel SDK initialization in the application entry point
- Trace context propagation configuration
- Metric collection for key operations (request duration, error count, active
  connections)
- Structured logging configuration (JSON format with trace correlation)
- Export configuration: stdout exporter for development, OTLP exporter for production
  (switchable via environment variable)

The telemetry scaffold must not add overhead to development. In dev mode, traces and
metrics should print to stdout in a human-readable format. In production, they export to
a collector endpoint configured via `OTEL_EXPORTER_OTLP_ENDPOINT`.

### Step 6: Update CLAUDE.md

Append concrete, copy-pasteable commands to `CLAUDE.md`:

- **Build**: exact command to compile/build the project
- **Test**: exact command to run tests (with and without coverage)
- **Lint**: exact command to run the linter
- **Format**: exact command to run the formatter
- **Type check**: exact command to run the type checker (if applicable)
- **Dev server**: exact command to start the development server
- **Deploy alpha**: exact command to deploy to alpha
  (e.g., `fly deploy -c fly.alpha.toml`)
- **Deploy staging**: exact command to deploy to staging
  (e.g., `fly deploy -c fly.staging.toml`)
- **Deploy prod**: exact command to deploy to prod
  (e.g., `fly deploy -c fly.toml`)
- **Promote alpha to staging**: instructions or command to trigger staging deploy
  after QA passes
- **Promote staging to prod**: instructions or command to trigger prod deploy after
  security clears (including user confirmation step)
- **Environment setup**: step-by-step instructions to go from clone to running
- **Secrets management**: commands to set secrets per environment
  (`fly secrets set -a {app}-alpha ...`, etc.)
- **Telemetry verification**: command to verify traces/metrics are flowing

Do not overwrite existing `CLAUDE.md` content. Append a `## Commands` section (or
update it if one exists).

### Step 7: Verify

Run the scaffold end-to-end:

1. Dependencies install successfully (no resolution errors)
2. Linter passes on all generated code
3. Formatter reports no changes needed
4. Type checker passes (if applicable)
5. All skeleton tests pass
6. Build produces an artifact
7. Docker builds successfully (if Dockerfile was generated)

If any verification step fails, fix it before reporting success. The scaffold must be
green on first checkout. Report all verification results to the user.

## State Tracking

Every skill must update `.factory/state.json` on invocation and completion, even when
run standalone (outside the `/factory` orchestrator).

**On start**: Set the `setup` phase to `in_progress`:

```json
{
  "phases": {
    "setup": {
      "status": "in_progress",
      "started_at": "2026-04-03T12:05:00Z"
    }
  }
}
```

**On completion**: Set the `setup` phase to `completed` with outputs:

```json
{
  "phases": {
    "setup": {
      "status": "completed",
      "started_at": "2026-04-03T12:05:00Z",
      "completed_at": "2026-04-03T13:00:00Z",
      "outputs": [
        "fly.toml",
        "fly.alpha.toml",
        "fly.staging.toml",
        "Dockerfile",
        ".github/workflows/ci.yml",
        ".github/workflows/deploy.yml"
      ]
    }
  }
}
```

**On failure**: Set the `setup` phase to `failed` with reason:

```json
{
  "phases": {
    "setup": {
      "status": "failed",
      "started_at": "2026-04-03T12:05:00Z",
      "failed_at": "2026-04-03T12:30:00Z",
      "failure_reason": "Docker build failed: missing system dependency libssl-dev"
    }
  }
}
```

If `.factory/state.json` does not exist, create it with the standard structure (see
orchestration spec for the full schema). If it exists, update only the `setup` phase
entry — do not modify other phases.

## Stack-Specific Patterns

### Node.js / TypeScript

- **Package manager**: Use whatever the spec or `CLAUDE.md` specifies. Default to
  `pnpm` if no preference is stated.
- **Linter**: ESLint with flat config (`eslint.config.js`). Include
  `@typescript-eslint/parser` and `@typescript-eslint/eslint-plugin`.
- **Formatter**: Prettier with minimal config (printWidth, semi, singleQuote).
- **Type checker**: `tsc --noEmit` (strict mode enabled).
- **Test runner**: Vitest (default) or Jest if specified. Configure coverage with
  `v8` provider.
- **Build**: `tsc` for libraries, bundler (esbuild/vite) for applications.
- **Telemetry**: `@opentelemetry/sdk-node`, `@opentelemetry/auto-instrumentations-node`.
- **Dockerfile**: Node 22 alpine base, multi-stage with `pnpm deploy --prod` or
  equivalent for minimal production image.

### Python

- **Package manager**: `uv` (default) or `pip` if specified. Generate
  `pyproject.toml` with project metadata and dependencies.
- **Linter/formatter**: `ruff` for both linting and formatting. Configure via
  `[tool.ruff]` in `pyproject.toml`.
- **Type checker**: `pyright` or `mypy` (default to `pyright` for stricter defaults).
- **Test runner**: `pytest` with `pytest-cov` for coverage.
- **Build**: `uv build` for packages, direct execution for applications.
- **Telemetry**: `opentelemetry-sdk`, `opentelemetry-instrumentation` with auto-
  instrumentation for common frameworks (FastAPI, Flask, Django).
- **Dockerfile**: Python 3.12 slim base, multi-stage with `uv pip install` in
  builder and copy of virtualenv to runtime.

### Rust

- **Package manager**: `cargo` (standard). Generate `Cargo.toml` with workspace
  layout if the spec has multiple domains.
- **Linter**: `clippy` with `-- -D warnings` to treat warnings as errors.
- **Formatter**: `rustfmt` with default settings.
- **Test runner**: `cargo test`. Use `cargo-llvm-cov` for coverage if specified.
- **Build**: `cargo build --release`. Use workspace members for multi-crate projects.
- **Telemetry**: `tracing` crate with `tracing-opentelemetry` bridge and
  `opentelemetry-otlp` exporter.
- **Dockerfile**: `rust:1.82-slim` builder, `debian:bookworm-slim` runtime.
  Statically link with `musl` for alpine if binary size is a concern.

### Go

- **Package manager**: Go modules (`go mod init`). Generate `go.mod` with correct
  module path.
- **Linter**: `golangci-lint` with a `.golangci.yml` config enabling `govet`,
  `staticcheck`, `errcheck`, `gosec`, and `unused` at minimum.
- **Formatter**: `gofmt` (standard, no configuration needed).
- **Test runner**: `go test ./...` with `-race` flag. Use `-coverprofile` for coverage.
- **Build**: `go build -o bin/` with appropriate `ldflags` for version embedding.
- **Telemetry**: `go.opentelemetry.io/otel` SDK with `otlptracehttp` exporter and
  `otelhttp` middleware for HTTP servers.
- **Dockerfile**: `golang:1.23-alpine` builder, `alpine:3.20` runtime. Build with
  `CGO_ENABLED=0` for static binary.

### Other Stacks

For stacks not listed above, the skill adapts based on spec constraints. It follows the
same pattern: identify the canonical package manager, linter, formatter, type checker
(if applicable), test runner, and build tool. When in doubt, use the most widely adopted
tooling for that ecosystem.

## Anti-Patterns

- **Do not over-scaffold.** Generate what the spec calls for, not a kitchen-sink
  template. If the spec describes a CLI tool, do not scaffold a web server with React
  frontend.

- **Do not hardcode secrets.** The `.env.example` file must contain only placeholder
  values. Real secrets go into deployment platform secret management (e.g.,
  `fly secrets set`). Each environment gets its own secrets — never share prod
  credentials with alpha or staging.

- **Do not skip verification.** A scaffold that does not pass its own linter, tests,
  and build is worse than no scaffold — it teaches agents to ignore failures.

- **Do not ignore the spec's domain decomposition.** If the spec defines three domains,
  the scaffold must have three corresponding source directories, not a flat `src/`
  folder.

- **Do not generate dead configuration.** Every config file must be referenced by a
  script or command in `CLAUDE.md`. If nobody runs it, do not generate it.

- **Do not copy prototype code.** If `PROTOTYPE-DECISION.md` exists, use its
  architectural decisions, not its source code. Prototype code was built without tests,
  error handling, or security considerations.

- **Do not leave the CLAUDE.md commands section vague.** Every command must be exact
  and copy-pasteable. "Run the tests" is not a command. `pnpm test` is.

- **Do not deploy to prod without the full promotion path.** Code must flow through
  alpha and staging before reaching prod. Direct-to-prod deploys bypass QA and
  security checks and are never acceptable.
