# /deploy — Ship to Alpha, Staging, or Production

The `/deploy` skill takes source code and ships it to one of three environments:
alpha, staging, or production. It follows a promotion model where code moves
through environments as it clears successive gates. The skill verifies
prerequisites for the target environment, executes the deployment, confirms the
application is healthy, and produces a receipt documenting exactly what was
deployed and how it went. For production, if anything goes wrong post-deploy, it
rolls back automatically — a broken production deployment must never stay live.

## Environments

The deploy skill operates across three environments in a promotion chain:

| Environment | App Name | Deploy Command | Gates Required |
|-------------|----------|----------------|----------------|
| **Alpha** | `{app}-alpha` | `fly deploy --app {app}-alpha` | None (opt-in) |
| **Staging** | `{app}-staging` | `fly deploy --app {app}-staging` | QA pass |
| **Prod** | `{app}` | `fly deploy --app {app}` | QA pass + security clear |

- **Alpha** is for development validation. Agents may deploy here during
  `/build` without any gate checks. No smoke tests or health checks are
  enforced.
- **Staging** mirrors production configuration and is promoted from alpha after
  `/qa` passes. Smoke tests run here to catch issues before prod.
- **Prod** is the live environment. Promotion from staging requires `/security`
  clearance and explicit user confirmation. Full health checks and automatic
  rollback are enforced.

## Contract

**Required inputs**:

- Source code passing all gates required for the target environment
- Infrastructure configuration (`fly.toml`, `Dockerfile`, or equivalent)
- Target environment: `alpha`, `staging`, or `prod` (default: `prod`)

**Optional inputs**:

- `QA-REPORT.md` — used to verify QA gate status (required for staging and prod)
- `SECURITY.md` — used to verify security gate status (required for prod)

**Outputs**:

- `DEPLOY-RECEIPT.md` — deployment record with status, environment, health
  checks, and smoke test results

**Failure output**:

- `DEPLOY-RECEIPT.md` with `status: FAILED` or `status: ROLLED BACK`, including
  diagnostics and the failure point

## Category

Procedural skill — executes a defined sequence of steps with no user interaction
beyond the initial invocation (except for prod confirmation). No sub-agents are
spawned.

## Process

### Step 1: Gate Verification

Check that all prerequisites are met for the target environment:

**Alpha** — no gates required. Skip this step entirely.

**Staging**:

- `QA-REPORT.md` exists with status `PASS` or `PASS WITH WARNINGS`. If the
  file is missing or status is not passing, halt and report — do not deploy.
- All CI checks passing on the main branch. Verify via `gh run list` or
  equivalent.

**Prod**:

- `QA-REPORT.md` exists with status `PASS` or `PASS WITH WARNINGS`. If the
  file is missing or status is not passing, halt and report — do not deploy.
- `SECURITY.md` exists with status `CLEAR` or `WARNINGS` (not `BLOCKED`). If
  the file is missing, halt and report. If status is `BLOCKED`, halt and
  report — do not deploy.
- All CI checks passing on the main branch. Verify via `gh run list` or
  equivalent.
- No unmerged PRs that are marked as deploy blockers.
- **Explicit user confirmation** is required before proceeding.

If any hard gate fails (security `BLOCKED`, QA not passing, or CI failing),
stop immediately. Write `DEPLOY-RECEIPT.md` with `status: FAILED` and the
reason, then exit.

### Step 2: Pre-Deploy Checklist

Verify the deployment environment is ready:

- Environment variables are set for the target environment
  (`fly secrets list --app {app-name}` or equivalent)
- Required secrets are configured — never log or echo secret values
- Database migrations are ready and tested (if applicable)
- For staging and prod: capture the current deployed version before proceeding
  (rollback plan)

### Step 3: Deploy (Fly.io Default)

Execute the deployment to the target environment:

- Run `fly deploy --app {app-name}` from the project root, where `{app-name}`
  is `{app}-alpha`, `{app}-staging`, or `{app}` depending on the target
