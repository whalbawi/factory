---
name: security
description: >
  Use when the user wants a "security audit", "security check", "threat model",
  "security review", "harden", or when the product needs a security assessment
  before deployment. Performs dependency audit, static analysis, threat modeling,
  auth flow review, and secrets management review. Acts as a deployment gate —
  critical findings block /deploy.
---

# /security — Security Audit, Threat Modeling, and Hardening

## Purpose

The `/security` skill performs a structured security review of a project's source
code, dependencies, authentication flows, and secrets management. It produces a
`SECURITY.md` report that acts as a **hard gate**: if any CRITICAL finding exists,
the pipeline cannot advance to `/deploy`.

This skill audits and reports. It does not modify source code. Fixes happen in
`/build` (or manually by the user), followed by a `/security` re-run.

## Category

**Hybrid skill.** Runs procedurally for single-domain projects. For multi-domain
projects the security agent may spawn per-domain sub-agents to parallelize the
audit across domains. Each sub-agent follows the same six-step process against its
assigned domain, and findings are merged into a single `SECURITY.md`.

## Contract

| Aspect              | Details                                                  |
|---------------------|----------------------------------------------------------|
| **Required inputs** | Source code, `SPEC.md`                                   |
| **Optional inputs** | `specs/`, `CLAUDE.md`                                    |
| **Outputs**         | `SECURITY.md`                                            |
| **Failure output**  | `SECURITY.md` with `status: BLOCKED` and critical        |
|                     | findings documented                                      |

The skill must never silently succeed. If it cannot complete a review phase (e.g.,
no dependency manifest found, no auth flow to review), it documents the gap in the
output rather than skipping it.

## Process

### Skill Parameters

For the sections referenced in [GLOBAL-REFERENCE.md](GLOBAL-REFERENCE.md):

- `{PHASE_NAME}` = `security`
- `{OUTPUT_FILES}` = `["SECURITY.md"]`

Read and follow the **Settings Protocol**, **State Tracking**, and
**Secrets Handling** sections in
[GLOBAL-REFERENCE.md](GLOBAL-REFERENCE.md).

### Step 1: Dependency Audit

Run stack-appropriate tools to surface known vulnerabilities in third-party
dependencies:

- **Node.js** — `npm audit` or `pnpm audit`
- **Python** — `pip-audit`
- **Rust** — `cargo audit`
- **Go** — `govulncheck`

For each vulnerability found:

1. Record package name, installed version, and vulnerability ID (CVE/GHSA).
2. Classify severity: CRITICAL, HIGH, MEDIUM, LOW.
3. Produce a remediation step: version bump, patch, or package replacement.
4. Flag CRITICAL and HIGH findings for the gate check.

If no dependency manifest is found, document this as a gap and proceed.

### Step 2: Static Analysis

Scan the source code for common vulnerability patterns using stack-appropriate
tools (semgrep, bandit, clippy security lints, or manual pattern matching):

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

1. **Enumerate attack surfaces** — inputs, endpoints, file access, network calls,
   inter-service communication.
2. **Identify threats per surface** — use STRIDE (Spoofing, Tampering, Repudiation,
   Information Disclosure, Denial of Service, Elevation of Privilege).
3. **Assess risk** — likelihood x impact, yielding CRITICAL / HIGH / MEDIUM / LOW.
4. **Document mitigations** — both existing mitigations already in the code and
   mitigations that are still needed.

### Step 4: Auth Flow Review

If the product has authentication or authorization:

- Verify the auth implementation matches what the spec describes.
- Check token handling: storage mechanism, transmission (HTTPS only), expiration
  policy, rotation strategy.
- Verify authorization checks exist on every protected operation — look for
  missing guards, not just present ones.
- Test permission boundary edge cases: role escalation, cross-tenant access,
  expired-but-cached tokens.

If the product has no auth, document this explicitly and note whether the spec
indicates auth is intentionally absent or whether it is a gap.

### Step 5: Secrets Management Review

Verify the project's secrets hygiene:

- **No secrets in source.** Scan code, config files, and git history for leaked
  secrets, API keys, passwords, or private keys.
- **`.env` gitignored.** Confirm `.gitignore` includes `.env` and any other
  secret-bearing files.
- **Access pattern.** Secrets are read from environment variables or a secret
  management service — never hardcoded.
- **Rotation strategy.** Check whether a rotation plan is documented or whether
  secrets are static with no expiration.

A secret that was committed and then deleted is still leaked. The review must
consider historical commits, not just the current tree.

### Step 6: Output

