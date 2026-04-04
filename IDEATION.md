# Ideation: Factory -- 2026-04-04

## Context

Factory's pipeline is optimized for feature development: ideation -> spec -> prototype -> setup ->
build -> retro -> qa -> security -> deploy. When a bug is found post-deploy, the user must either
run the full pipeline (overkill for a small fix) or skip `/spec` and break downstream skills that
depend on pipeline state continuity. There is no structured path for small, well-understood changes
that need to bypass the spec phase while still getting proper QA, security review, and deployment.

## Ideas Explored

### 1. Lightweight Triage Document

- **Description**: `/bugfix` produces a `BUGFIX-{id}.md` triage doc that serves as a spec-
  equivalent contract for downstream skills.
- **Problem**: Spec is overkill for small fixes; skipping spec breaks the pipeline.
- **Effort**: M
- **Impact**: H
- **Feasibility**: Follows existing SKILL.md patterns. Needs a triage template that `/build`,
  `/qa`, `/security` can consume as an alternative to `SPEC.md`.
- **Dependencies**: Downstream skills must accept `BUGFIX-{id}.md` as input.

### 2. Scope Guardrails

- **Description**: Built-in complexity assessment during triage that estimates fix size (S/M/L)
  and recommends escalation to `/spec` when a fix exceeds the threshold.
- **Problem**: No mechanism for scope judgment -- bugs that grow into features need an off-ramp.
- **Effort**: S
- **Impact**: H
- **Feasibility**: Heuristics from codebase read (file count, domain boundaries, test surface).
  No external tooling needed.
- **Dependencies**: None -- internal to `/bugfix`.

### 3. Multi-Entry Triggers

- **Description**: `/bugfix` accepts input from multiple sources (user description, GitHub Issue
  URL, CI failure log, agent-detected error) with per-source parsers that normalize into a common
  bug representation.
- **Problem**: Bugs come from many sources; a skill that only accepts prose misses CI/agent/backlog
  paths.
- **Effort**: M
- **Impact**: M
- **Feasibility**: GitHub Issues via `gh issue view`, CI logs via `gh run view`. Agent detection
  needs a convention. Backlog integration is extensible.
- **Dependencies**: `gh` CLI for GitHub-sourced bugs.

### 4. Adaptive Build Team

- **Description**: `/bugfix` invokes `/build` with a right-sized team based on triage assessment
  -- single agent for trivial fixes, small team for multi-file fixes.
- **Problem**: Full agent team is overhead for a one-line fix; single agent misses cross-cutting
  concerns on larger fixes.
- **Effort**: S
- **Impact**: M
- **Feasibility**: `/build` already supports variable team sizes. `/bugfix` passes a team size
  recommendation and scoped task description.
- **Dependencies**: `/build` skill, triage output.

### 5. Pipeline Short-Circuit

- **Description**: `/bugfix` orchestrates a compressed pipeline (triage -> build -> qa -> security
  -> deploy), skipping ideation, spec, prototype, setup, and retro.
- **Problem**: Skipping spec breaks the pipeline -- downstream skills lose state continuity.
- **Effort**: M
- **Impact**: H
- **Feasibility**: Needs a `bugfix` pipeline mode in `.factory/state.json`. Gate checks already
  work off report files, not spec. Downstream skills need acceptance criteria from the triage doc.
- **Dependencies**: State tracking changes, triage document.

### 6. Regression-First QA

- **Description**: When `/qa` runs after a bugfix, it prioritizes regression testing (verify the
  fix, verify nothing broke) before running the full conformance suite.
- **Problem**: Full QA is needed but should prioritize the fix area first for fast feedback.
- **Effort**: S
- **Impact**: M
- **Feasibility**: `/qa` already supports scoped runs. Triage doc's acceptance criteria serve as
  the focused test plan. Full suite still runs after regression check.
- **Dependencies**: Triage document, `/qa` skill.

### 7. Fix Verification Loop

- **Description**: After the build agent implements the fix, `/bugfix` runs reproduction steps
  from the triage doc to verify the fix before handing off to `/qa`.
- **Problem**: Without defined reproduction steps, you don't know if the fix works until full QA.
- **Effort**: S
- **Impact**: M
- **Feasibility**: Reproduction steps are part of the triage doc. Verification is running those
  steps and checking output.
- **Dependencies**: Triage document.

## Selected for Development

### /bugfix -- Structured Bug Triage and Compressed Pipeline

Ideas 1, 2, and 5 bundled as the core skill. Ideas 4 and 6 are implementation details within
the bundle. Idea 3 is a future extension. Idea 7 is QA's responsibility.

- **Scenarios**:
  - User reports "deploy receipt is missing the region field." `/bugfix` reads the codebase,
    identifies root cause, produces `BUGFIX-{id}.md` with fix approach and acceptance criteria,
    then drives through build -> QA -> security -> deploy.
  - User reports "auth is broken for all users." `/bugfix` triages, determines the fix spans 3
    domains and requires a migration. Guardrails flag it as L-sized and recommend escalation to
    `/spec`.
  - During triage, `/bugfix` discovers the spec itself is wrong. The triage doc flags the spec
    deviation and the fix includes a spec amendment.
  - CI goes red after a dependency update. User pastes the log. `/bugfix` parses the failure,
    identifies the breaking change, proposes a fix, and runs the compressed pipeline.

- **Technical approach**:
  - **Triage phase**: Read bug description + relevant source + `SPEC.md`. Produce `BUGFIX-{id}.md`
    with symptom, root cause, proposed fix, affected files, acceptance criteria, and spec
    conformance check.
  - **Scope assessment**: Heuristics -- file count, domain count, migration needs. S = 1-2 files,
    single domain. M = 3-5 files, single domain. L = multi-domain or migration, recommend
    escalation to `/spec`.
  - **Compressed pipeline**: `bugfix` state in `.factory/state.json` with phases: triage -> build
    -> qa -> security -> deploy. Each downstream skill reads `BUGFIX-{id}.md` as input but still
    references `SPEC.md` for conformance.
  - **Adaptive team**: Pass team size to `/build` based on triage. S = single agent. M = 2-3
    agents. L = escalate.
  - **The fix must conform to the existing SPEC.md** unless the triage determines the spec is
    wrong, in which case the spec amendment is part of the fix.

- **Risks**:
  - Downstream skill compatibility: `/qa` and `/security` currently expect `SPEC.md`. They need
    to accept `BUGFIX-{id}.md` as an alternative or the triage doc must reference relevant spec
    sections.
  - State model: Bugfix pipelines run alongside the main pipeline state. May need a `bugfixes`
    array or separate namespace in `.factory/state.json`.
  - Spec amendments: When a bugfix corrects the spec, the fix PR and spec amendment PR need
    coordination.
  - ID generation: `BUGFIX-{id}` needs a stable, human-readable scheme (sequential, date-based,
    or description-derived).

- **Next step**: Feed into `/spec`

## Parked Ideas

- **Multi-Entry Triggers (3)**: Valuable but not core. Adding parsers for GitHub Issues, CI logs,
  and agent-detected errors is a natural extension once the base skill works. Kept for future
  ideation.
- **Fix Verification Loop (7)**: Reproduction step verification is QA's responsibility. The triage
  doc's acceptance criteria feed into `/qa` directly.
