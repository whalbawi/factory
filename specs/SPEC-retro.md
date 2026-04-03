# /retro — Team Retrospective and Process Synthesis

`/retro` gathers status from all agents and progress artifacts, surfaces coordination
issues, checks cross-agent alignment, and produces an actionable retrospective report.
It is a synthesis skill — it does not modify code or project artifacts. Its value is in
making the invisible visible: coordination failures, scope drift, quality trends, and
velocity patterns that no single agent can see on its own.

## Contract

| Field | Value |
|-------|-------|
| **Required inputs** | At least one completed phase (any phase with `status: completed` in `.factory/state.json`) |
| **Optional inputs** | `PROGRESS.md`, `PROGRESS-{PREFIX}.md` files, all phase output files (`SPEC.md`, `QA-REPORT.md`, `SECURITY.md`, etc.) |
| **Outputs** | `RETRO-{date}.md` (date format: `YYYY-MM-DD`) |
| **Failure mode** | Retro summary with gaps noted — missing files are flagged but do not block the retro |

## Category

**Conversational skill** (synthesis and discussion).

`/retro` is interactive. It presents findings to the user, invites discussion, and
refines recommendations based on user input. It does not spawn sub-agents or execute
procedural steps silently.

## Pipeline Position

`/retro` is **mandatory** after `/build` in the v1 pipeline. The full v1 pipeline is:

```
/ideation -> /spec -> /prototype -> /setup -> /build -> /retro -> /qa -> /security -> /deploy
```

`/retro` cannot be skipped when running the full `/factory` pipeline. It serves as a
checkpoint between construction and quality gates — a deliberate pause to assess process
health before evaluating product quality.

`/retro` can also be invoked **standalone at any time** during development. Standalone
invocations do not affect pipeline state progression — they produce a `RETRO-{date}.md`
report but do not advance or block the pipeline. This makes `/retro` useful for mid-build
check-ins, ad hoc team syncs, or post-deploy reviews.

**Trigger patterns**: "team sync", "standup", "retrospective", "retro", "how's the team",
"status check"

## Process

### Step 1: Gather Status

Read all `PROGRESS-{PREFIX}.md` files and the rolled-up `PROGRESS.md`. For each agent
and task, identify:

- **Completed tasks** since the last retro (or since project start if no prior retro)
- **In-progress tasks** and their current status, blockers, and estimated completion
- **Blocked tasks** and the nature of each blocker (dependency, unclear spec, external,
  technical)
- **Overdue tasks** — tasks that have taken significantly longer than their difficulty
  rating suggests

If `PROGRESS.md` or agent-specific progress files are missing, note the gap and work
with whatever status information is available (git log, output files, state.json).

### Step 2: Surface Issues

Analyze the gathered status for systemic problems:

- **Coordination failures** — Agents stepping on each other's work, conflicting
  changes to shared files, merge conflicts that required manual resolution, or agents
  blocked waiting on each other in cycles
- **Scope creep** — Tasks or features being implemented that are not in `SPEC.md` or
  domain specs. Work that goes beyond acceptance criteria without explicit approval.
- **Quality concerns** — Patterns of test failures, repeated CI breakages, declining
  code coverage, recurring lint violations, or agents committing without tests
- **Velocity trends** — Is the team accelerating, decelerating, or steady? Are
  estimates calibrated? Are later tasks taking longer due to accumulated complexity?

### Step 3: Cross-Agent Alignment

Check for alignment across all agents involved in the build:

- **Interface contracts honored** — Are agents producing outputs that match the
  contracts defined in domain specs? Are API shapes, data formats, and type
  definitions consistent across boundaries?
- **Naming conventions consistent** — Variable names, file names, endpoint paths,
  error codes — are agents following the conventions in `CLAUDE.md`?
- **Duplicate efforts** — Are two agents building the same utility, validation logic,
  or abstraction independently? Flag overlaps for consolidation.
- **CLAUDE.md updates** — Has `CLAUDE.md` been updated with learnings from the build?
  Are new commands, patterns, or conventions documented?

### Step 4: Recommend Actions

Based on findings from Steps 2 and 3, produce prioritized recommendations:

- **Re-prioritize tasks** — If velocity data shows the current ordering is suboptimal
- **Reassign work** — If an agent is blocked or overloaded while another has capacity
- **Update spec** — If scope creep indicates requirements have evolved and the spec
  should be revised to match reality
