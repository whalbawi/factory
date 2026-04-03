# /spec — Product Discovery, Specification & Agent Team Orchestration

`/spec` turns a user's idea into a detailed, buildable specification. It handles
single-domain projects end-to-end as a conversational skill, and multi-domain projects
by decomposing into bounded domains and farming out specs to a fixed team of specialist
agents orchestrated by a Software Architect. The output is dense enough for Claude to
autonomously build, test, and ship the product.

## Contract

| Field | Value |
|-------|-------|
| **Required inputs** | None (discovery phase gathers requirements from the user) |
| **Optional inputs** | Existing codebase, `IDEATION.md` (from `/ideation` phase) |
| **Outputs** | `SPEC.md`, `specs/SPEC-{domain}.md` (per domain, multi-domain only), `CLAUDE.md` |
| **Failure** | Partial `SPEC.md` with incomplete sections noted |

When optional inputs are present, the skill uses them to ground specification in the
current product reality. If an `IDEATION.md` exists, `/spec` inherits the selected ideas,
context, and parked alternatives rather than re-discovering from scratch.

## Category

**Agentic skill** (multi-domain) / **Conversational skill** (single-domain).

For single-domain projects, the skill runs as a conversation between top-level Claude and
the user through all three phases. For multi-domain projects, top-level Claude handles
Discovery (Phase 1) and Validation (Phase 3), then spawns a Software Architect agent who
orchestrates seven specialist agents to produce domain-level specs in parallel. The
Architect and specialists run autonomously — no user interaction until results are
presented in Phase 3.

## Process

### Phase 1: Discovery

Adaptive conversation to understand the product vision. Top-level Claude acts as a
critical thinking partner: it pressure-tests ideas, flags contradictions, refuses to move
forward on vague foundations, and pushes back when answers don't hold up.

Key behaviors:

- **Calibrate depth** based on the user's starting point: full discovery (vague idea,
  5-10 rounds), focused discovery (partial concept, 3-6 rounds), or fast-path (detailed
  vision, 1-3 rounds).
- **Explore dimensions adaptively**: problem & purpose, users & context, core
  functionality, platform & stack, data & state, integrations, hard constraints,
  complexity assessment. Not sequential — probe the dimension with the most uncertainty
  after each user response.
- **Use concrete techniques**: scenarios over abstractions, propose-and-react, periodic
  playback, challenge feasibility, expose hidden complexity, cut scope proactively.
- **Stop on red flags**: unarticulable problem, contradictory features, vague success
  criteria, scope creep, tech stack chosen before problem is understood.

Exit criteria: all core functionality understood with concrete input/output examples,
scope boundaries explicit and confirmed, hard constraints identified with specific
numbers, contradictions resolved (not deferred), product vision internally coherent.

### Phase 2: Architect Orchestration

Top-level Claude launches the Architect agent with all discovery context. The Architect
runs five sub-phases autonomously:

- **2a. Synthesis** — Architect writes the structured master spec (`SPEC.md`) covering
  overview, scope (in/out), scenarios, data model, external interfaces, constraints,
  UI/UX overview, decision log, and open questions.
- **2b. Decomposition** — Architect identifies 2-5 bounded domains, defines interface
  contracts between them (mechanism, request/response shapes, error cases), establishes
  shared definitions, determines build order, and assigns specialist agents per domain.
  Skipped for trivially simple projects.
- **2c. Agent Spec Generation** — Architect fans out specialist agents in batches
  following the build order. All agents within a batch run in parallel. Each agent writes
  its section of `specs/SPEC-{domain}.md`. Agents in later batches receive specs from
  earlier batches as context.
- **2d. Peer Review & Revision** — All agents read each other's specs (own domain +
  adjacent domains sharing interface contracts), identify contradictions and gaps, and
  update their sections in place. All review-revise agents run in parallel.
- **2e. Final Review & CLAUDE.md** — Architect reviews all domain specs, resolves
  disputes (Architect is tiebreaker), checks cross-domain consistency, appends an
  Architect Review section to `SPEC.md`, and generates `CLAUDE.md` to the project root.

### Phase 3: Validation

Top-level Claude presents results to the user for confirmation:

- **Single-domain**: priority check, assumption review (Decision Log), open question
  resolution, feasibility confirmation, final approval.
- **Multi-domain**: all of the above, plus domain boundary review, contract review, agent
  output review (highlighting peer review and Architect corrections), Architect review
  summary, and full integration review.

Iterate until confirmed. Update spec files in place with each revision. Re-launch
affected agents if master spec changes affect domain assignments or contracts.

## Agent Team

Every project gets the same team roster. The Architect decides which agents are active
per domain based on relevance.

