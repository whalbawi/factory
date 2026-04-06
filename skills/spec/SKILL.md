---
name: spec
description: Use when the user asks to "spec out a project", "write a spec", "clarify requirements", "I have an idea", "what should I build", "help me plan", or when the user has a vague-to-detailed idea and needs it turned into a concrete, buildable specification. Also trigger when the user seems uncertain about what they want or needs help articulating product requirements. Handles single-domain projects end-to-end, and multi-domain projects by decomposing into domains and farming out specs to a fixed team of specialized agents (Backend, Frontend, DevOps, Security, QA, Product Design, Tech Writing) orchestrated by a Software Architect.
---

# Spec: Product Discovery, Specification & Agent Team Orchestration

Turn a user's idea into a spec dense enough for Claude to autonomously build,
test, and ship the product. Complex products are decomposed into bounded
domains, then a fixed team of specialist agents — orchestrated by a Software
Architect — produces detailed specs across every domain in parallel.

## Agent Team

Every project gets the same team. The Architect decides which agents are
active per domain based on relevance.

### Top-Level Claude (User-Facing)

The top-level Claude runs in the main conversation with the user. It handles
Discovery (Phase 1) and Validation (Phase 3). After discovery is complete, it
launches the Architect agent with the collected context and waits for it to
finish before presenting results to the user.

### Software Architect (Orchestrator Agent)

A separate agent launched via the Agent tool. The Architect receives the
discovery context from top-level Claude and handles everything else: writes
the master spec (Phase 2), decomposes domains, assigns agents, launches
specialist agents in batches, runs peer review, performs the final review
pass, generates `CLAUDE.md`, and writes the architect review. The Architect
has full authority to edit any spec file and is the tiebreaker when agents
disagree.

### Specialist Agents

These agents are launched by the Architect via the Agent tool as parallel
subagents. Each operates within a scoped context: one domain + one specialty.
Multiple agents can run in parallel across domains and within the same domain.

| Agent | Responsibility |
|---|---|
| **Backend** | Internal architecture, data models, API implementation, business logic, service internals, performance-critical paths |
| **Frontend** | Component hierarchy, state management, routing, UI behavior, client-side data flow, accessibility |
| **DevOps** | Build pipeline, CI/CD, containerization, deployment strategy, infrastructure-as-code, monitoring, environments |
| **Security** | Threat model, auth/authz design, input validation, secrets management, dependency auditing, compliance mapping |
| **QA** | Test strategy, test plan, acceptance criteria, edge case inventory, integration test boundaries, regression scope |
| **Product Design** | Information architecture, user flows, interaction patterns, wireframe descriptions, design system constraints, copy guidelines |
| **Tech Writing** | API documentation plan, user-facing docs structure, onboarding guides, CLI help text, changelog strategy, README spec |

### Agent Assignment Rules

Not every agent is needed for every domain. The Architect assigns agents per
domain using these heuristics:

| Domain type | Always assign | Assign if relevant | Rarely needed |
|---|---|---|---|
| API / backend service | Backend, Security, QA | DevOps, Tech Writing | Frontend, Product Design |
| Frontend / UI | Frontend, Product Design, QA | Security | Backend, DevOps, Tech Writing |
| Data pipeline | Backend, QA | Security, DevOps | Frontend, Product Design, Tech Writing |
| CLI tool | Backend, QA, Tech Writing | Security | Frontend, DevOps, Product Design |
| Library / SDK | Backend, QA, Tech Writing | Security | Frontend, DevOps, Product Design |
| Infrastructure | DevOps, Security | QA | Backend, Frontend, Product Design, Tech Writing |
| Full-stack (entire system) | All | — | — |

The Architect documents agent assignments in the master spec's Domain
Decomposition section.

---

## Process Overview

1. **Discovery** — Top-level Claude understands the user's vision through
   adaptive conversation
