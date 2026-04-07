# /setup — Project Scaffolding, CI/CD, and Infrastructure

The `/setup` skill creates the foundational project structure, continuous integration
pipeline, deployment infrastructure, and telemetry scaffold. It runs BEFORE `/build` so
that agents have a working, tested, deployable skeleton from the start. Every file it
generates must pass linting, build, and test on first run.

## Contract

| Aspect | Detail |
|--------|--------|
| **Required inputs** | `SPEC.md`, `CLAUDE.md` |
| **Optional inputs** | Prototype decisions in `SPEC.md` |
| **Outputs** | Project scaffold, CI/CD pipeline, infra config, `.factory/deploy-config.json` |
| **Failure mode** | Partial scaffold with manual steps documented |

If `SPEC.md` or `CLAUDE.md` is missing, the skill aborts with a clear message.

If `SPEC.md` contains a `## Prototype Decisions` section, the skill uses the selected
approach to inform scaffold structure.

## Category

Procedural skill — executes a defined sequence of steps without user interaction beyond
the initial invocation. No sub-agents are spawned.

## Process

Seven steps, in order:

### Step 1: Read Inputs

Parse `SPEC.md` and `CLAUDE.md` to extract: tech stack, project name, domain
decomposition, deployment target, external dependencies, and architectural decisions.

### Step 2: Project Scaffold

Create directory structure based on tech stack: source directories matching domain
decomposition, test directories mirroring source, configuration files, dependency
manifest, `.gitignore`, and `.env.example` with placeholder values only.

Every generated source file must be minimal but valid. Test files must contain at least
one passing test.

### Step 3: CI/CD Pipeline

Generate two GitHub Actions workflows:

- **`.github/workflows/ci.yml`** — lint, type check, test, build on push/PR to main
- **`.github/workflows/deploy.yml`** — three-environment deployment (alpha, staging,
  prod) via `workflow_dispatch` and `repository_dispatch`, with Fly.io deploy steps,
  health checks, and auto-rollback on prod failure

Replace all placeholder comments with actual stack-specific commands.

### Step 4: Deployment Infrastructure

Default bias is Fly.io. Create three environments with separate Fly apps.

#### 4a-4b. Fly Apps and Configs

Provision `{app}-alpha`, `{app}-staging`, and `{app}` apps. Generate three `fly.toml`
variants sharing a common base structure with per-environment overrides:

| File | `app` | `min_machines_running` | `interval` | Notes |
|---|---|---|---|---|
| `fly.alpha.toml` | `{app}-alpha` | 0 | 30s | Auto-stops when idle |
| `fly.staging.toml` | `{app}-staging` | 1 | 15s | Mirrors prod exactly |
| `fly.toml` | `{app}` | 1 | 15s | Production config |

#### 4c. Dockerfile

Multi-stage build pattern (builder + minimal runtime). Shared across all environments.
See `references/stack-patterns.md` for base image and build details per language.

#### 4d. Health Check Endpoint

`GET /health` returning `200 OK` with JSON body (version, environment, uptime).

#### 4e. Secrets Management

Separate secrets per environment via `fly secrets set -a {app}-{env}`.

#### 4f. Promotion Path

```text
alpha  -->  staging  -->  prod
        QA passes     security clears + user confirms
```

#### 4g. Deployment Manifest

Write `.factory/deploy-config.json` — the machine-readable source of truth that
`/deploy` reads. Contains platform, project name, internal port, health check path,
and per-environment config (app name, region, config file, deploy command, URL).

### Step 5: Telemetry Scaffold

Default bias is OpenTelemetry: SDK initialization, trace propagation, metric collection,
structured logging (JSON with trace correlation), stdout exporter for dev, OTLP exporter
for prod.

### Step 6: Update CLAUDE.md

Append concrete, copy-pasteable commands: build, test, lint, format, type check, dev
server, deploy (per environment), promote, environment setup, secrets management,
telemetry verification. Every command must be exact.

### Step 7: Verify

Run the scaffold end-to-end: dependency install, lint, format, type check, tests, build,
Docker build. Fix failures before reporting success.

## State Tracking

Update `.factory/state.json` on start (`in_progress`), completion (`completed` with
output list), or failure (`failed` with reason).

## Stack-Specific Patterns

See `skills/setup/references/stack-patterns.md` for per-language tooling choices
(Node.js/TypeScript, Python, Rust, Go, and other stacks).

## Anti-Patterns

- **Over-scaffold.** Generate what the spec calls for, not a kitchen-sink template.
- **Hardcode secrets.** `.env.example` has placeholders only; real secrets go in
  `fly secrets set` per environment.
- **Skip verification.** A scaffold that fails its own checks is worse than none.
- **Ignore domain decomposition.** If the spec defines three domains, scaffold three
  source directories.
- **Generate dead configuration.** Every config file must be referenced by a command
  in `CLAUDE.md`.
- **Copy prototype code.** Use architectural decisions, not prototype source code.
- **Leave CLAUDE.md commands vague.** Every command must be exact and copy-pasteable.
- **Deploy to prod without the full promotion path.** Code flows through alpha and
  staging first.