| Role | Responsibility |
|------|----------------|
| **Software Architect** (orchestrator) | Master spec, domain decomposition, agent assignment, peer review orchestration, final review, dispute resolution, `CLAUDE.md` generation |
| **Backend** | Internal architecture, data models, API implementation, business logic, performance-critical paths |
| **Frontend** | Component hierarchy, state management, routing, UI behavior, accessibility |
| **DevOps** | Build pipeline, CI/CD, containerization, deployment strategy, infrastructure, monitoring |
| **Security** | Threat model, auth/authz design, input validation, secrets management, compliance |
| **QA** | Test strategy, test plan, acceptance criteria, edge cases, integration test boundaries |
| **Product Design** | Information architecture, user flows, interaction patterns, wireframe descriptions, design system |
| **Tech Writing** | API docs, user-facing docs, onboarding guides, CLI help text, changelog strategy, README |

Agent assignment follows heuristics by domain type (e.g., API services always get
Backend + Security + QA; frontend domains always get Frontend + Product Design + QA).
The Architect documents the full assignment matrix and execution plan in the master spec.

## State Tracking

Every invocation of `/spec` must update `.factory/state.json`, whether the skill is
invoked standalone or via the `/genesis` orchestrator. This ensures pipeline state
remains consistent and resumable.

### On Start

When `/spec` begins, update (or create) `.factory/state.json`:

```json
{
  "phases": {
    "spec": {
      "status": "in_progress",
      "started_at": "2026-04-03T10:00:00Z"
    }
  }
}
```

If the state file does not exist, create it with the `spec` phase entry. If it exists,
merge — do not overwrite other phases.

### On Completion

When `/spec` finishes successfully:

```json
{
  "phases": {
    "spec": {
      "status": "completed",
      "started_at": "2026-04-03T10:00:00Z",
      "completed_at": "2026-04-03T11:30:00Z",
      "outputs": ["SPEC.md", "specs/SPEC-{domain}.md", "CLAUDE.md"]
    }
  }
}
```

### On Failure

If `/spec` cannot complete:

```json
{
  "phases": {
    "spec": {
      "status": "failed",
      "started_at": "2026-04-03T10:00:00Z",
      "failed_at": "2026-04-03T11:00:00Z",
      "failure_reason": "User ended session before validation"
    }
  }
}
```

On failure, write a partial `SPEC.md` with whatever was produced so far, noting
incomplete sections explicitly so downstream skills know the output is not finalized.

### State File Creation

If no `.factory/state.json` exists when `/spec` is invoked:

1. Create the `.factory/` directory if it does not exist.
2. Initialize `state.json` with the spec phase entry.
3. Proceed normally.

This is critical for standalone invocations where the orchestrator has not already
created the state file.

## Pipeline Position

Second in the v1 pipeline:

```text
/ideation -> /spec -> /prototype -> ...
```

`/spec` can be invoked standalone (without a prior `/ideation` phase). When invoked
standalone, Discovery (Phase 1) covers the full problem space. When `IDEATION.md` exists
from a prior `/ideation` run, Discovery is shorter — the skill inherits context and
selected ideas, focusing on clarification and gap-filling rather than open exploration.

### External Skill

`/spec` is an external skill. It lives at `~/.claude/skills/spec/SKILL.md`, not in the
Factory repo. Factory wraps it and invokes it within the pipeline context — it does not
fork or duplicate the skill definition. The SPEC file you are reading documents how the
skill fits into the Factory pipeline; the canonical skill behavior is defined in
`SKILL.md`.

## Output Files

| Project type | Files produced |
|---|---|
| Single-domain | `SPEC.md` + `CLAUDE.md` |
| Multi-domain | `SPEC.md` (master) + `specs/SPEC-{domain}.md` per domain + `CLAUDE.md` |

## Anti-Patterns

- **Skipping discovery**: Do not jump straight to spec writing. Even with an
  `IDEATION.md`, Discovery confirms assumptions, resolves ambiguity, and fills gaps that
  ideation deliberately left open.

- **Rubber-stamping user input**: The skill is a critical thinking partner, not a
  stenographer. Push back on vague requirements, contradictions, and unrealistic scope.

- **Decomposing prematurely**: A project that fits in one agent's head should stay as one
  spec. Do not force multi-domain decomposition on simple projects.

- **Hand-waving contracts**: `GET /api/tasks?status=active -> { tasks: Task[], cursor:
  string }` is a contract. "The frontend calls the API" is not. Interface contracts must
  have concrete shapes.

- **Assigning agents blindly**: A pure backend service does not need a Product Design
  agent. The Architect assigns agents where they add value, not everywhere.

- **Ignoring cross-domain consistency**: The Architect's final review exists to catch
  integration issues no single agent can see. Never skip it.

- **Skipping re-generation on spec changes**: When the master spec changes materially
  (new domain, changed contracts), re-launch affected agents. Stale domain specs are
  worse than no domain specs.

- **Forking the skill**: Factory wraps `/spec`, it does not fork it. If behavior changes
  are needed, they go into `~/.claude/skills/spec/SKILL.md`, not into Factory.

- **Ignoring existing code**: If the user has an existing codebase, the spec must
  reference it. Do not spec in a vacuum when prior work exists.
