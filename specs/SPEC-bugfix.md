# /bugfix -- Structured Bug Triage and Compressed Pipeline

## Overview

The `/bugfix` skill provides a fast path from bug report to deployed fix, bypassing the
full spec phase that is designed for feature work. It produces a lightweight triage
document (`BUGFIX-{id}.md`) that serves as the contract for downstream skills, then
orchestrates a compressed pipeline: triage -> build -> QA -> security -> deploy.

`/bugfix` is independent of the main `/genesis` pipeline. It does not appear in the
9-phase sequence and does not modify the main pipeline's phase state. It maintains its
own state in a `bugfixes` namespace within `.factory/state.json`.

The fix must conform to the existing `SPEC.md` unless the triage determines the spec
itself is wrong, in which case the spec amendment is part of the bugfix deliverable.

---

## Contract

| Field               | Value                                                          |
|---------------------|----------------------------------------------------------------|
| **Required inputs** | Bug description (user-provided or agent-detected), source code |
| **Optional inputs** | `SPEC.md`, `specs/`, `CLAUDE.md`, CI failure logs              |
| **Outputs**         | `BUGFIX-{id}.md`, code changes (via `/build`), updated        |
|                     | `QA-REPORT.md`, `SECURITY.md`, `DEPLOY-RECEIPT.md`            |
| **Failure output**  | `BUGFIX-{id}.md` with `status: ABANDONED`, `ESCALATED`,       |
|                     | or `NOT_AN_ISSUE`                                              |

---

## Category

**Agentic skill** -- orchestrates a multi-phase pipeline. The `/bugfix` skill itself
handles triage (Steps 1-3), then delegates to existing skills (`/build`, `/qa`,
`/security`, `/deploy`) for execution. It is conversational during triage and autonomous
during pipeline execution.

---

## Triggering

### User-Initiated

The user invokes `/bugfix` directly with a bug description:

- `/bugfix the deploy receipt is missing the region field`
- `/bugfix CI is red after the last merge`
- `/bugfix` (no argument -- the skill asks for a description)

### Claude-Suggested

Claude may suggest `/bugfix` when a user describes a problem that appears to be a small,
well-scoped bug rather than a feature request. Claude should use judgment: if the problem
sounds like it touches multiple domains, requires new architecture, or needs design
exploration, recommend `/spec` instead.

The skill's description in its YAML frontmatter should trigger on phrases like "fix this
bug", "this is broken", "CI is failing", "there's an issue with", "quick fix", "patch",
"hotfix", or when the user describes a concrete defect in existing behavior.

### When NOT to Use /bugfix

- The problem requires new features or capabilities -> use `/spec`
- The problem is vague and needs discovery -> use `/spec` or `/ideation`
- The fix requires schema migrations -> likely needs `/spec` (guardrails will catch this)
- The problem spans 3+ domains -> likely needs `/spec` (guardrails will catch this)

---

## Process

### Skill Parameters

For the mandatory sections in [GLOBAL-REFERENCE.md](GLOBAL-REFERENCE.md):

- `{PHASE_NAME}` = `bugfix`
- `{OUTPUT_FILES}` = `["BUGFIX-{id}.md"]`

**Additional state fields for this skill:**

