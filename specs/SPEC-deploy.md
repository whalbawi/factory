# /deploy — Push to Production with Verification

The `/deploy` skill takes source code that has passed all quality and security gates and
ships it to production. It verifies prerequisites, executes the deployment, confirms the
application is healthy, and produces a receipt documenting exactly what was deployed and
how it went. If anything goes wrong post-deploy, it rolls back automatically — a broken
deployment must never stay live.

## Contract

**Required inputs**:

- Source code passing all gates (CI green on main branch)
- Infrastructure configuration (`fly.toml`, `Dockerfile`, or equivalent)

**Optional inputs**:

- `QA-REPORT.md` — used to verify QA gate status
- `SECURITY.md` — used to verify security gate status

**Outputs**:

- `DEPLOY-RECEIPT.md` — deployment record with status, health checks, and smoke test
  results

**Failure output**:

- `DEPLOY-RECEIPT.md` with `status: FAILED` or `status: ROLLED BACK`, including
  diagnostics and the failure point

## Category

Procedural skill — executes a defined sequence of steps with no user interaction beyond
the initial invocation. No sub-agents are spawned.

## Process

### Step 1: Gate Verification

Check that all prerequisites are met before touching production:

- `QA-REPORT.md` exists with status `PASS` or `PASS WITH WARNINGS`. If the file is
  missing, warn but allow the user to proceed (standalone invocation may not have a
  QA phase).
- `SECURITY.md` exists with status `CLEAR` or `WARNINGS` (not `BLOCKED`). If the file
  is missing, warn but allow the user to proceed. If status is `BLOCKED`, halt and
  report — do not deploy.
- All CI checks passing on the main branch. Verify via `gh run list` or equivalent.
- No unmerged PRs that are marked as deploy blockers.

If any hard gate fails (security `BLOCKED` or CI failing), stop immediately. Write
`DEPLOY-RECEIPT.md` with `status: FAILED` and the reason, then exit.

### Step 2: Pre-Deploy Checklist

Verify the deployment environment is ready:

- Environment variables are set in production (`fly secrets list` or equivalent)
- Required secrets are configured — never log or echo secret values
- Database migrations are ready and tested (if applicable)
- Rollback plan is documented: capture the current deployed version before proceeding

### Step 3: Deploy (Fly.io Default)

Execute the deployment:

- Run `fly deploy` from the project root
- Monitor deployment progress via `fly deploy` output
- Wait for Fly.io's built-in health checks to pass
- If the platform is not Fly.io, adapt to the configured deployment target (the
  deployment command should be documented in `CLAUDE.md`)

### Step 4: Post-Deploy Verification

Confirm the deployment is healthy:

- Hit the health check endpoint and verify a 200 response
- Run smoke tests — a subset of acceptance tests executed against the production URL
- Verify telemetry is flowing (check that traces/metrics appear in the collector)
- Check error rates are within normal bounds (no spike compared to pre-deploy baseline)

If any verification step fails, proceed to rollback (see Rollback section below).

### Step 5: Output

Write `DEPLOY-RECEIPT.md` with the full deployment record. See the Output Template
section for the exact format.

## State Tracking

Every skill must update `.factory/state.json` on invocation and completion, even when
invoked standalone outside the `/factory` orchestrator pipeline. If `.factory/state.json`
does not exist, create it.

**On start** — set the deploy phase to `in_progress`:

```json
{
  "phases": {
    "deploy": {
      "status": "in_progress",
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
      "started_at": "2026-04-03T14:00:00Z",
      "failed_at": "2026-04-03T14:08:00Z",
      "failure_reason": "Health check returned 503 after deploy; rolled back to v42",
      "outputs": ["DEPLOY-RECEIPT.md"]
    }
  }
}
```

When updating an existing `state.json`, merge into the existing structure — do not
overwrite other phases or top-level fields.

## Rollback

If any post-deploy health check or smoke test fails:

1. **Immediately roll back** — run `fly releases rollback` (or the equivalent for the
   configured platform). Do not wait for manual intervention.
2. **Verify rollback** — hit the health check endpoint again to confirm the previous
   version is serving.
3. **Record in receipt** — set `DEPLOY-RECEIPT.md` status to `ROLLED BACK` with the
   failure reason, the version rolled back to, and the diagnostic output.
4. **Update state** — set `.factory/state.json` deploy phase to `failed` with the
   `failure_reason` explaining what went wrong and that rollback was performed.

A broken deployment must never stay live. If the rollback itself fails, document that
in the receipt and escalate to the user with clear next steps.

## Output Template

```markdown
# Deployment Receipt — [Date]

## Deployment
- **Status**: SUCCESS / FAILED / ROLLED BACK
- **Version**: [git commit SHA]
- **Previous version**: [git commit SHA]
- **Environment**: production
- **Platform**: Fly.io
- **Region**: [region]
- **Deployed at**: [ISO 8601 timestamp]

## Gate Checks
| Gate | Status | Notes |
|------|--------|-------|
| QA Report | PASS / WARN / MISSING | [details] |
| Security Report | CLEAR / WARN / MISSING | [details] |
| CI Checks | PASS / FAIL | [details] |

## Health Checks
| Endpoint | Status | Response Time | Expected |
|----------|--------|---------------|----------|
| /health | 200 | 45ms | 200 |

## Smoke Tests
| Test | Status | Notes |
|------|--------|-------|
| [test name] | PASS / FAIL | [details] |

## Telemetry
- **Traces flowing**: YES / NO
- **Error rate**: [percentage] (baseline: [percentage])

## Rollback Info
- **Previous version**: [commit SHA]
- **Rollback command**: `fly releases rollback`
- **Rollback performed**: YES / NO
- **Rollback reason**: [if applicable]

## Diagnostics
[If status is FAILED or ROLLED BACK, include relevant logs, error messages, and
the exact step where failure occurred.]
```

## Anti-Patterns

- **Deploying past a BLOCKED security gate.** Never override a `BLOCKED` status from
  `SECURITY.md`. If security found critical issues, they must be fixed first.
- **Skipping post-deploy verification.** A deploy without health checks is not a deploy
  — it is a hope. Always verify.
- **Leaving a broken deployment live.** If health checks fail, roll back immediately.
  Do not "wait and see" or "give it a minute."
- **Logging secrets.** During pre-deploy checklist, verify secrets exist but never echo
  or log their values. Use `fly secrets list` (which shows names only), not
  `fly secrets show`.
- **Deploying from a non-main branch.** Production deploys come from main. If the user
  wants to deploy a branch, confirm explicitly and document the deviation in the
  receipt.
- **Skipping the receipt.** Always write `DEPLOY-RECEIPT.md`, even on failure. The
  receipt is the audit trail. Future debugging depends on it.
- **Overwriting prior receipts without archiving.** If a previous `DEPLOY-RECEIPT.md`
  exists, rename it to `DEPLOY-RECEIPT-[timestamp].md` before writing the new one.
