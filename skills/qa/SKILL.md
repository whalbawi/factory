---
name: qa
description: >
  Use when the user wants to "run QA", "quality check", "test everything",
  "acceptance testing", "QA pass", or when the build is complete and the product
  needs structured quality control before deployment. Goes beyond "tests pass" —
  validates test quality, acceptance criteria, edge cases, and coverage.
---

# /qa — Structured Quality Control

## Purpose

The `/qa` skill performs structured quality control that goes far beyond
"tests pass." Passing tests are necessary but insufficient — they only prove
what was tested works as the test author imagined. This skill validates that
tests are meaningful, that acceptance criteria from the spec map to specific
tests, that edge cases have been systematically hunted, and that coverage
numbers reflect genuine verification rather than padding.

The output is always a `QA-REPORT.md` — even on failure — so there is a
permanent audit trail of what was checked and what was found.

## Category

**Hybrid skill** — procedural for single-domain projects, agentic for
multi-domain projects.

For a single-domain project, `/qa` runs as a linear six-step procedure: one
agent, one pass, one report.

For multi-domain projects (multiple `specs/SPEC-{domain}.md` files), the QA
agent may spawn per-domain sub-agents that run coverage and test audits in
parallel, then consolidate into a single `QA-REPORT.md`. The top-level QA
agent owns the final report and is responsible for cross-domain integration
findings that per-domain agents would miss.

## Inputs and Outputs

| Field              | Value                                        |
|--------------------|----------------------------------------------|
| **Required inputs**| Source code, `SPEC.md`                        |
| **Optional inputs**| `specs/`, `CLAUDE.md`                         |
| **Outputs**        | `QA-REPORT.md`                                |
| **Failure output** | `QA-REPORT.md` with `status: failed` + findings |

The skill reads `SPEC.md` (and domain specs in `specs/` when present) to
extract acceptance criteria. It reads `CLAUDE.md` for test commands, coverage
targets, and project conventions. Source code is required because there is
nothing to QA without it.

On failure, the skill still produces `QA-REPORT.md` documenting whatever
findings were collected before the failure. The report carries `status: failed`
so downstream consumers (the orchestrator, `/deploy`) know the gate did not
pass.

## Process

### Skill Parameters

For the sections referenced in [GLOBAL-REFERENCE.md](GLOBAL-REFERENCE.md):

- `{PHASE_NAME}` = `qa`
- `{OUTPUT_FILES}` = `["QA-REPORT.md"]`

Read and follow the **Settings Protocol** and **State Tracking** sections in
[GLOBAL-REFERENCE.md](GLOBAL-REFERENCE.md).

**Additional state fields for this skill:**

On failure, also include:
- `"outputs": ["QA-REPORT.md"]` (partial report is still produced)

### Step 1 — Coverage Analysis

Run the test suite with coverage instrumentation using the commands from
`CLAUDE.md`.

1. Measure line, branch, and function coverage per domain.
2. Identify untested code paths — list specific files and functions lacking
   coverage.
3. Compare against the coverage target from `CLAUDE.md` (default: 100% if
   unspecified).
4. Record raw coverage numbers for the report.

If the test suite fails to run at all (missing dependencies, broken config),
halt and produce a `QA-REPORT.md` with `status: failed` and the failure
reason.

### Step 2 — Test Quality Audit

Review existing tests for substance, not just existence.

- **Meaningful assertions.** Tests that only check "it doesn't throw" are
  flagged. Every test must assert on observable behavior. A test that calls a
  function without checking the result is not a test — it is coverage padding.
- **Edge case coverage.** Check for null inputs, empty collections, boundary
  values, and concurrent access scenarios in the existing test suite.
- **Error path testing.** Verify that error and failure branches are tested,
  not just the happy path. Look for catch blocks, error returns, and rejection
  handlers that lack corresponding test cases.
- **Integration test isolation.** Confirm proper stubs/mocks and no test
  interdependency. Tests must pass in any order.
- **Mutation testing.** If the stack supports it (Stryker for JS/TS, mutmut
  for Python, cargo-mutants for Rust), run mutation testing to verify that
  tests actually catch bugs. Report the mutation score.

### Step 3 — Acceptance Criteria Verification

For each acceptance criterion in `SPEC.md` and `specs/SPEC-{domain}.md`:

1. Map the criterion to specific test(s) that verify it.
2. Run those tests and confirm they pass.
3. For criteria without corresponding tests, write the missing tests.
4. For criteria that cannot be automatically tested (require manual
   verification), document them and explain why.

