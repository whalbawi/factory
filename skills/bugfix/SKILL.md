---
name: bugfix
description: Use when the user says "fix this bug", "this is broken", "CI is failing",
  "there's an issue with", "quick fix", "patch", "hotfix", or describes a concrete
  defect in existing behavior. Also use when Claude detects a small, well-scoped bug
  that does not require full specification. This skill triages bugs, produces a
  lightweight fix plan, and orchestrates a compressed pipeline (build -> QA -> security
  -> deploy) that bypasses the spec phase. Do not use for feature requests, vague
  problems needing discovery, or large changes spanning 3+ domains -- those need /spec.
---

# /bugfix -- Structured Bug Triage and Compressed Pipeline

Fast path from bug report to deployed fix. Produces a `BUGFIX-{id}.md` triage
document that serves as the contract for downstream skills, then orchestrates
build -> QA -> security -> deploy without running the full spec phase.

`/bugfix` is independent of the main `/genesis` pipeline. It does not appear
in the 9-phase sequence and does not modify the main pipeline's phase state.

The fix must conform to the existing `SPEC.md` unless the triage determines
the spec itself is wrong, in which case the spec amendment is part of the
bugfix deliverable.

**Parameter**: bug description (optional -- the skill will ask if not
provided).

---

## Inputs and Outputs

| Field               | Value                                                     |
|---------------------|-----------------------------------------------------------|
| **Required inputs** | Bug description (user or agent), source code              |
| **Optional inputs** | `SPEC.md`, `specs/`, `CLAUDE.md`, CI failure logs         |
| **Outputs**         | `BUGFIX-{id}.md`, code changes (via `/build`), updated   |
|                     | `QA-REPORT.md`, `SECURITY.md`, `DEPLOY-RECEIPT.md`       |
| **Failure output**  | `BUGFIX-{id}.md` with status `ABANDONED`, `ESCALATED`,   |
|                     | or `NOT_AN_ISSUE`                                         |

---

## Process

### Skill Parameters

Read and execute ALL [MANDATORY] sections in [GLOBAL-REFERENCE.md](GLOBAL-REFERENCE.md):

- `{PHASE_NAME}` = `bugfix`
- `{OUTPUT_FILES}` = `["BUGFIX-{id}.md"]`

**Additional state fields for this skill:**

