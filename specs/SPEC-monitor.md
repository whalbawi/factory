# /monitor — Application Health Monitoring and Bug Triage (v1.1)

> **DEFERRED TO v1.1.** This skill is defined but not included in the initial release.
> It is documented here for planning purposes and to lock the contract that other skills
> depend on (e.g., `/deploy` references `MONITOR-REPORT.md`).

## Contract

| Field | Value |
|-------|-------|
| **Required inputs** | Deployed application (live, reachable endpoint) |
| **Optional inputs** | Telemetry config (OTel exporter settings), `DEPLOY-RECEIPT.md` |
| **Outputs** | `MONITOR-REPORT.md` |
| **Failure output** | `MONITOR-REPORT.md` with `status: UNREACHABLE` and connectivity issues documented |

## Category

**Procedural skill** — executes a defined sequence of collection, analysis, triage,
and reporting steps. No user interaction during execution; output is reviewed after
completion.

## Process

### Step 1: Collect Metrics

Gather data from all available sources:

- **Fly.io platform metrics** — `fly status`, `fly logs`, `fly machine status`.
  Capture instance health, restart counts, and deployment version.

- **OpenTelemetry data** — Query the configured OTel backend for:

  - Request rate and error rate (HTTP 4xx, 5xx breakdown)
  - Latency distributions (p50, p95, p99) per endpoint
  - Active connections and throughput
  - Custom application metrics (if instrumented)

- **Error tracking** — If an error tracking service is configured (Sentry, Honeybadger,
  etc.), pull recent errors with stack traces, frequency, and affected users.

- **Uptime / health checks** — Hit the application's health endpoint. Record response
  time, status code, and body. If `DEPLOY-RECEIPT.md` exists, use the health check
  URL recorded there.

If a data source is unreachable, log the failure and continue with remaining sources.
Do not abort the entire process because one source is down.

### Step 2: Analyze

Evaluate collected metrics against baselines and thresholds:

- **Error rate spikes** — Compare current error rate to the trailing 24-hour average.
  Flag if current rate exceeds 2x baseline or if any 5xx errors exist.

- **Latency degradation** — Compare current p95 and p99 to trailing averages. Flag if
  either exceeds 1.5x baseline.

- **Resource exhaustion** — Check memory usage, CPU usage, and disk consumption. Flag
  if any resource exceeds 80% utilization.

- **Unusual traffic patterns** — Detect sudden drops (possible outage) or spikes
  (possible attack or viral event) relative to time-of-day norms.

- **Recurring errors** — Group errors by signature. Flag any error that has occurred
  more than 10 times in the collection window.

When baselines are unavailable (first run, or insufficient historical data), document
raw metrics without comparison and note that baselines will be established on
subsequent runs.

### Step 3: Triage Anomalies

For each anomaly detected in Step 2:

- **Correlate with deployments** — Check `DEPLOY-RECEIPT.md` timestamps. Did the
  anomaly start after a deployment?

- **Correlate with code changes** — Check recent git history for changes to affected
  code paths.

- **Classify severity**:

  - **Critical** — Service down, data loss, security breach
  - **Major** — Degraded performance affecting users, elevated error rates
  - **Minor** — Non-user-facing issues, warning-level resource usage

- **Suggest action**:

  - **Hotfix** — Ship a targeted fix immediately
  - **Rollback** — Revert to previous deployment (`fly releases rollback`)
  - **Investigate** — Needs deeper analysis before action
  - **Monitor** — Not actionable yet, watch for escalation

### Step 4: Output

Write `MONITOR-REPORT.md` with all findings. See the Output Template section below
for the full structure.

## State Tracking

Every skill must update `.factory/state.json` on invocation and completion, even when
run standalone (outside the `/factory` pipeline).

**On invocation**, set the monitor phase to `in_progress`:

```json
{
  "monitor": {
    "status": "in_progress",
    "started_at": "2026-04-03T16:00:00Z"
  }
}
```

**On completion**, record status and outputs:

```json
{
  "monitor": {
    "status": "completed",
    "started_at": "2026-04-03T16:00:00Z",
    "completed_at": "2026-04-03T16:05:00Z",
    "outputs": ["MONITOR-REPORT.md"],
    "skipped": false
  }
}
```

**On failure**, record the failure:

```json
{
  "monitor": {
    "status": "completed",
    "started_at": "2026-04-03T16:00:00Z",
    "completed_at": "2026-04-03T16:02:00Z",
    "outputs": ["MONITOR-REPORT.md"],
    "skipped": false,
    "notes": "Partial report — OTel backend unreachable"
  }
}
```

Note: even a partial report counts as `completed` with outputs, because the failure
report itself is a valid `MONITOR-REPORT.md`. The `notes` field captures what went
wrong.

If `.factory/state.json` does not exist (standalone invocation with no prior pipeline),
create it with only the `monitor` phase entry.

## Output Template

```markdown
# Monitor Report — [Date]

## Overall Health

- **Status**: HEALTHY / DEGRADED / DOWN / UNREACHABLE
- **Uptime**: [percentage over collection period, or "unknown"]
- **Collection window**: [start time] — [end time]
- **Data sources**: [list of sources successfully queried]
- **Data sources unavailable**: [list of sources that failed, or "none"]

## Metrics

| Metric | Current | Baseline | Status |
|--------|---------|----------|--------|
| Request rate | N req/s | N req/s | NORMAL / ELEVATED / LOW |
| Error rate (4xx) | N% | N% | NORMAL / ELEVATED |
| Error rate (5xx) | N% | N% | NORMAL / ELEVATED |
| Latency p50 | Nms | Nms | NORMAL / DEGRADED |
| Latency p95 | Nms | Nms | NORMAL / DEGRADED |
| Latency p99 | Nms | Nms | NORMAL / DEGRADED |
| Memory usage | N% | — | NORMAL / WARNING / CRITICAL |
| CPU usage | N% | — | NORMAL / WARNING / CRITICAL |
| Disk usage | N% | — | NORMAL / WARNING / CRITICAL |

## Errors

| Error | Count | First Seen | Last Seen | Likely Cause | Severity | Action |
|-------|-------|------------|-----------|--------------|----------|--------|

## Anomalies

### [Anomaly Title]

- **Severity**: Critical / Major / Minor
- **Detection**: [What metric or signal triggered this]
- **Correlation**: [Related deployment, code change, or external event]
- **Suggested action**: Hotfix / Rollback / Investigate / Monitor
- **Details**: [Additional context]

## Recommendations

[Proactive suggestions — performance tuning, scaling, alerting gaps, etc.]
```

## Anti-Patterns

- **Do not block on missing data sources.** If Fly.io is reachable but OTel is not,
  produce a partial report. A partial report is always better than no report.

- **Do not fabricate baselines.** If this is the first run or historical data is
  unavailable, report raw values and explicitly state that baselines are not yet
  established. Do not invent "expected" values.

- **Do not conflate monitoring with incident response.** This skill collects, analyzes,
  and reports. It does not execute hotfixes, rollbacks, or code changes. Suggested
  actions are recommendations for the user, not commands for the skill to execute.

- **Do not ignore the health endpoint.** Even if telemetry data looks fine, always hit
  the health check endpoint directly. Telemetry pipelines can fail silently while the
  application is actually down.

- **Do not produce reports without timestamps.** Every metric, error, and anomaly must
  include timestamps. A monitoring report without timestamps is useless for
  correlation.

- **Do not skip state tracking.** Even when `/monitor` is invoked standalone (not via
  the `/factory` pipeline), it must update `.factory/state.json`. This ensures that
  the orchestrator can detect that monitoring has been run when it eventually checks.
