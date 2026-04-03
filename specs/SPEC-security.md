# /security — Security Audit, Threat Modeling, and Hardening

The `/security` skill performs a structured security review of a project's source code,
dependencies, authentication flows, and secrets management. It produces a `SECURITY.md`
report that acts as a gate: if any CRITICAL finding exists, the pipeline cannot advance
to `/deploy`.

## Contract

| Aspect | Details |
|--------|---------|
| **Required inputs** | Source code, `SPEC.md` |
| **Optional inputs** | `specs/`, `CLAUDE.md` |
| **Outputs** | `SECURITY.md` |
| **Failure output** | `SECURITY.md` with `status: BLOCKED` and critical findings documented |

The skill must never silently succeed. If it cannot complete a review phase (e.g., no
dependency manifest found for audit, no auth flow to review), it documents the gap in the
output rather than skipping it.

## Category

**Hybrid skill** — runs procedurally for single-domain projects. For multi-domain projects,
the Security agent may spawn per-domain sub-agents to parallelize the audit across domains.
Each sub-agent follows the same six-step process against its assigned domain, and findings
are merged into a single `SECURITY.md`.

## Process

### Step 1: Dependency Audit

Run stack-appropriate tools to surface known vulnerabilities in third-party dependencies:

- **Node.js**: `npm audit` or `pnpm audit`
- **Python**: `pip-audit`
- **Rust**: `cargo audit`
- **Go**: `govulncheck`

For each vulnerability found:

- Record package name, installed version, and vulnerability ID (CVE/GHSA)
- Classify severity: CRITICAL, HIGH, MEDIUM, LOW
- Produce a remediation step: version bump, patch, or package replacement
- Flag CRITICAL and HIGH findings for the gate check

If no dependency manifest is found, document this as a gap and proceed.

### Step 2: Static Analysis

Scan the source code for common vulnerability patterns using stack-appropriate tools
(semgrep, bandit, clippy security lints, or manual pattern matching):

- SQL injection, XSS, SSRF, path traversal
- Hardcoded secrets, API keys, credentials
- Insecure deserialization
- Improper error handling that leaks internal details (stack traces, DB schemas)
- Unsafe use of `eval`, `exec`, or equivalent dynamic execution
- Missing input validation on public-facing endpoints

Record each finding with file path, line number, issue description, severity, and
recommended fix.

### Step 3: Threat Model

For each domain in the project (or the whole project if single-domain):

- **Enumerate attack surfaces** — inputs, endpoints, file access, network calls,
  inter-service communication
- **Identify threats per surface** — use STRIDE (Spoofing, Tampering, Repudiation,
  Information Disclosure, Denial of Service, Elevation of Privilege) or equivalent
- **Assess risk** — likelihood x impact, yielding CRITICAL / HIGH / MEDIUM / LOW
- **Document mitigations** — both existing mitigations already in the code and
  mitigations that are still needed

### Step 4: Auth Flow Review

If the product has authentication or authorization:

- Verify the auth implementation matches what the spec describes
- Check token handling: storage mechanism, transmission (HTTPS only), expiration
  policy, rotation strategy
- Verify authorization checks exist on every protected operation — look for missing
  guards, not just present ones
- Test permission boundary edge cases: role escalation, cross-tenant access,
  expired-but-cached tokens

If the product has no auth, document this explicitly and note whether the spec
indicates auth is intentionally absent or whether it is a gap.

### Step 5: Secrets Management Review

Verify the project's secrets hygiene:

- **No secrets in source**: Scan code, config files, and git history for leaked
  secrets, API keys, passwords, or private keys
- **`.env` gitignored**: Confirm `.gitignore` includes `.env` and any other
  secret-bearing files
- **Access pattern**: Secrets are read from environment variables or a secret
  management service — never hardcoded
- **Rotation strategy**: Check whether a rotation plan is documented or whether
  secrets are static with no expiration

### Step 6: Output

Write `SECURITY.md` following the output template below. Set the overall status:

- **CLEAR** — no CRITICAL or HIGH findings
- **WARNINGS** — HIGH findings exist but no CRITICAL; deployment may proceed with
  documented acceptance of risk
- **BLOCKED** — one or more CRITICAL findings; deployment must not proceed

## State Tracking

Every skill must update `.factory/state.json` on invocation and completion, even when
run standalone (outside the `/factory` orchestrator).