Bugfix state lives in a `bugfixes` array in `.factory/state.json`, not in the
main `phases` object. See the [State Tracking](#state-tracking) section for
the full schema.

### Step 1 -- Bug Intake

Gather the bug report and normalize it into a structured representation.

1. **Symptom**: The observable wrong behavior. Be precise -- "the button
   doesn't work" is not a symptom. "Clicking Submit returns a 500 with
   `{error: 'null reference'}`" is a symptom. If the user's description
   is vague, ask clarifying questions until the symptom is concrete.
2. **Expected behavior**: What should happen instead. Reference `SPEC.md`
   if it defines the expected behavior.
3. **Reproduction context**: How to trigger the bug -- environment, inputs,
   sequence of actions. If the user provides a CI log, extract the failing
   test or error from it.
4. **Severity**:
   - **P0**: Production is broken for all/most users. Fix immediately.
   - **P1**: Significant functionality is degraded. Fix soon.
   - **P2**: Minor issue, workaround exists. Fix when convenient.

Do not proceed to Step 2 until the symptom is concrete and reproducible.

### Step 2 -- Root Cause Analysis (Agent Team)

Spawn a two-agent team to diagnose the bug. Both agents run in parallel
and communicate via `SendMessage` to converge on a diagnosis.

#### Agents

| Agent | Focus |
|-------|-------|
| **RCA Specialist** | Traces symptoms to failure points. Reads stack traces, error logs, test output. Identifies the code path that produces the wrong behavior. Classifies the root cause type. |
| **Domain Expert** | Selected based on where the bug manifests (Backend for API/DB/logic, Frontend for UI/state/routing, DevOps for CI/deploy/infra, Security for auth/permissions, QA for test failures). Validates findings against the spec and domain architecture. Maps affected files and proposes the fix approach. |

If the bug spans two domains, spawn the RCA Specialist plus both relevant
domain experts (3 agents total).

#### Workflow

1. Both agents receive the bug intake from Step 1.
2. **RCA Specialist** traces the failure -- reads error logs, identifies
   the origin file(s) and line(s), proposes a root cause classification.
   Sends findings to the Domain Expert.
3. **Domain Expert** validates -- reads `SPEC.md` and domain specs,
   confirms or challenges the RCA findings, maps all affected files
   (including tests), proposes the fix approach. Sends back to RCA.
4. Agents converge on a joint diagnosis. If they disagree, present both
   perspectives to the user for resolution.

#### Root Cause Classification

The agents classify the root cause as one of:

- **Code bug**: The spec is correct but the implementation is wrong.
- **Spec bug**: The spec is wrong or incomplete, and the code faithfully
  implements the wrong spec. The fix includes a spec amendment.
- **Missing spec**: The spec doesn't cover this case. The fix includes
  a spec addition.
- **Not an issue**: The reported behavior is actually correct. The spec
  confirms it, the code implements it faithfully, and the reporter's
  expectation was wrong.

#### Output

The agent team produces: root cause classification and explanation,
file-level mapping of affected code and tests, proposed fix approach,
and spec conformance assessment.

If the root cause is "Not an issue", skip to Step 3 and produce the
triage doc with `status: NOT_AN_ISSUE`. No build, QA, security, or
deploy phases run.

### Step 3 -- Scope Assessment and Triage Document

Assess fix complexity and produce the triage document.

#### Scope Assessment

| Signal | Size | Action |
|--------|------|--------|
| 1-2 source files, single domain, no schema changes | **S** | Proceed |
| 3-5 source files, single domain, no schema changes | **M** | Proceed |
| 6+ files, OR multi-domain, OR schema migration, OR new API surface | **L** | Recommend escalation |

When the assessment is **L**, present the recommendation:

```text
This fix is larger than a typical bugfix:
- Touches [N] files across [N] domains
- [Requires schema migration / Adds new API surface / etc.]

I recommend running /spec to design the solution properly.
Proceed with /bugfix anyway? [escalate to /spec / continue]
```

If the user escalates, set the bugfix status to `ESCALATED` and exit.
If the user continues despite the recommendation, document the override in
the triage document.

#### Write the Triage Document

Write `BUGFIX-{id}.md` using the output template below. The ID is a
zero-padded sequential number derived from the count of existing
`BUGFIX-*.md` files (e.g., `BUGFIX-001.md`, `BUGFIX-002.md`).

Present the triage document to the user for confirmation:

```text
Here's the triage for this bug:

- Root cause: [one sentence]
- Fix: [one sentence]
- Size: S/M
- Files: [list]
- Spec impact: None / Amendment needed

Proceed to build? [Y / revise / abandon]
```

### Step 4 -- Build

Invoke `/build` with a scoped task derived from the triage document.

1. **Team sizing** based on scope:
   - **S**: Single agent. No architect overhead.
   - **M**: 2-3 agents. Architect assigns based on affected areas.
2. **Task description**: The triage document's root cause, proposed fix,
   affected files, and acceptance criteria.
3. **Spec amendments**: If the triage identified a spec bug, updating the
   relevant spec file(s) is part of the same PR -- the spec fix IS the
   bugfix.
4. **Standard build rules apply**: Worktree isolation, PR workflow, squash
   before merge. All conventions from `CLAUDE.md` are followed.

The build phase produces the fix as a merged PR on main.

### Step 5 -- QA

Invoke `/qa` with the bugfix context.

1. `/qa` reads `BUGFIX-{id}.md` for acceptance criteria specific to this
   fix.
2. `/qa` prioritizes regression testing: verify the bug is fixed first,
   then verify nothing else broke.
3. The full QA conformance suite runs as normal -- regression
   prioritization is about ordering, not scope reduction.
4. `/qa` still reads `SPEC.md` for the full project acceptance criteria.

### Step 6 -- Security

Invoke `/security` as normal. The review covers:

1. Changes introduced by the bugfix (new code paths, changed data flows).
2. Whether the fix introduces any new attack surfaces.
3. Full dependency and secrets audit as usual.

If the bugfix amended the spec, the threat model accounts for the changed
behavior.

### Step 7 -- Deploy

Invoke `/deploy`. The user picks the target environment. The standard
promotion model applies (alpha -> staging -> prod). Gate checks verify
`QA-REPORT.md` and `SECURITY.md` against current HEAD as normal.

### Step 8 -- Completion

After deploy (or if the user skips deploy):

1. Update the bugfix state to `completed`.
2. Present a summary:

```text
Bugfix complete.

- Bug: [symptom]
- Fix: [one sentence]
- PR: #[number]
- QA: PASS
- Security: CLEAR
- Deployed to: [environment]
```

---

## State Tracking

Bugfix state lives in a `bugfixes` array within `.factory/state.json`,
separate from the main `phases` object. Each bugfix is an independent
pipeline.

**On start**, append a new entry:

```json
{
  "bugfixes": [
    {
      "id": "001",
      "status": "in_progress",
      "started_at": "2026-04-04T10:00:00Z",
      "symptom": "Deploy receipt missing region field",
      "severity": "P2",
      "size": "S",
      "triage_doc": "BUGFIX-001.md",
      "phases": {
        "triage": { "status": "in_progress", "started_at": "..." },
        "build": { "status": "pending" },
        "qa": { "status": "pending" },
        "security": { "status": "pending" },
        "deploy": { "status": "pending" }
      }
    }
  ]
}
```

**On phase transitions**, update the relevant phase within the bugfix entry
using the same `in_progress` / `completed` / `failed` pattern as the main
pipeline.

**On completion**, set the top-level `status` to `completed` with a
`completed_at` timestamp.

**Status values** for the top-level bugfix:

- `in_progress` -- pipeline is active
- `completed` -- fix deployed (or deploy skipped by user)
- `failed` -- a phase failed and the user chose not to retry
- `escalated` -- guardrails triggered and user chose `/spec`
- `abandoned` -- user chose to abandon
- `not_an_issue` -- triage determined the behavior is correct

---

## BUGFIX-{id}.md Output Template

```markdown
# Bugfix {id} -- [Short Description]

## Bug Report
- **Symptom**: [Precise description of wrong behavior]
- **Expected behavior**: [What should happen, with spec reference]
- **Severity**: P0 / P1 / P2
- **Reported by**: User / CI / Agent
- **Reproduction**: [Steps or CI log excerpt]

## Root Cause
- **Type**: Code bug / Spec bug / Missing spec / Not an issue
- **Location**: [file:line, or N/A if not an issue]
- **Explanation**: [Why the code produces the wrong behavior, or why
  the behavior is actually correct]

## Proposed Fix
- **Description**: [What changes and why]
- **Affected files**: [List of files to modify, including tests]
- **Size**: S / M (/ L if user overrode escalation)
- **Spec conformance**: Conforms / Amendment needed
- **Spec changes**: [If amendment needed: which file, section, changes]

## Acceptance Criteria
| Criterion | How to verify |
|-----------|---------------|
| [Bug is fixed] | [Specific test or check] |
| [No regressions] | [What to verify didn't break] |
| [Spec updated] | [If applicable] |

## Scope Override
_(Only present if user overrode an L-size escalation recommendation.)_
- **Recommended**: Escalate to /spec
- **User decision**: Continue with /bugfix
- **Reason**: [User's rationale]
```

---

## Settings

```yaml
settings:
  - name: auto_deploy
    type: boolean
    default: false
    description: >
      After QA and security pass, automatically invoke /deploy without
      prompting the user. When false (default), the skill presents the
      results and asks whether to proceed to deployment.
```

---

## Anti-Patterns

- **Skipping triage.** Jumping straight to a fix without understanding the
  root cause leads to patches that mask the real problem. The triage
  document forces this discipline.
- **Ignoring scope guardrails.** When the assessment says L, take it
  seriously. A large fix crammed through `/bugfix` without proper design
  will create more bugs than it fixes.
- **Treating spec amendments as optional.** If the triage identifies a spec
  bug, the spec update is part of the fix. A code-only fix that leaves the
  spec wrong will confuse future development.
- **Skipping QA or security.** The compressed pipeline skips ideation, spec,
  prototype, setup, and retro. It does NOT skip QA or security. These gates
  prevent broken or insecure code from reaching production.
- **Bypassing the user on escalation.** When guardrails recommend `/spec`,
  present the recommendation and let the user decide. Do not silently
  escalate or silently continue.
- **Modifying main pipeline state.** Bugfix state lives in the `bugfixes`
  array. The main `phases` object tracks the feature pipeline and must not
  be touched by `/bugfix`.
- **Skipping the triage doc.** Always produce `BUGFIX-{id}.md`, even on
  failure, abandonment, or "not an issue." The triage doc is the audit
  trail.
