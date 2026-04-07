# /genesis claim -- Codebase Onboarding for Existing Projects

`/genesis claim` is a mode of the `/genesis` orchestrator skill (not a separate skill)
that deeply reads an existing codebase, infers which Factory pipeline phases have already
been completed, writes `.factory/state.json` with confidence-tagged phase statuses, and
proposes a `CLAUDE.md` tailored to the project. It is the on-ramp for bringing an existing
project into the Factory pipeline.

## Contract

| Field | Value |
|-------|-------|
| **Required inputs** | An existing codebase (at least one source file) |
| **Optional inputs** | Existing `CLAUDE.md`, `README.md`, `.env.example` |
| **Outputs** | `.factory/state.json`, proposed `CLAUDE.md` (user-confirmed) |
| **Failure output** | `.factory/state.json` with `claimed: false` and diagnostics |

The skill reads the codebase non-destructively. It never modifies existing files without
explicit user confirmation. The only file it writes unconditionally is
`.factory/state.json`.

## Category

Conversational mode of the `/genesis` orchestrator -- interactive, with a
read-analyze-propose-confirm loop. No sub-agents spawned. The orchestrator itself
executes claim logic inline.

## Process

### Step 1: Detect Claim Invocation

Activated on `/genesis claim` or phrasing like "claim this project" / "onboard this
codebase". If already claimed (`claimed: true` in state), warn before overwriting.

### Steps 2-3: Deep Read and Confidence Classification

The five-layer deep-read protocol and confidence classification rules are defined in
`skills/genesis/references/claim-layers.md`. That reference file is the implementation
and contains:

- **Layer 1** -- Package manifests (tech stack, dependencies, scripts)
- **Layer 2** -- CI/CD configuration (automation, deploy targets)
- **Layer 3** -- Deployment configuration (infrastructure, environments)
- **Layer 4** -- Test infrastructure (testing patterns, coverage)
- **Layer 5** -- Project structure and conventions

Confidence levels: **high** (multiple corroborating signals, stated as fact), **medium**
(single authoritative signal, stated with caveat), **low** (indirect/ambiguous, stated
as question to user).

Claim never executes code. It reads artifacts only.

### Step 4: State Backfill

Map detected artifacts to pipeline phases and write `.factory/state.json`.

| Phase | Completed | Partial |
|-------|-----------|---------|
| ideation | Not detectable. Always `pending`. | N/A |
| spec | `SPEC.md` exists | `README.md` with project description |
| prototype | `prototypes/` + `PROTOTYPE-DECISION.md` | `prototypes/` but no decision doc |
| setup | Package manifest + CI + deploy config | Manifest but no CI, or CI but no deploy |
| build | Source code + tests exist | Source code but no tests |
| retro | `RETRO-*.md` exists | N/A |
| qa | `QA-REPORT.md` with passing status | `QA-REPORT.md` with failed status |
| security | `SECURITY.md` with no critical findings | `SECURITY.md` with unresolved findings |
| deploy | `DEPLOY-RECEIPT.md` + app accessible | `DEPLOY-RECEIPT.md` but status unknown |

Rules: only mark `completed` with high confidence. Medium -> `partial`.
Low -> `pending`. Set `current_phase` to earliest `partial` phase, or earliest
`pending` phase following a `completed` phase.

### Step 5: Present Findings

Present findings grouped by category (tech stack, commands, infrastructure, pipeline
status, questions) with confidence-appropriate framing. Do not dump raw file contents.

### Step 6: CLAUDE.md Generation

Two parts, both detailed in `skills/genesis/references/claim-layers.md`:

- **Part A: Process Rules** -- Factory-owned process-rules sections, gated by the
  `update_project_claude_md` setting (`prompt`/`auto`/`skip`).
- **Part B: Claim-Specific Sections** -- Development commands, code conventions,
  deployment config, environment variables derived from codebase analysis.

If `CLAUDE.md` already exists, propose changes (ADD/UPDATE/KEEP AS-IS) and confirm
with the user before writing.

### Step 7: Feedback Loop

Iterate with user feedback until they confirm the proposed `CLAUDE.md`. After 3+
rounds, ask whether to take a different approach.

### Step 8: Write and Handoff

1. Write `CLAUDE.md` if confirmed.
2. Update `.factory/state.json` with `claimed: true`, `claimed_at`, and
   `claim_confidence` summary (`{"high": N, "medium": N, "low": N}`).
3. Present pipeline status and recommended next step.

## State Tracking Protocol

- **On entry**: Set `claimed: false` and `claim_started_at`.
- **During execution**: Update phase statuses as findings are classified.
- **On completion**: Set `claimed: true` and `claimed_at`.
- **On failure**: Set `claimed: false` with `claim_error` field.

Claim only sets `completed`, `partial`, or `pending` -- never `in_progress`.

## Anti-Patterns

- **Running test suites during claim.** Reads artifacts only. Test verification is
  `/qa`'s job.
- **Overwriting CLAUDE.md without confirmation.** Always present and get explicit
  approval first.
- **Marking phases `completed` without high confidence.** Medium -> `partial`,
  low -> `pending`.
- **Inventing commands.** If not found in manifest or CI config, ask the user or omit.
- **Reading every file in the repo.** Use the five-layer targeted read protocol.
- **Backfilling spec artifacts.** Claim only detects whether artifacts exist; it does
  not generate `SPEC.md`, `IDEATION.md`, etc.
- **Treating `partial` as `completed`.** Surface gaps and let the user decide.