Bugfix state lives in a `bugfixes` array in `.factory/state.json`, not in the main
`phases` object. See [State Tracking](#state-tracking) for the full schema.

### Step 1 -- Bug Intake

Gather the bug report from the user. Normalize it into a structured representation:

1. **Symptom**: What is the observable wrong behavior? Be precise -- "the button
   doesn't work" is not a symptom. "Clicking Submit on the payment form returns a 500
   error with body `{error: 'null reference'}` " is a symptom.
2. **Expected behavior**: What should happen instead? Reference `SPEC.md` if it
   defines the expected behavior.
3. **Reproduction context**: How to trigger the bug. Environment, inputs, sequence of
   actions. If the user provides a CI log, extract the failing test or error.
4. **Severity assessment**: How bad is this?
   - **P0**: Production is broken for all/most users. Fix immediately.
   - **P1**: Significant functionality is degraded. Fix soon.
   - **P2**: Minor issue, workaround exists. Fix when convenient.

If the user's description is too vague, ask clarifying questions. Do not proceed to
Step 2 until the symptom is concrete and reproducible.

### Step 2 -- Root Cause Analysis (Agent Team)

Root cause analysis is performed by a two-agent team working in parallel.
The `/bugfix` skill spawns both agents simultaneously and they communicate
via `SendMessage` to converge on a diagnosis.

#### Agent Roles

| Agent | Role | Focus |
|-------|------|-------|
| **RCA Specialist** | Root cause analysis expert | Traces symptoms to failure points. Reads stack traces, error logs, test output. Identifies the code path that produces the wrong behavior. Classifies the root cause type. |
| **Domain Expert** | Backend, Frontend, DevOps, etc. (selected based on where the bug manifests) | Understands the domain's architecture, conventions, and spec. Validates the RCA agent's findings against the spec and domain knowledge. Identifies affected files and proposes the fix approach. |

#### Agent Selection

The `/bugfix` skill selects the domain expert based on where the symptom
manifests:

- API error, database issue, business logic -> **Backend**
- UI rendering, state management, routing -> **Frontend**
- CI failure, deployment issue, infra -> **DevOps**
- Auth failure, permission error, token issue -> **Security**
- Test failure unrelated to a specific domain -> **QA**

If the bug spans two domains (e.g., a frontend bug caused by a backend
contract change), spawn the RCA Specialist plus both domain experts (3
agents total).

#### Agent Workflow

1. Both agents receive the bug intake from Step 1 (symptom, expected
   behavior, reproduction context, severity).
2. **RCA Specialist** traces the failure:
   - Reads error logs, stack traces, test output
   - Identifies the specific file(s) and line(s) where the bug originates
   - Proposes a root cause classification
   - Sends findings to the Domain Expert via `SendMessage`
3. **Domain Expert** validates and extends:
   - Reads `SPEC.md` and relevant `specs/SPEC-{domain}.md` to understand
     intended behavior
   - Confirms or challenges the RCA Specialist's findings
   - Maps all affected files (including tests)
   - Proposes the fix approach based on domain knowledge
   - Sends findings back to the RCA Specialist via `SendMessage`
4. Both agents converge on a joint diagnosis. If they disagree, the
   `/bugfix` skill presents both perspectives to the user for resolution.

#### Root Cause Classification

The agents classify the root cause as one of:

- **Code bug**: The spec is correct but the implementation is wrong.
- **Spec bug**: The spec is wrong or incomplete, and the code faithfully
  implements the wrong spec. The fix includes a spec amendment.
- **Missing spec**: The spec doesn't cover this case at all. The fix
  includes a spec addition.
- **Not an issue**: The reported behavior is actually correct. The spec
  confirms it, the code implements it faithfully, and the reporter's
  expectation was wrong. Close the bugfix with an explanation.

#### Output

The agent team produces:

- Root cause classification and explanation
- File-level mapping of all affected code and tests
- Proposed fix approach
- Spec conformance assessment (conforms / amendment needed)

If the root cause is "Not an issue", skip to Step 3 and produce the triage
document with `status: NOT_AN_ISSUE`. No build, QA, security, or deploy
phases run.

### Step 3 -- Scope Assessment and Triage Document

Assess the fix complexity and produce the triage document.

#### Scope Assessment

Evaluate the fix using these heuristics:

| Signal | Size | Action |
|--------|------|--------|
| 1-2 source files, single domain, no schema changes | **S** | Proceed with `/bugfix` |
| 3-5 source files, single domain, no schema changes | **M** | Proceed with `/bugfix` |
| 6+ source files, OR multi-domain, OR schema migration, OR new API surface | **L** | Recommend escalation to `/spec` |

When the assessment is **L**, present the recommendation to the user:

```text
This fix is larger than a typical bugfix:
- Touches [N] files across [N] domains
- [Requires schema migration / Adds new API surface / etc.]

I recommend running /spec to design the solution properly.
Proceed with /bugfix anyway? [escalate to /spec / continue]
```

If the user chooses to continue despite the recommendation, proceed but document the
override in the triage document. If the user escalates, set the bugfix status to
`ESCALATED` and exit.

#### Triage Document

Write `BUGFIX-{id}.md` using the output template below. The ID is a zero-padded
sequential number derived from the count of existing `BUGFIX-*.md` files in the
working directory (e.g., `BUGFIX-001.md`, `BUGFIX-002.md`).

The triage document is the contract that downstream skills consume. It replaces
`SPEC.md` as the primary input for the bugfix pipeline, though downstream skills
still reference `SPEC.md` for conformance.

Present the triage document to the user for confirmation before proceeding:

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

Invoke `/build` with a scoped task derived from the triage document:

1. **Team sizing**: Based on the scope assessment:
   - **S**: Single agent. No architect overhead.
   - **M**: 2-3 agents. Architect assigns based on affected domains.
2. **Task description**: The triage document's root cause, proposed fix, affected
   files, and acceptance criteria. Include the spec conformance note.
3. **Spec amendments**: If the triage identified a spec bug, the build task includes
   updating the relevant spec file(s) as part of the same PR.
4. **Standard build rules apply**: Worktree isolation, PR workflow, squash before
   merge. All conventions from `CLAUDE.md` are followed.

The build phase produces the fix as a merged PR on main.

### Step 5 -- QA

Invoke `/qa` with the bugfix context:

1. `/qa` reads `BUGFIX-{id}.md` for the acceptance criteria specific to this fix.
2. `/qa` prioritizes regression testing: verify the bug is fixed first, then verify
   nothing else broke.
3. The full QA conformance suite runs as normal -- regression prioritization is about
   ordering, not scope reduction.
4. `/qa` still reads `SPEC.md` for the full acceptance criteria of the project.

### Step 6 -- Security

Invoke `/security` as normal. The security review covers:

1. The changes introduced by the bugfix (new code paths, changed data flows).
2. Whether the fix introduces any new attack surfaces.
3. Full dependency and secrets audit as usual.

If the bugfix amended the spec, the threat model should account for the changed
behavior.

### Step 7 -- Deploy

Invoke `/deploy`. The user picks the target environment as usual. The standard
promotion model applies (alpha -> staging -> prod). Gate checks verify `QA-REPORT.md`
and `SECURITY.md` against current HEAD as normal.

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

Bugfix state is tracked in a `bugfixes` array within `.factory/state.json`. Each
bugfix is an independent pipeline that does not interfere with the main `phases` state.

### Schema

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
        "triage": {
          "status": "completed",
          "completed_at": "2026-04-04T10:15:00Z"
        },
        "build": {
          "status": "in_progress",
          "started_at": "2026-04-04T10:15:00Z"
        },
        "qa": { "status": "pending" },
        "security": { "status": "pending" },
        "deploy": { "status": "pending" }
      }
    }
  ]
}
```

### Status Values

The top-level bugfix `status` can be:

- `in_progress` -- bugfix pipeline is active
- `completed` -- fix deployed (or deploy skipped by user)
- `failed` -- a phase failed and the user chose not to retry
- `escalated` -- scope guardrails triggered and user chose to escalate to `/spec`
- `abandoned` -- user chose to abandon the bugfix
- `not_an_issue` -- triage determined the reported behavior is correct

### On Start

Append a new entry to the `bugfixes` array with `status: in_progress` and the triage
phase set to `in_progress`.

### On Phase Transitions

Update the relevant phase within the bugfix entry. Follow the same
`in_progress` / `completed` / `failed` pattern as the main pipeline.

### On Completion

Set the top-level bugfix `status` to `completed` with a `completed_at` timestamp.

---

## BUGFIX-{id}.md Output Template

```markdown
# Bugfix {id} -- [Short Description]