**On start** — set the `security` phase to `in_progress`:

```json
{
  "security": {
    "status": "in_progress",
    "started_at": "2026-04-03T15:00:00Z"
  }
}
```

**On successful completion** — set to `completed` with outputs:

```json
{
  "security": {
    "status": "completed",
    "started_at": "2026-04-03T15:00:00Z",
    "completed_at": "2026-04-03T15:45:00Z",
    "outputs": ["SECURITY.md"]
  }
}
```

**On failure** — set to `failed` with reason:

```json
{
  "security": {
    "status": "failed",
    "started_at": "2026-04-03T15:00:00Z",
    "failed_at": "2026-04-03T15:30:00Z",
    "failure_reason": "Could not run dependency audit — no package manifest found and static analysis tooling unavailable"
  }
}
```

If `.factory/state.json` does not exist, create it with the minimal structure:

```json
{
  "pipeline": "factory",
  "current_phase": "security",
  "phases": {
    "security": {
      "status": "in_progress",
      "started_at": "2026-04-03T15:00:00Z"
    }
  }
}
```

## Gate Behavior

The `/security` skill is a **hard gate** in the pipeline. The orchestrator enforces:

- **CRITICAL finding present** → `status: BLOCKED` in `SECURITY.md`. The orchestrator
  must not advance to `/deploy`. The user must fix the critical findings and re-run
  `/security`.
- **HIGH findings only** → `status: WARNINGS`. The orchestrator may advance to `/deploy`
  but must surface the warnings and require explicit user acknowledgment.
- **No CRITICAL or HIGH** → `status: CLEAR`. The orchestrator advances normally.

The gate check reads the `## Summary` section of `SECURITY.md` and inspects the
`Overall status` field. There is no separate gate file — `SECURITY.md` is the
source of truth.

## Output Template

```markdown
# Security Report — [Date]

## Summary

- **Overall status**: CLEAR / WARNINGS / BLOCKED
- **Critical findings**: [count]
- **High findings**: [count]
- **Medium findings**: [count]
- **Low findings**: [count]

## Dependency Audit

| Package | Vulnerability | Severity | Remediation |
|---------|---------------|----------|-------------|
| [name]  | [CVE/GHSA-ID] | CRITICAL / HIGH / MEDIUM / LOW | [action] |

## Static Analysis Findings

| File | Line | Issue | Severity | Fix |
|------|------|-------|----------|-----|
| [path] | [line] | [description] | CRITICAL / HIGH / MEDIUM / LOW | [recommendation] |

## Threat Model

### [Domain Name]

| Surface | Threat | Risk | Mitigation | Status |
|---------|--------|------|------------|--------|
| [input/endpoint/etc.] | [STRIDE category: description] | CRITICAL / HIGH / MEDIUM / LOW | [what exists or what is needed] | Mitigated / Needs Work / Open |

## Auth Review

[Findings from Step 4. If no auth exists, state why and whether that is intentional.]

## Secrets Management

[Findings from Step 5. Enumerate any leaked secrets, missing .gitignore rules,
or absent rotation strategy.]

## Deployment Blockers

[List every CRITICAL and HIGH finding that must be resolved before `/deploy` can
proceed. If none, state "No deployment blockers."]

## Recommendations

[Non-blocking improvements: MEDIUM and LOW findings, hardening suggestions,
future audit areas. These do not block deployment but should be addressed.]
```

## Anti-Patterns

- **Do not rubber-stamp.** A `CLEAR` status must reflect genuine analysis, not a
  skipped review. If a review step could not be performed, the status must reflect
  that uncertainty.

- **Do not conflate severity levels.** CRITICAL means active exploitability or data
  breach risk. HIGH means significant risk that requires near-term remediation. Do not
  inflate or deflate — inaccurate severity erodes trust in the gate.

- **Do not skip steps for small projects.** Even a single-file CLI tool gets a
  dependency audit and secrets scan. The threat model may be brief, but it must exist.

- **Do not fix findings inline.** The `/security` skill audits and reports. It does
  not modify source code. Fixes happen in `/build` (or manually by the user), followed
  by a `/security` re-run.

- **Do not ignore git history.** A secret that was committed and then deleted is still
  leaked. The secrets management review must consider historical commits, not just the
  current tree.

- **Do not produce a wall of text.** Use the tables in the output template. Findings
  without severity, file location, and remediation are not actionable.