- **Schedule focused fixes** — For systemic issues (e.g., "all agents need to rebase
  on main before continuing" or "shared types need to be extracted to a common module")
- **Process adjustments** — Communication patterns, commit frequency, PR size, or
  coordination protocols that should change

Each recommendation must be concrete and actionable — not "improve communication" but
"Backend and Frontend agents should align on the `/api/users` response shape before
either proceeds with dependent tasks."

### Step 5: Output

Write `RETRO-{date}.md` using the output template below. Present findings to the user
for discussion before finalizing. The user may disagree with assessments, add context
the retro missed, or re-prioritize recommendations.

## State Tracking

Every skill must update `.factory/state.json` on invocation and completion, even when
invoked standalone. `/retro` follows this protocol:

**On start** — Set the `retro` phase to `in_progress`:

```json
{
  "retro": {
    "status": "in_progress",
    "started_at": "2026-04-03T15:00:00Z"
  }
}
```

**On completion** — Set to `completed` with outputs:

```json
{
  "retro": {
    "status": "completed",
    "started_at": "2026-04-03T15:00:00Z",
    "completed_at": "2026-04-03T15:30:00Z",
    "outputs": ["RETRO-2026-04-03.md"]
  }
}
```

**On failure** — Set to `failed` with reason:

```json
{
  "retro": {
    "status": "failed",
    "started_at": "2026-04-03T15:00:00Z",
    "failed_at": "2026-04-03T15:10:00Z",
    "failure_reason": "No completed phases found — nothing to retrospect"
  }
}
```

If `.factory/state.json` does not exist, create it with the standard structure before
recording the retro phase entry. Standalone invocations still update state — they add
or update the `retro` phase entry without modifying other phase entries.

## Output Template

```markdown
# Team Retro — [Date]

## Summary

- **Phases completed**: [list]
- **Active agents**: [list with prefixes]
- **Overall health**: HEALTHY / CONCERNS / AT RISK

## Progress Since Last Retro

| Agent | Tasks Completed | Tasks In Progress | Tasks Blocked |
|-------|----------------|-------------------|---------------|
| ARC   |                |                   |               |
| BE    |                |                   |               |
| FE    |                |                   |               |
| OPS   |                |                   |               |

## Issues Surfaced

### Blockers

[Active blockers preventing progress, with affected agents and tasks]

### Coordination Issues

[Conflicts, duplicate work, communication gaps]

### Quality Concerns

[Test failures, coverage gaps, CI instability, pattern violations]

### Scope Drift

[Work happening outside the spec, with assessment of whether the spec
should be updated or the work should be reverted]

## Velocity

- **Tasks completed this period**: N
- **Tasks remaining**: N
- **Trend**: Accelerating / Steady / Decelerating
- **Calibration**: [Are estimates matching actuals?]

## Cross-Agent Alignment

| Check | Status | Notes |
|-------|--------|-------|
| Interface contracts | OK / DRIFT | |
| Naming conventions  | OK / DRIFT | |
| Duplicate efforts   | NONE / FOUND | |
| CLAUDE.md updated   | YES / NO | |

## Recommendations

[Prioritized, concrete, actionable items — numbered list]

1. [Highest priority action]
2. [Next priority action]
3. ...

## Next Retro

- **When**: [Suggested timing — after next milestone, after N tasks, or on-demand]
- **Focus**: [What to pay attention to next time based on current findings]
```

## Anti-Patterns

- **Don't turn retro into code review.** `/retro` examines process, coordination, and
  progress. Code quality is `/qa`'s job. If `/retro` finds quality concerns, it flags
  them as process issues (e.g., "agents are not running tests before committing"), not
  as code-level findings.

- **Don't fabricate status.** If progress files are missing or incomplete, say so. Do
  not infer task completion from git history alone — that produces unreliable data.
  Flag the gap and recommend that agents update their progress files.

- **Don't produce a retro with zero findings.** Every project has friction. If the
  retro surfaces nothing, the analysis was not thorough enough. At minimum, note what
  is going well and what could be better, even if there are no critical issues.

- **Don't skip the discussion.** The retro is conversational. Presenting a report and
  immediately moving on defeats the purpose. Invite the user to react, add context,
  and adjust recommendations before finalizing.

- **Don't block on missing inputs.** `/retro` should work with whatever is available.
  A retro with partial data and noted gaps is more valuable than no retro at all.