2. **Architect Orchestration** — Top-level Claude launches the Architect
   agent, which runs Phases 2a–2e:
   - 2a. **Synthesis** — Architect produces the structured master spec
   - 2b. **Decomposition** — Architect identifies domains, defines contracts,
     assigns agents *(skip for trivially simple projects)*
   - 2c. **Agent Spec Generation** — Architect fans out specialist agents
     (parallel within and across domains)
   - 2d. **Peer Review & Revision** — Agents read each other's specs,
     critique, and update their own (all in parallel)
   - 2e. **Architect Final Review & CLAUDE.md** — Architect reads everything,
     resolves disputes, generates `CLAUDE.md`
3. **Validation** — Top-level Claude presents results to user for
   confirmation

---

## Phase 1: Discovery

The goal of Discovery is to produce a **coherent, internally consistent
product vision** — not to transcribe whatever the user says. Top-level Claude
acts as a critical thinking partner: it pressure-tests ideas, flags
contradictions, refuses to move forward on vague foundations, and pushes back
when answers don't hold up. A spec built on hand-wavy inputs produces
hand-wavy output. Discovery is where rigor starts.

### Skill Parameters

Read and execute ALL [MANDATORY] sections in [GLOBAL-REFERENCE.md](GLOBAL-REFERENCE.md):

- `{PHASE_NAME}` = `spec`
- `{OUTPUT_FILES}` = `["SPEC.md", "CLAUDE.md", "design-tokens.json"]`

- **You are not a stenographer.** Understand the product well enough to build
  it. If something doesn't make sense, say so.
- **Push back.** Reject vague answers ("it should be fast", "standard auth").
  Ask what "fast" means in numbers. Vague inputs produce vague specs.
- **Name contradictions immediately.** "Simple MVP" + 15 features = conflict.
  Surface tensions. Do not silently collect conflicting requirements.
- **Say no.** Unrealistic scope, wrong tech choice, wrong problem — say so
  with reasoning. Propose alternatives. Agreeable is not helpful.
- **Demand specifics.** "What happens when X fails?" and "Walk me through
  exactly what the user sees" are always valid. Abstractions are not
  requirements.
- **Hold the line on coherence.** Every answer must fit with every other
  answer. Resolve contradictions before continuing — do not accumulate them.

### Calibrate Depth

Assess the user's starting point from their first message and pick a track:

| Signal | Track | Typical rounds |
|---|---|---|
| Vague idea ("something for tracking habits") | **Full discovery** — explore problem space broadly | 5–10 |
| Partial concept ("CLI tool that syncs dotfiles across machines") | **Focused discovery** — clarify core, probe edges | 3–6 |
| Detailed vision ("React dashboard with auth, these 5 endpoints...") | **Fast-path** — challenge assumptions, fill gaps, confirm | 1–3 |

Even on the fast-path, do not rubber-stamp. Probe for contradictions,
missing error handling, and unstated assumptions.

### Discovery Areas

These are **dimensions of understanding**, not sequential steps. After each
user response, reassess which dimension has the most uncertainty and probe
there next. Ask **1--3 questions per message**. Skip areas already addressed.

- **Problem & Purpose**: What problem? Current workaround? Observable success
  criteria? Why does this need to exist vs. existing tools?
- **Users & Context**: Who uses it? Technical level? Existing codebase? Scale
  (1, 10, 1000, 1M users -- changes everything)?
- **Core Functionality**: 3--5 most important actions, each with trigger →
  input → expected output. What's explicitly out of scope? What's the single
  most important feature?
- **Platform & Stack**: Form factor (CLI, web, API, library, etc.). Tech
  stack preferences and *why*. OS/environment constraints.
- **Data & State**: What's stored, where, who owns it? Privacy/compliance?
  Source of truth and consistency model?
- **Integrations**: External services, APIs, auth. Failure modes for every
  dependency (not optional).
- **Hard Constraints**: Performance targets in numbers. Budget, timeline,
  licensing, regulatory mandates. Non-negotiable technical requirements.