Write `SECURITY.md` following the output template below. Set the overall status:

- **CLEAR** — no CRITICAL or HIGH findings.
- **WARNINGS** — HIGH findings exist but no CRITICAL; deployment may proceed with
  documented acceptance of risk.
- **BLOCKED** — one or more CRITICAL findings; deployment must not proceed.

## Gate Behavior

The `/security` skill is a **hard gate** in the pipeline. The orchestrator
enforces:

| Condition                  | Status     | Pipeline effect                    |
|----------------------------|------------|------------------------------------|
| CRITICAL finding present   | `BLOCKED`  | Orchestrator must NOT advance to   |
|                            |            | `/deploy`. User must fix and       |
|                            |            | re-run `/security`.                |
| HIGH findings only         | `WARNINGS` | Orchestrator may advance to        |
|                            |            | `/deploy` but must surface         |
|                            |            | warnings and require explicit      |
|                            |            | user acknowledgment.               |
| No CRITICAL or HIGH        | `CLEAR`    | Orchestrator advances normally.    |

The gate check reads the `## Summary` section of `SECURITY.md` and inspects the
`Overall status` field. There is no separate gate file — `SECURITY.md` is the
source of truth.

## SECURITY.md Output Template

```markdown
# Security Report — [Date]

## Summary

- **Overall status**: CLEAR / WARNINGS / BLOCKED
- **Tested commit**: [output of `git rev-parse HEAD`]
- **Critical findings**: [count]
- **High findings**: [count]
- **Medium findings**: [count]
- **Low findings**: [count]

## Dependency Audit

| Package | Vulnerability   | Severity                     | Remediation |
|---------|-----------------|------------------------------|-------------|
| [name]  | [CVE/GHSA-ID]  | CRITICAL / HIGH / MED / LOW  | [action]    |

## Static Analysis Findings

| File   | Line   | Issue           | Severity                    | Fix              |
|--------|--------|-----------------|-----------------------------|------------------|
| [path] | [line] | [description]   | CRITICAL / HIGH / MED / LOW | [recommendation] |

## Threat Model

### [Domain Name]

| Surface              | Threat                        | Risk    | Mitigation   | Status     |
|----------------------|-------------------------------|---------|--------------|------------|
| [input/endpoint/etc] | [STRIDE category: description]| C/H/M/L | [details]    | Mitigated / Needs Work / Open |

## Auth Review

[Findings from Step 4. If no auth exists, state why and whether
that is intentional.]

## Secrets Management

[Findings from Step 5. Enumerate any leaked secrets, missing
.gitignore rules, or absent rotation strategy.]

## Deployment Blockers

[List every CRITICAL and HIGH finding that must be resolved before
/deploy can proceed. If none, state "No deployment blockers."]

## Recommendations

[Non-blocking improvements: MEDIUM and LOW findings, hardening
suggestions, future audit areas. These do not block deployment
but should be addressed.]
```

## Settings

```yaml
settings:
  - name: history_scan_depth
    type: enum
    values: ["full", "recent", "current"]
    default: "full"
    description: >
      How deeply the secrets management review scans git history.
      "full" scans all commits for leaked secrets. "recent" scans
      the last 100 commits. "current" scans only the current tree
      (fastest but misses historically leaked secrets).
  - name: threat_model_depth
    type: enum
    values: ["full", "abbreviated"]
    default: "full"
    description: >
      Depth of the STRIDE threat model in Step 3. "full" enumerates
      all attack surfaces and threats per domain. "abbreviated"
      covers only high-risk surfaces (external inputs, auth
      boundaries, data stores).
```

## Anti-Patterns

- **Do not rubber-stamp.** A `CLEAR` status must reflect genuine analysis, not a
  skipped review. If a review step could not be performed, the status must reflect
  that uncertainty.

- **Do not conflate severity levels.** CRITICAL means active exploitability or
  data breach risk. HIGH means significant risk requiring near-term remediation.
  Do not inflate or deflate — inaccurate severity erodes trust in the gate.

- **Do not skip steps for small projects.** Even a single-file CLI tool gets a
  dependency audit and secrets scan. The threat model may be brief, but it must
  exist.

- **Do not fix findings inline.** The `/security` skill audits and reports. It
  does not modify source code. Fixes happen in `/build` or manually, followed by
  a `/security` re-run.

- **Do not ignore git history.** A secret committed and then deleted is still
  leaked. The secrets management review must consider historical commits, not
  just the current tree.

- **Do not produce a wall of text.** Use the tables in the output template.
  Findings without severity, file location, and remediation are not actionable.
