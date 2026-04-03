# /qa — Structured Quality Control

## Contract

| Field | Value |
|-------|-------|
| **Required inputs** | Source code, `SPEC.md` |
| **Optional inputs** | `specs/`, `CLAUDE.md` |
| **Outputs** | `QA-REPORT.md` |
| **Failure output** | `QA-REPORT.md` with `status: failed` and findings |

The skill reads `SPEC.md` (and domain specs in `specs/` when present) to extract
acceptance criteria. It reads `CLAUDE.md` for test commands, coverage targets, and
project conventions. Source code is required because there is nothing to QA without it.

On failure, the skill still produces `QA-REPORT.md` documenting whatever findings were
collected before the failure. The report carries `status: failed` so downstream consumers
(the orchestrator, `/deploy`) know the gate did not pass.

---

## Category

**Hybrid skill** — procedural for single-domain projects, optionally agentic for
multi-domain projects.

For a single-domain project, the QA skill runs as a linear procedure: coverage analysis,
test audit, acceptance verification, edge case hunting, regression check, report. One
agent, one pass.

For multi-domain projects (multiple `specs/SPEC-{domain}.md` files), the QA agent may
spawn per-domain sub-agents that run coverage and test audits in parallel, then
consolidate into a single `QA-REPORT.md`. The top-level QA agent owns the final report
and is responsible for cross-domain integration findings that per-domain agents would
miss.

---

## Process

### Step 1: Coverage Analysis

Run the test suite with coverage instrumentation using the commands from `CLAUDE.md`.

- Measure line, branch, and function coverage per domain.
- Identify untested code paths — list specific files and functions lacking coverage.
- Compare against the coverage target from `CLAUDE.md` (default: 100% if unspecified).
- Record raw coverage numbers for the report.

If the test suite fails to run at all (missing dependencies, broken config), halt and
produce a `QA-REPORT.md` with `status: failed` and the failure reason.

### Step 2: Test Quality Audit

Review existing tests for substance, not just existence.

- **Meaningful assertions** — Tests that only check "it doesn't throw" are flagged.
  Every test must assert on observable behavior.
- **Edge case coverage** — Check for null inputs, empty collections, boundary values,
  and concurrent access scenarios.
- **Error path testing** — Verify that error/failure branches are tested, not just
  the happy path.
- **Integration test isolation** — Confirm proper stubs/mocks, no test interdependency
  (tests must pass in any order).
- **Mutation testing** — If the stack supports it (e.g., Stryker for JS/TS, mutmut for
  Python, cargo-mutants for Rust), run mutation testing to verify that tests actually
  catch bugs. Report the mutation score.

### Step 3: Acceptance Criteria Verification

For each acceptance criterion in `SPEC.md` and `specs/SPEC-{domain}.md`:

- Map the criterion to specific test(s) that verify it.
- Run those tests and confirm they pass.
- For criteria without corresponding tests, write the missing tests.
- Document any criteria that cannot be automatically tested (require manual
  verification) and explain why.

Produce a criterion-by-criterion table with pass/fail/missing status.

### Step 4: Edge Case Hunting

Systematically probe beyond what existing tests cover:

- **Input validation boundaries** — Min/max values, empty strings, special characters,
  oversized payloads.
- **Concurrent operations** — Race conditions, deadlocks, double-submit scenarios.
- **Resource exhaustion** — Memory pressure, disk full, network timeouts.
- **State transitions** — Invalid transitions, interrupted operations mid-flight,
  partial failures.
- **External dependency failures** — API down, malformed responses, certificate errors,
  DNS failures, slow responses exceeding timeouts.

Write tests for any edge cases discovered. If an edge case reveals a bug, document it
in the Issues Found section of the report.

### Step 5: Regression Check

Verify that all previously passing functionality still works after the build phase.

- Run the full test suite (not just new tests).
- Compare results against any prior `QA-REPORT.md` if one exists.
- Flag any tests that previously passed but now fail.
- Flag any decrease in coverage compared to the prior report.

### Step 6: Output

Write `QA-REPORT.md` following the template in the Output Template section below.

---

## State Tracking