- **Visual Identity** *(mandatory for UI projects)*: Ask explicitly -- users
  rarely volunteer this. Reference sites ("clean like Linear", "bold like
  Stripe"). Theme, density, brand constraints. The Product Design agent
  translates into `design-tokens.json`. Confirm with user before proceeding.
- **Complexity Assessment**: How many distinct technical concerns? Natural
  ownership boundaries? Which specialist agents needed where?

### Techniques

- **Concrete over abstract.** Ask for specific scenarios, not abstractions.
  If the user can't walk through a scenario, the feature isn't ready to spec.
- **Propose and react.** Offer concrete options when the user is stuck. Be
  honest about tradeoffs.
- **Playback.** Every 3--4 exchanges, summarize in 2--3 sentences. Confirm
  or correct.
- **Challenge feasibility.** Surface impractical requirements immediately
  with specific reasons. Propose alternatives.
- **Expose hidden complexity.** Probe auth, error handling, multi-tenancy,
  offline/sync, migrations, admin features even if not mentioned.
- **Cut scope proactively.** If scope exceeds a realistic v1, say so and
  propose what to cut.

### Red Flags — Stop and Resolve

Do not proceed past Discovery if any of these are present:

| Red flag | What to do |
|---|---|
| User can't articulate what problem this solves | Stop. Explore the problem space before discussing solutions. |
| Features contradict each other | Name both sides of the contradiction. Force a choice. |
| "It should just work like [popular product]" with no specifics | That product has 500 features. Which 5 matter? Why? |
| Scope keeps growing with each answer | Pause. Restate the core. Ask what's v1 vs. later. |
| Vague success criteria ("users love it") | Demand observable outcomes. What can you *test*? |
| Tech stack chosen before problem is understood | Challenge it. "Why X and not Y? What does X give you here?" |
| No error/failure modes discussed for any feature | Probe: "What happens when this fails? When the user enters bad input? When the API is down?" |

### Exit Criteria

Move to the Architect only when:

- All core functionality is understood with **concrete input/output
  examples** — not descriptions, actual examples
- Scope boundaries (in/out) are explicit and the user has confirmed them
- Hard constraints are identified with specific numbers where applicable
- Contradictions are resolved — not deferred, resolved
- The product vision is coherent: every piece fits with every other piece
- Remaining unknowns are implementation decisions the Architect can make
  autonomously, not product decisions

Announce: "I have a clear picture. Handing off to the Architect to produce
the spec."

---

## Phase 2: Architect Orchestration

After Discovery, the top-level Claude launches the Architect agent with a
single Agent tool call:

- **Name**: `architect`
- **Mode**: `auto`
- **Prompt**: Include all discovery context collected from the user (problem,
  users, core functionality, platform, data, integrations, constraints,
  complexity assessment). Instruct the Architect to execute Phases 2a–2e and
  return a summary of what was produced, any unresolved issues, and open
  questions for the user.

The Architect runs autonomously. Top-level Claude waits for it to return
before proceeding to Phase 3 (Validation).

---

### Phase 2a: Synthesis — Master Spec

Write the spec to `SPEC.md` in the working directory.

Adapt to the product. Omit inapplicable sections, add ones the product demands.

STOP. Read `references/spec-template.md` now. It contains the master spec,
domain decomposition, and agent assignment matrix templates.

### Writing Principles

- **Dense, not verbose.** Every sentence should carry information. No filler.
- **Concrete over general.** "Accepts `--format json|csv|table`, defaults to
  `table`" beats "supports multiple output formats."
- **Priority is load-bearing.** The ordered in-scope list tells agents what
  to protect and what to sacrifice under pressure.
- **Distinguish requirement strength.** "must" (hard), "should" (strong
  preference), "could" (nice-to-have).
- **Examples are requirements.** A sample input/output pair is a concrete,
  testable contract.
- **Reference existing context.** If there's an existing repo or system,
  reference it by name/path.

---

### Phase 2b: Decomposition & Agent Assignment

### Identifying Domains

A domain is a bounded area of concern that:

- Can be built and tested semi-independently
- Has a well-defined interface surface to other domains
- Maps to a coherent technical concern

Common decompositions:

| Project type | Typical domains |
|---|---|
| Full-stack web app | `frontend`, `api`, `storage`, `auth` |
| Data platform | `ingestion`, `processing`, `storage`, `api`, `frontend` |
| CLI with backend | `cli`, `core-lib`, `api-client` |
| ML-powered product | `ml-pipeline`, `serving`, `api`, `frontend` |

Aim for 2–5 domains.

### Interface Contracts

For every domain boundary, define contracts using the domain decomposition
template in `references/spec-template.md`. Each contract specifies: the
mechanism, endpoint or function signature, request/response shapes with
examples, error cases, and the owning domain.

### Agent Assignment Matrix

The Architect produces an explicit assignment table using the template in
`references/spec-template.md`, showing which agents are assigned to each
domain plus an execution plan that respects domain dependency order
(topological sort) and maximizes parallelism within each batch.

### Sprint Plan

After producing the execution plan, the Architect sizes the work into
ordered sprints. Sprints give incremental validation with bounded blast
radius -- QA and security run as checkpoints between sprints so issues
are caught early.

1. **Count total tasks** in the task DAG (each task maps to a single PR
   in `/build`).
2. **Apply the sizing heuristic**:
   - 1-8 tasks: 1 sprint (no checkpoints, identical to current behavior)
   - 9-16 tasks: 2 sprints (split at the natural dependency boundary
     closest to the midpoint)
   - 17-30 tasks: 3-4 sprints (split by priority tiers from the spec's
     ordered in-scope list)
   - 31+ tasks: 4-6 sprints (split by priority tiers, respecting the
     size bound)
3. **Assign tasks to sprints** respecting three criteria in order:
   - **Dependency closure**: every task's dependencies are in the same
     or an earlier sprint. No forward references.
   - **Priority cohesion**: higher-priority items land in earlier
     sprints. Sprint 1 contains the highest-priority work.
   - **Size bound**: target 3-8 tasks per sprint, with flexibility for
     dependency constraints.
4. For each sprint, list the tasks, their parallel batches, a one-
   sentence goal, and a **checkpoint criteria** statement -- a concrete,
   testable description of what the sprint delivers.

If the project has 8 or fewer tasks, assign all tasks to Sprint 1
(single sprint). This preserves current behavior -- no checkpoints, no
overhead, and the `## Sprint Plan` section may be omitted entirely.

---

### Phase 2c: Agent Spec Generation

The Architect launches specialist agents using the Agent tool, following the
execution plan's batch order. All agents within a batch run in parallel. Each
agent writes its section of `specs/SPEC-{domain}.md` directly.

Each agent receives: the master spec, its domain context (ownership,
contracts, shared definitions), and its role-specific instructions. Agents in
later batches also receive the domain specs produced by earlier batches.

For each agent, read the base prompt template and role-specific instructions
from `references/agent-prompts.md` and include them in the agent's prompt.

---

### Phase 2d: Peer Review & Revision

After all batches complete, agents read each other's specs and revise their
own. Each agent reviews specs from its own domain and adjacent domains
sharing interface contracts. All review-revise agents run in parallel.

Each agent:

1. Identifies contradictions, gaps, interface mismatches, and
   self-corrections
2. Updates its section of `specs/SPEC-{domain}.md` in place
3. Returns a summary of what it changed and what issues remain in other
   agents' specs

---

### Phase 2e: Architect Final Review & CLAUDE.md

The Architect reviews all domain specs and the review summaries. It checks
for:

- Unresolved contradictions between agents
- Contract consistency across domain boundaries
- Completeness of coverage for all assigned roles
- Alignment with the master spec
- Cross-cutting consistency (auth flows, error formats, naming conventions)

The Architect edits any `specs/SPEC-{domain}.md` that needs fixing — it is
the tiebreaker when agents disagree. Then it:

- Appends an `## Architect Review` section to `SPEC.md` (issues found,
  resolutions, open questions)
- Writes `CLAUDE.md` to the project root

### Output Structure

```text
project/
├── CLAUDE.md
├── SPEC.md
└── specs/
    ├── SPEC-storage.md
    ├── SPEC-auth.md
    ├── SPEC-api.md
    └── SPEC-frontend.md
```

The Architect also initializes `.factory/state.json` with the spec phase
marked as `completed` and all output files listed.

### CLAUDE.md Generation

After the final review, the Architect writes the project-specific sections of
`CLAUDE.md`. The Architect derives these from the master spec and domain specs.

The `/genesis` orchestrator owns the process-rules sections (Mandatory Process
Rules, Agent Communication, etc.) and writes them with
`<!-- factory:process-rules:start/end -->` markers. The `/spec` skill owns the
project-specific sections and writes them with
`<!-- spec:project:start/end -->` markers.

STOP. Read `references/claude-template.md` now. Follow its steps before
proceeding. It contains the normal flow vs. standalone fallback logic, the
spec-owned sections template, the standalone fallback process-rules
template, and the generation rules.

---

## Phase 3: Validation

### For Single-Domain Projects

Present the spec and direct attention to:

1. **Priority check**: "Here's the priority order. Does this ranking match?"
2. **Assumption review**: Reference the Decision Log.
3. **Open questions**: Resolve items marked "requires user input."
4. **Feasibility confirmation**: If scope was adjusted, confirm the tradeoff.
5. **Final ask**: "Does this capture what you want to build?"

### For Multi-Domain Projects

All of the above, plus:

6. **Domain boundary review**: "Here's how I split the system. Do these
   ownership lines make sense?"
7. **Contract review**: "These are the interfaces between domains. Shapes
   correct? Anything missing?"
8. **Agent output review**: Present each domain's spec suite. Highlight what
   changed during peer review and what the Architect corrected.
9. **Architect review summary**: Walk through the Architect Review section of
   `SPEC.md` — what was caught, what was fixed, what needs user input.
10. **Final integration review**: "Here's how the pieces fit together. Does
    the full picture match your vision?"

Iterate until confirmed. Update spec files in place with each revision.
Re-launch affected agents if master spec changes affect domain assignments
or contracts.

---

## Output Files

| Project type | Files produced |
|---|---|
| Single-domain | `SPEC.md` + `CLAUDE.md` |
| Multi-domain | `CLAUDE.md` + `SPEC.md` (master) + `specs/SPEC-{domain}.md` per domain (consolidated agent specs) |

---

## Settings

```yaml
settings:
  - name: discovery_track
    type: enum
    values: ["auto", "full", "focused", "fast"]
    default: "auto"
    description: >
      Controls discovery depth. "auto" lets the skill calibrate based
      on the user's first message. "full", "focused", and "fast" force
      a specific track regardless of input signal.
  - name: peer_review_enabled
    type: boolean
    default: true
    description: >
      Enable the peer review pass (Phase 2d) where specialist agents
      read and critique each other's specs. Disabling saves time but
      reduces cross-domain consistency.
```

## Anti-Patterns

- **Don't interrogate.** If the user clearly knows what they want, accept it
  and move on.
- **Don't front-load.** Never dump all questions in one message. This is a
  conversation.
- **Don't cargo-cult.** No "As a user, I want X so that Y" unless requested.
  Concrete scenarios are more useful.
- **Don't defer everything.** When either choice is fine, pick one and
  document it in the Decision Log.
- **Don't spec implementation in the master spec.** The master spec captures
  *what* and *why*. Agent specs go deeper into *how* within their scoped
  (domain, role) cell.
- **Don't ignore the repo.** If the user has existing code, the spec should
  reference it.
- **Don't decompose prematurely.** A project that fits in one agent's head
  should stay as one spec.
- **Don't hand-wave contracts.**
  `GET /api/tasks?status=active → { tasks: Task[], cursor: string }` is a
  contract. "The frontend calls the API" is not.
- **Don't assign agents blindly.** A pure backend service doesn't need a
  Product Design agent. The Architect's job is to assign agents where they
  add value, not to run every agent everywhere.
- **Don't ignore cross-domain consistency.** The whole point of the Architect
  role is to catch integration issues that no single agent can see. Always
  run the consistency check.
- **Don't skip re-generation.** When the master spec changes materially (new
  domain, changed contracts), re-launch affected agents. Stale domain specs
  are worse than no domain specs.
- **Don't speculate on external schemas.** When the spec references an
  external system's format (plugin manifests, API schemas, config file
  formats), verify the actual schema before writing the spec. Read
  documentation, check examples, or test the system. A spec built on a
  guessed schema will need correction during build — wasting a round trip.
