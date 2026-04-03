---
name: deploy
description: >
  Use when the user wants to "deploy", "ship it", "push to production",
  "go live", "release", "deploy to alpha", "deploy to staging", or when the
  product is ready to be shipped to an environment. Handles three environments
  (alpha, staging, prod) with a promotion model and per-environment gates.
---

# /deploy — Ship to Alpha, Staging, or Production

Deploy source code to one of three environments: alpha, staging, or
production. Follows a promotion model where code moves through environments
as it clears successive gates. Verifies prerequisites, executes the
deployment, confirms health, and produces a receipt.

**Parameter**: target environment — `alpha`, `staging`, or `prod`
(default: `prod`).

---

## Environments

| Environment | App Name         | Deploy Command                     | Gates Required           |
|-------------|------------------|------------------------------------|--------------------------|
| **Alpha**   | `{app}-alpha`    | `fly deploy --app {app}-alpha`     | None                     |
| **Staging** | `{app}-staging`  | `fly deploy --app {app}-staging`   | QA pass                  |
| **Prod**    | `{app}`          | `fly deploy --app {app}`           | QA pass + security clear |

- **Alpha** — development validation. No gate checks, no smoke tests, no
  health checks enforced.
- **Staging** — mirrors production configuration. Promoted from alpha after
  `/qa` passes. Smoke tests run here.
- **Prod** — the live environment. Promoted from staging after `/security`
  clearance and explicit user confirmation. Full health checks and automatic
  rollback enforced.

---

## Process

### Skill Parameters

For the sections referenced in [GLOBAL-REFERENCE.md](GLOBAL-REFERENCE.md):

- `{PHASE_NAME}` = `deploy`
- `{OUTPUT_FILES}` = `["DEPLOY-RECEIPT.md"]`

Read and follow the **Settings Protocol**, **State Tracking**,
**Gate Verification**, and **Secrets Handling** sections in
[GLOBAL-REFERENCE.md](GLOBAL-REFERENCE.md).

**Additional state fields for this skill:**

On start, also include:
- `"target_environment": "<alpha|staging|prod>"`

On failure, also include:
- `"outputs": ["DEPLOY-RECEIPT.md"]` (receipt is always produced)

### Step 1 — Gate Verification

Check that all prerequisites are met for the target environment.

**Alpha** — no gates required. Skip this step entirely.

**Staging**:

1. Read `QA-REPORT.md` and parse the `## Summary` section. Extract the
   `Overall status` field directly from the file content. Verify it is
   `PASS` or `PASS WITH WARNINGS`. If missing or not passing, halt — do
   not deploy. Do NOT trust `.factory/state.json` for gate status — always
   read the actual report file.
2. Verify the `Tested commit` field in `QA-REPORT.md` matches the current
   `git rev-parse HEAD`. If it does not match, the report is stale — halt
   and inform the user that QA must be re-run.
3. Verify all CI checks passing on main via `gh run list` or equivalent.

**Prod**:

1. Read `QA-REPORT.md` and parse the `## Summary` section. Extract the
   `Overall status` field directly from the file content. Verify it is
   `PASS` or `PASS WITH WARNINGS`. If missing or not passing, halt — do
   not deploy. Do NOT trust `.factory/state.json` for gate status.
2. Read `SECURITY.md` and parse the `## Summary` section. Extract the
   `Overall status` field directly from the file content. Verify it is
   `CLEAR` or `WARNINGS` (not `BLOCKED`). If missing or `BLOCKED`, halt
   — do not deploy. Do NOT trust `.factory/state.json` for gate status.
3. Verify the `Tested commit` field in both `QA-REPORT.md` and
   `SECURITY.md` matches the current `git rev-parse HEAD`. If either
   does not match, the report is stale — halt and inform the user.
4. Verify all CI checks passing on main via `gh run list` or equivalent.
5. Verify no unmerged PRs marked as deploy blockers.
6. Obtain **explicit user confirmation** before proceeding.

If any hard gate fails (security `BLOCKED`, QA not passing, CI failing),
stop immediately. Write `DEPLOY-RECEIPT.md` with `status: FAILED` and the
reason, then exit.

### Step 2 — Pre-Deploy Checklist

Verify the deployment environment is ready:

1. Environment variables are set for the target environment
   (`fly secrets list --app {app-name}` — never log or echo secret values).
2. Required secrets are configured (verify names only, never values).
3. Database migrations are ready and tested (if applicable).
4. For staging and prod: capture the current deployed version before
   proceeding (rollback reference).

### Step 3 — Deploy

Execute the deployment:

1. Run `fly deploy --app {app-name}` from the project root, where
   `{app-name}` is `{app}-alpha`, `{app}-staging`, or `{app}` depending
   on the target.
2. Monitor deployment progress via `fly deploy` output.
3. For staging and prod: wait for Fly.io's built-in health checks to pass.
4. If the platform is not Fly.io, adapt to the configured deployment
   target (the deployment command should be documented in `CLAUDE.md`).

### Step 4 — Post-Deploy Verification

Verification depends on the target environment.

**Alpha** — no verification required. Deploy is complete once
`fly deploy` succeeds.

**Staging**:

1. Hit the health check endpoint and verify a 200 response.
2. Run smoke tests (subset of acceptance tests against the staging URL).
3. Verify telemetry is flowing (traces/metrics appear in the collector).

**Prod**:

1. Hit the health check endpoint and verify a 200 response.
2. Run smoke tests (subset of acceptance tests against the production URL).
3. Verify telemetry is flowing (traces/metrics appear in the collector).
4. Check error rates are within normal bounds (no spike compared to
   pre-deploy baseline).

If any verification step fails on prod, proceed to automatic rollback.
If verification fails on staging, record the failure and notify the user.

### Step 5 — Output

Write `DEPLOY-RECEIPT.md` with the full deployment record. If a previous
`DEPLOY-RECEIPT.md` exists, rename it to `DEPLOY-RECEIPT-[timestamp].md`
before writing the new one. See the Output Template section below.

---

## Promotion Model

### Alpha to Staging

- **Trigger**: `/qa` completes with status `PASS` or `PASS WITH WARNINGS`.
- **Action**: Invoke deploy with `target: staging`.
- **Automatic**: once QA passes, promotion proceeds without manual
  intervention.

### Staging to Prod

- **Trigger**: `/security` completes with status `CLEAR` or `WARNINGS`.
- **Gate**: explicit user confirmation required before deploying to prod.
- **Action**: Invoke deploy with `target: prod`.
- **Manual**: the user must confirm they want to proceed to production.

The promotion chain ensures code reaching production has been validated in
alpha, tested by QA in staging, and cleared by security.

---

## Rollback

### Prod — Automatic Rollback

If any post-deploy health check or smoke test fails on prod:

1. **Immediately roll back** — run
   `fly releases rollback --app {app}`. Do not wait for manual
   intervention.
2. **Verify rollback** — hit the health check endpoint again to confirm
   the previous version is serving.
3. **Record in receipt** — set `DEPLOY-RECEIPT.md` status to `ROLLED BACK`
   with the failure reason, the version rolled back to, and diagnostic
   output.
4. **Update state** — set `.factory/state.json` deploy phase to `failed`
   with `failure_reason` explaining what went wrong and that rollback was
   performed.

A broken production deployment must never stay live. If the rollback itself
fails, document that in the receipt and escalate to the user with clear
next steps.

### Staging — Manual Rollback

If post-deploy verification fails on staging:

1. Record the failure in `DEPLOY-RECEIPT.md` with `status: FAILED` and
   diagnostic details.
2. Notify the user with the failure details and the rollback command:
   `fly releases rollback --app {app}-staging`.
3. Do not auto-rollback — staging failures are not user-facing, so the
   user decides whether to roll back or investigate.

### Alpha — No Rollback

Alpha deployments have no rollback mechanism. If a deploy to alpha fails
or the app is unhealthy, the next `/build` cycle will deploy a new version.
Record the failure in the receipt but take no rollback action.

---

## DEPLOY-RECEIPT.md Output Template

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
| QA Report | YES/NO | PASS / WARN / MISSING / SKIPPED | [details] |
| Security Report | YES/NO | CLEAR / WARN / MISSING / SKIPPED | [details] |
| CI Checks | YES/NO | PASS / FAIL / SKIPPED | [details] |
| User Confirmation | YES/NO | CONFIRMED / SKIPPED | [details] |

## Health Checks
| Endpoint | Status | Response Time | Expected |
|----------|--------|---------------|----------|
| /health  | 200    | 45ms          | 200      |

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
[If status is FAILED or ROLLED BACK, include relevant logs, error
messages, and the exact step where failure occurred.]
```

---

## Settings

```yaml
settings:
  - name: auto_archive_receipts
    type: boolean
    default: true
    description: >
      Automatically rename existing DEPLOY-RECEIPT.md to
      DEPLOY-RECEIPT-{timestamp}.md before writing a new receipt.
      When false, overwrite the existing receipt without archiving.
```

## Anti-Patterns

- **Deploying past a BLOCKED security gate.** Never override a `BLOCKED`
  status from `SECURITY.md`. Critical issues must be fixed first.
- **Skipping post-deploy verification on staging or prod.** A deploy
  without health checks is not a deploy — it is a hope. Always verify.
- **Leaving a broken production deployment live.** If health checks fail
  on prod, roll back immediately. Do not "wait and see."
- **Logging secrets.** Verify secrets exist but never echo or log their
  values. Use `fly secrets list` (names only), not `fly secrets show`.
- **Deploying to prod from a non-main branch.** Production deploys come
  from main. If the user wants to deploy a branch, confirm explicitly and
  document the deviation in the receipt.
- **Skipping the receipt.** Always write `DEPLOY-RECEIPT.md`, even on
  failure. The receipt is the audit trail.
- **Overwriting prior receipts without archiving.** If a previous
  `DEPLOY-RECEIPT.md` exists, rename it to
  `DEPLOY-RECEIPT-[timestamp].md` before writing the new one.
- **Promoting without passing gates.** Never skip the promotion chain.
  Code must pass through alpha and staging before reaching prod.
- **Auto-rolling back staging.** Staging rollback is manual by design.
  Let the developer investigate failures rather than hiding them with an
  automatic rollback.