Produce a criterion-by-criterion table with PASS / FAIL / MISSING status.
Every criterion must appear in the table — none may be silently skipped.

### Step 4 — Edge Case Hunting

Systematically probe beyond what existing tests cover. This step is where
real bugs are found. Steps 1-3 verify what is already tested; step 4 finds
what is missing.

Probe these categories methodically:

- **Input validation boundaries.** Min/max values, empty strings, special
  characters, oversized payloads, unicode edge cases.
- **Concurrent operations.** Race conditions, deadlocks, double-submit
  scenarios, interleaved writes.
- **Resource exhaustion.** Memory pressure, disk full, network timeouts,
  connection pool exhaustion.
- **State transitions.** Invalid transitions, interrupted operations
  mid-flight, partial failures, rollback correctness.
- **External dependency failures.** API down, malformed responses,
  certificate errors, DNS failures, slow responses exceeding timeouts.

Write tests for any edge cases discovered. If an edge case reveals a bug,
document it in the Issues Found section of the report AND fix it. The report
is the audit trail; the fix is the remediation. Both are required.

### Step 5 — Regression Check

Verify that all previously passing functionality still works.

1. Run the full test suite (not just new tests).
2. Compare results against any prior `QA-REPORT.md` if one exists.
3. Flag any tests that previously passed but now fail.
4. Flag any decrease in coverage compared to the prior report.

### Step 6 — Output

Write `QA-REPORT.md` following the template below. The report must be
written regardless of outcome — a failed QA run still produces a report
with `status: failed` and whatever findings were collected.

## QA-REPORT.md Template

```markdown
# QA Report — [Date]

## Summary

- **Overall status**: PASS / FAIL / PASS WITH WARNINGS
- **Tested commit**: [output of `git rev-parse HEAD`]
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

[Issues that block deployment — broken functionality, data loss risk,
security holes discovered during testing.]

### Major

[Issues that should be fixed before deployment — degraded UX, missing
error handling for common cases, performance problems.]

### Minor

[Issues that can ship but should be tracked — cosmetic problems, uncommon
edge cases, minor inconsistencies.]

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

[Prioritized list of what to fix before deploying. Reference specific
issues above.]
```

## Settings

```yaml
settings:
  - name: write_missing_tests
    type: boolean
    default: true
    description: >
      When QA finds acceptance criteria without corresponding tests
      (Step 3), automatically write the missing tests. When false, QA
      only reports the gaps without writing tests.
  - name: edge_case_hunting
    type: enum
    values: ["full", "light", "skip"]
    default: "full"
    description: >
      Depth of edge case hunting in Step 4. "full" probes all
      categories (input validation, concurrency, resource exhaustion,
      state transitions, external failures). "light" probes input
      validation and error paths only. "skip" disables edge case
      hunting (not recommended).
```

## Anti-Patterns

**Do not rubber-stamp.** A QA report that says PASS without evidence is
worse than no report. Every PASS must be backed by coverage numbers and
test results.

**Do not skip edge case hunting.** Step 4 is where real bugs are found.
Steps 1-3 verify what is already tested; step 4 finds what is missing.
Skipping it turns QA into a formality.

**Do not write trivial tests to inflate coverage.** Tests added during QA
must assert on meaningful behavior. A test that calls a function without
checking the result is coverage padding, not quality assurance. Tests must
verify observable behavior — return values, side effects, state changes,
error conditions.

**Do not ignore flaky tests.** A test that passes sometimes and fails
sometimes is a bug. Document it as a Major issue, not a minor annoyance.
Flaky tests erode trust in the entire suite.

**Do not conflate "tests pass" with "quality is good."** A project can
have 100% coverage and still be broken if the tests assert on the wrong
things. The test quality audit (step 2) exists precisely for this reason.

**Do not silently fix bugs.** If edge case hunting reveals a bug, document
it in the report AND fix it. The report is the audit trail; the fix is the
remediation. Both are required. A fix without documentation means the next
QA pass cannot verify the regression stayed fixed.

**Do not skip state tracking.** Even when invoked standalone (not via
`/genesis`), the skill must update `.factory/state.json`. This ensures the
orchestrator can detect that QA has been run if the user later invokes
`/genesis`.

**Do not report failures without investigation.** When tests fail, QA
investigates the root cause. "Test X failed" is not a finding — "Test X
failed because the handler does not check for null input on line 42" is a
finding. Diagnosis is part of the job.