Every invocation of `/qa` must update `.factory/state.json`, whether the skill is
invoked standalone or as part of the `/factory` pipeline. If `.factory/state.json` does
not exist, create it.

### On Start

Set the `qa` phase to `in_progress` with a `started_at` timestamp:

```json
{
  "phases": {
    "qa": {
      "status": "in_progress",
      "started_at": "2026-04-03T14:00:00Z"
    }
  }
}
```

If the state file already exists with other phases, merge — do not overwrite the
existing phase data.

### On Completion

Set the `qa` phase to `completed` with `completed_at` and `outputs`:

```json
{
  "phases": {
    "qa": {
      "status": "completed",
      "started_at": "2026-04-03T14:00:00Z",
      "completed_at": "2026-04-03T14:45:00Z",
      "outputs": ["QA-REPORT.md"]
    }
  }
}
```

### On Failure

Set the `qa` phase to `failed` with `failed_at` and `failure_reason`:

```json
{
  "phases": {
    "qa": {
      "status": "failed",
      "started_at": "2026-04-03T14:00:00Z",
      "failed_at": "2026-04-03T14:10:00Z",
      "failure_reason": "Test suite failed to execute: missing vitest dependency",
      "outputs": ["QA-REPORT.md"]
    }
  }
}
```

Even on failure, `QA-REPORT.md` is listed in outputs because the skill always produces
a report (with `status: failed` and whatever findings were collected).

---

## Output Template

```markdown
# QA Report — [Date]

## Summary

- **Overall status**: PASS / FAIL / PASS WITH WARNINGS
- **Coverage**: X% line, Y% branch, Z% function
- **Acceptance criteria**: N/M passing
- **Test quality**: [Brief assessment]

## Coverage by Domain

| Domain | Lines | Branches | Functions | Gaps |
|--------|-------|----------|-----------|------|
| [domain] | X% | Y% | Z% | [uncovered areas] |

## Acceptance Criteria

| Criterion | Test(s) | Status | Notes |
|-----------|---------|--------|-------|
| [from spec] | [test file:test name] | PASS/FAIL/MISSING | [details] |

## Issues Found

### Critical

[Issues that block deployment — broken functionality, data loss risk, security holes
discovered during testing.]

### Major

[Issues that should be fixed before deployment — degraded UX, missing error handling
for common cases, performance problems.]

### Minor

[Issues that can ship but should be tracked — cosmetic problems, uncommon edge cases,
minor inconsistencies.]

## Test Quality Assessment

- **Assertion quality**: [Findings]
- **Edge case coverage**: [Findings]
- **Error path coverage**: [Findings]
- **Integration test isolation**: [Findings]
- **Mutation score**: [X% if applicable, or "not measured"]

## Regression

- **Previously passing tests now failing**: [count and details, or "none"]
- **Coverage delta**: [change from prior report, or "no prior report"]

## Recommendations

[Prioritized list of what to fix before deploying. Reference specific issues above.]
```

---

## Anti-Patterns

- **Do not rubber-stamp.** A QA report that says PASS without evidence is worse than
  no report. Every PASS must be backed by coverage numbers and test results.

- **Do not skip edge case hunting.** Step 4 is where real bugs are found. Steps 1-3
  verify what's already tested; step 4 finds what's missing.

- **Do not write trivial tests to inflate coverage.** Tests added during QA must assert
  on meaningful behavior. A test that calls a function without checking the result is
  not a test.

- **Do not ignore flaky tests.** A test that passes sometimes and fails sometimes is a
  bug. Document it as a Major issue, not a minor annoyance.

- **Do not conflate "tests pass" with "quality is good."** A project can have 100%
  coverage and still be broken if the tests assert on the wrong things. The test
  quality audit (step 2) exists for this reason.

- **Do not silently fix bugs.** If edge case hunting reveals a bug, document it in the
  report AND fix it. The report is the audit trail; the fix is the remediation. Both
  are required.

- **Do not skip state tracking.** Even when invoked standalone (not via `/factory`),
  the skill must update `.factory/state.json`. This ensures the orchestrator can detect
  that QA has been run if the user later invokes `/factory`.