- Monitor deployment progress via `fly deploy` output
- For staging and prod: wait for Fly.io's built-in health checks to pass
- If the platform is not Fly.io, adapt to the configured deployment target
  (the deployment command should be documented in `CLAUDE.md`)

### Step 4: Post-Deploy Verification

Post-deploy verification depends on the target environment:

**Alpha** — no verification required. The deploy is complete once `fly deploy`
succeeds.

**Staging**:

- Hit the health check endpoint and verify a 200 response
- Run smoke tests — a subset of acceptance tests executed against the staging
  URL
- Verify telemetry is flowing (check that traces/metrics appear in the
  collector)

**Prod**:

- Hit the health check endpoint and verify a 200 response
- Run smoke tests — a subset of acceptance tests executed against the
  production URL
- Verify telemetry is flowing (check that traces/metrics appear in the
  collector)
- Check error rates are within normal bounds (no spike compared to pre-deploy
  baseline)

If any verification step fails on prod, proceed to automatic rollback (see
Rollback section below). If verification fails on staging, record the failure
and notify the user.

### Step 5: Output

Write `DEPLOY-RECEIPT.md` with the full deployment record. See the Output
Template section for the exact format.

## Promotion

Code flows through environments via a promotion model:

### Alpha to Staging

- **Trigger**: `/qa` skill completes with status `PASS` or `PASS WITH WARNINGS`
- **Action**: The deploy skill is invoked with `target: staging`
- **Automatic**: Once QA passes, promotion to staging proceeds without manual
  intervention

### Staging to Prod

- **Trigger**: `/security` skill completes with status `CLEAR` or `WARNINGS`
- **Gate**: Explicit user confirmation is required before deploying to prod
- **Action**: The deploy skill is invoked with `target: prod`
- **Manual**: The user must confirm they want to proceed to production

The promotion chain ensures that code reaching production has been validated in
alpha, tested by QA in staging, and cleared by security before going live.

## State Tracking

Every skill must update `.factory/state.json` on invocation and completion,
even when invoked standalone outside the `/genesis` orchestrator pipeline. If
`.factory/state.json` does not exist, create it.

**On start** — set the deploy phase to `in_progress`:

```json
{
  "phases": {
    "deploy": {
      "status": "in_progress",
      "target_environment": "prod",
      "started_at": "2026-04-03T14:00:00Z"
    }
  }
}
```

**On successful completion** — set the deploy phase to `completed`:

```json
{
  "phases": {
    "deploy": {
      "status": "completed",
      "target_environment": "prod",
      "started_at": "2026-04-03T14:00:00Z",
      "completed_at": "2026-04-03T14:12:00Z",
      "outputs": ["DEPLOY-RECEIPT.md"]
    }
  }
}
```

**On failure** — set the deploy phase to `failed`:

```json
{
  "phases": {
    "deploy": {
      "status": "failed",
      "target_environment": "prod",
      "started_at": "2026-04-03T14:00:00Z",
      "failed_at": "2026-04-03T14:08:00Z",
      "failure_reason": "Health check returned 503 after deploy; rolled back to v42",
      "outputs": ["DEPLOY-RECEIPT.md"]
    }
  }
}
```

When updating an existing `state.json`, merge into the existing structure — do
not overwrite other phases or top-level fields.

## Rollback

Rollback behavior depends on the target environment:

### Prod — Automatic Rollback

If any post-deploy health check or smoke test fails on prod:

1. **Immediately roll back** — run `fly releases rollback --app {app}` (or the
   equivalent for the configured platform). Do not wait for manual
   intervention.
2. **Verify rollback** — hit the health check endpoint again to confirm the
   previous version is serving.
3. **Record in receipt** — set `DEPLOY-RECEIPT.md` status to `ROLLED BACK` with
   the failure reason, the version rolled back to, and the diagnostic output.
4. **Update state** — set `.factory/state.json` deploy phase to `failed` with
   the `failure_reason` explaining what went wrong and that rollback was
   performed.

A broken production deployment must never stay live. If the rollback itself
fails, document that in the receipt and escalate to the user with clear next
steps.

### Staging — Manual Rollback

If post-deploy verification fails on staging:

1. **Record the failure** in `DEPLOY-RECEIPT.md` with `status: FAILED` and
   diagnostic details.
2. **Notify the user** with the failure details and the rollback command:
   `fly releases rollback --app {app}-staging`.
3. **Do not auto-rollback** — staging failures are not user-facing, so the user
   decides whether to roll back or investigate further.

### Alpha — No Rollback

Alpha deployments have no rollback mechanism. If a deploy to alpha fails or
the app is unhealthy, the next `/build` cycle will deploy a new version. Record
the failure in the deploy receipt but take no rollback action.

## Output Template

```markdown
# Deployment Receipt — [Date]

## Deployment
- **Status**: SUCCESS / FAILED / ROLLED BACK
- **Version**: [git commit SHA]
- **Previous version**: [git commit SHA]
- **Environment**: alpha / staging / prod
- **App name**: [app name used in deploy command]
- **Platform**: Fly.io
- **Region**: [region]
- **Deployed at**: [ISO 8601 timestamp]

## Gate Checks
| Gate | Required | Status | Notes |
|------|----------|--------|-------|
| QA Report | YES (staging/prod) / NO (alpha) | PASS / WARN / MISSING / SKIPPED | [details] |
| Security Report | YES (prod) / NO (alpha/staging) | CLEAR / WARN / MISSING / SKIPPED | [details] |
| CI Checks | YES (staging/prod) / NO (alpha) | PASS / FAIL / SKIPPED | [details] |
| User Confirmation | YES (prod) / NO (alpha/staging) | CONFIRMED / SKIPPED | [details] |

## Health Checks
| Endpoint | Status | Response Time | Expected |
|----------|--------|---------------|----------|
| /health | 200 | 45ms | 200 |

_(Skipped for alpha deployments.)_

## Smoke Tests
| Test | Status | Notes |
|------|--------|-------|
| [test name] | PASS / FAIL | [details] |

_(Skipped for alpha deployments.)_

## Telemetry
- **Traces flowing**: YES / NO / SKIPPED
- **Error rate**: [percentage] (baseline: [percentage])

## Rollback Info
- **Previous version**: [commit SHA]
- **Rollback command**: `fly releases rollback --app {app-name}`
- **Rollback behavior**: AUTOMATIC (prod) / MANUAL (staging) / N/A (alpha)
- **Rollback performed**: YES / NO / N/A
- **Rollback reason**: [if applicable]

## Diagnostics
[If status is FAILED or ROLLED BACK, include relevant logs, error messages,
and the exact step where failure occurred.]
```

## Anti-Patterns

- **Deploying past a BLOCKED security gate.** Never override a `BLOCKED` status
  from `SECURITY.md`. If security found critical issues, they must be fixed
  first.
- **Skipping post-deploy verification on staging or prod.** A deploy without
  health checks is not a deploy — it is a hope. Always verify on staging and
  prod.
- **Leaving a broken production deployment live.** If health checks fail on
  prod, roll back immediately. Do not "wait and see" or "give it a minute."
- **Logging secrets.** During pre-deploy checklist, verify secrets exist but
  never echo or log their values. Use `fly secrets list` (which shows names
  only), not `fly secrets show`.
- **Deploying to prod from a non-main branch.** Production deploys come from
  main. If the user wants to deploy a branch, confirm explicitly and document
  the deviation in the receipt.
- **Skipping the receipt.** Always write `DEPLOY-RECEIPT.md`, even on failure.
  The receipt is the audit trail. Future debugging depends on it.
- **Overwriting prior receipts without archiving.** If a previous
  `DEPLOY-RECEIPT.md` exists, rename it to `DEPLOY-RECEIPT-[timestamp].md`
  before writing the new one.
- **Promoting without passing gates.** Never skip the promotion chain. Code
  must pass through alpha and staging before reaching prod. Direct-to-prod
  deploys bypass validation and risk shipping broken code.
- **Auto-rolling back staging.** Staging rollback is manual by design. Let the
  developer investigate failures in staging rather than hiding them with an
  automatic rollback.