## Bug Report
- **Symptom**: [Precise description of wrong behavior]
- **Expected behavior**: [What should happen, with spec reference if applicable]
- **Severity**: P0 / P1 / P2
- **Reported by**: User / CI / Agent
- **Reproduction**: [Steps or CI log excerpt]

## Root Cause
- **Type**: Code bug / Spec bug / Missing spec / Not an issue
- **Location**: [file:line, or N/A if not an issue]
- **Explanation**: [Why the code produces the wrong behavior, or why the
  behavior is actually correct]

## Proposed Fix
- **Description**: [What changes and why]
- **Affected files**: [List of files to modify, including tests]
- **Size**: S / M (/ L if user overrode escalation)
- **Spec conformance**: Conforms / Amendment needed
- **Spec changes**: [If amendment needed: which spec file, which section, what changes]

## Acceptance Criteria
| Criterion | How to verify |
|-----------|---------------|
| [Bug is fixed] | [Specific test or check] |
| [No regressions] | [What to verify didn't break] |
| [Spec updated] | [If applicable: spec section matches new behavior] |

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

## Constraints

- `/bugfix` never modifies the main `phases` state in `.factory/state.json`. The main
  pipeline and bugfix pipelines are independent.
- `/bugfix` always produces `BUGFIX-{id}.md`, even on failure or abandonment. The
  triage doc is the audit trail.
- The fix must conform to `SPEC.md` unless the triage explicitly identifies a spec bug.
  Spec amendments are part of the fix, not a separate effort.
- `/bugfix` does not run `/retro`. Bugfixes are small and scoped; retrospectives are
  for build phases with team coordination.
- `/bugfix` does not run `/ideation`, `/spec`, `/prototype`, or `/setup`. These are
  feature-development phases.

---

## Scenarios

### Scenario 1: Simple Code Bug

1. User: `/bugfix the health check endpoint returns 503 instead of 200`
2. Triage: Reads the health check handler, finds a missing database connection check
   that throws when the pool is warming up. Size S, 1 file.
3. Build: Single agent fixes the handler, adds a test.
4. QA: Regression-first -- verifies health check returns 200, then runs full suite.
5. Security: No new attack surface. CLEAR.
6. Deploy: User picks staging, then promotes to prod.
7. `BUGFIX-001.md` records the full trail.

### Scenario 2: Spec Bug

1. User: `/bugfix the API returns 404 for archived items but the spec says they should return 410 Gone`
2. Triage: Reads spec, confirms spec says 410. Reads code, finds it returns 404.
   Wait -- re-reads the HTTP spec. 410 is correct for permanently removed resources,
   but archived items are not removed. Root cause: the spec is wrong. Archived items
   should return 200 with an `archived: true` field.
3. Triage doc flags: Spec bug. Amendment: update SPEC-api.md section on archived items.
4. Build: Fix the handler to return 200 with `archived: true`. Update SPEC-api.md.
   Both changes in the same PR.
5. QA, Security, Deploy proceed as normal.

### Scenario 3: Scope Escalation

1. User: `/bugfix notifications are broken`
2. Triage: Investigates. The notification system touches the event bus, the
   notification service, the email provider integration, and the frontend toast system.
   4 domains, 12+ files.
3. Guardrails: Size L. Recommends escalation.
4. User agrees. Bugfix status set to `ESCALATED`. User runs `/spec` to design the fix.

### Scenario 4: Not an Issue

1. User: `/bugfix the search API returns results in random order`
2. Triage: Reads the spec. SPEC-api.md explicitly states "search results are returned
   in relevance order, which is non-deterministic for equal-relevance items." The code
   is correct. The user expected alphabetical ordering, but the spec does not guarantee it.
3. Root cause: Not an issue. The behavior matches the spec.
4. Triage doc written with `status: NOT_AN_ISSUE` and explanation. No build, QA,
   security, or deploy phases run.
5. User informed: "This is working as specified. If you want deterministic ordering for
   equal-relevance items, that's a feature request -- run `/spec` to design it."

### Scenario 5: CI Failure

1. User: `/bugfix CI is red -- here's the log` (pastes log)
2. Triage: Parses the log. A dependency update broke the date formatter. The test
   `formatDate.test.ts` fails because `dayjs` 2.0 changed the default locale format.
3. Size S. Fix: pin `dayjs` to 1.x or update the format string.
4. Build, QA, Security, Deploy proceed.

---

## Anti-Patterns

- **Do not skip triage.** Jumping straight to a fix without understanding the root
  cause leads to patches that mask the real problem. The triage document exists to
  force this discipline.

- **Do not ignore scope guardrails.** When the assessment says L, take it seriously.
  A large fix crammed through `/bugfix` without proper design will create more bugs
  than it fixes.

- **Do not treat spec amendments as optional.** If the triage identifies a spec bug,
  the spec update is part of the fix. A code-only fix that leaves the spec wrong will
  confuse future development.

- **Do not skip QA or security.** The compressed pipeline skips ideation, spec,
  prototype, setup, and retro. It does NOT skip QA or security. These gates exist to
  prevent broken or insecure code from reaching production.

- **Do not bypass the user on escalation.** When guardrails recommend escalation to
  `/spec`, present the recommendation and let the user decide. Do not silently escalate
  or silently continue.

- **Do not modify main pipeline state.** Bugfix state lives in the `bugfixes` array.
  The main `phases` object tracks the feature pipeline and must not be touched by
  `/bugfix`.

---

## Decision Log

| Decision | Rationale | Reversible |
|----------|-----------|------------|
| Sequential IDs (001, 002, ...) | Simple, human-readable, avoids collisions. Date-based IDs are ambiguous when multiple bugfixes happen on the same day. | Yes |
| Bugfixes array in state.json | Keeps bugfix state co-located with main state for recovery. Separate files would scatter state. Array supports concurrent bugfixes. | Yes |
| No /retro for bugfixes | Bugfixes are small and scoped. Retro overhead is disproportionate. User can always run /retro manually. | Yes |
| Spec amendments inline | The spec bug IS the bugfix. Splitting into separate efforts adds coordination cost for no benefit. | Yes |
| Auto-deploy setting defaults to false | Deploying a bugfix without explicit user confirmation is risky. Power users can opt in. | Yes |

---

## Open Questions

None. The design is fully resolved from ideation.
