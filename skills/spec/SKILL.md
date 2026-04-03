---
name: spec
description: Use when the user asks to "spec out a project", "write a spec", "clarify requirements", "I have an idea", "what should I build", "help me plan", or when the user has a vague-to-detailed idea and needs it turned into a concrete, buildable specification. Also trigger when the user seems uncertain about what they want or needs help articulating product requirements. Handles single-domain projects end-to-end, and multi-domain projects by decomposing into domains and farming out specs to a fixed team of specialized agents (Backend, Frontend, DevOps, Security, QA, Product Design, Tech Writing) orchestrated by a Software Architect.
---

# Spec: Product Discovery, Specification & Agent Team Orchestration

Turn a user's idea into a spec dense enough for Claude to autonomously build, test, and ship the product. Complex products are decomposed into bounded domains, then a fixed team of specialist agents — orchestrated by a Software Architect — produces detailed specs across every domain in parallel.

## Agent Team

Every project gets the same team. The Architect decides which agents are active per domain based on relevance.

### Top-Level Claude (User-Facing)

The top-level Claude runs in the main conversation with the user. It handles Discovery (Phase 1) and Validation (Phase 3). After discovery is complete, it launches the Architect agent with the collected context and waits for it to finish before presenting results to the user.

### Software Architect (Orchestrator Agent)

A separate agent launched via the Agent tool. The Architect receives the discovery context from top-level Claude and handles everything else: writes the master spec (Phase 2), decomposes domains, assigns agents, launches specialist agents in batches, runs peer review, performs the final review pass, generates `CLAUDE.md`, and writes the architect review. The Architect has full authority to edit any spec file and is the tiebreaker when agents disagree.

### Specialist Agents

These agents are launched by the Architect via the Agent tool as parallel subagents. Each operates within a scoped context: one domain + one specialty. Multiple agents can run in parallel across domains and within the same domain.

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

Not every agent is needed for every domain. The Architect assigns agents per domain using these heuristics:

| Domain type | Always assign | Assign if relevant | Rarely needed |
|---|---|---|---|
| API / backend service | Backend, Security, QA | DevOps, Tech Writing | Frontend, Product Design |
| Frontend / UI | Frontend, Product Design, QA | Security | Backend, DevOps, Tech Writing |
| Data pipeline | Backend, QA | Security, DevOps | Frontend, Product Design, Tech Writing |
| CLI tool | Backend, QA, Tech Writing | Security | Frontend, DevOps, Product Design |
| Library / SDK | Backend, QA, Tech Writing | Security | Frontend, DevOps, Product Design |
| Infrastructure | DevOps, Security | QA | Backend, Frontend, Product Design, Tech Writing |
| Full-stack (entire system) | All | — | — |

The Architect documents agent assignments in the master spec's Domain Decomposition section.

---

## Process Overview

1. **Discovery** — Top-level Claude understands the user's vision through adaptive conversation
2. **Architect Orchestration** — Top-level Claude launches the Architect agent, which runs Phases 2a–2e:
   - 2a. **Synthesis** — Architect produces the structured master spec
   - 2b. **Decomposition** — Architect identifies domains, defines contracts, assigns agents *(skip for trivially simple projects)*
   - 2c. **Agent Spec Generation** — Architect fans out specialist agents (parallel within and across domains)
   - 2d. **Peer Review & Revision** — Agents read each other's specs, critique, and update their own (all in parallel)
   - 2e. **Architect Final Review & CLAUDE.md** — Architect reads everything, resolves disputes, generates `CLAUDE.md`
3. **Validation** — Top-level Claude presents results to user for confirmation

---

## Phase 1: Discovery

The goal of Discovery is to produce a **coherent, internally consistent product vision** — not to transcribe whatever the user says. Top-level Claude acts as a critical thinking partner: it pressure-tests ideas, flags contradictions, refuses to move forward on vague foundations, and pushes back when answers don't hold up. A spec built on hand-wavy inputs produces hand-wavy output. Discovery is where rigor starts.

### Mindset

- **You are not a stenographer.** Your job is to understand the product well enough to build it, not to record what the user said. If something doesn't make sense, say so.
- **Push back.** If the user gives a vague answer ("it should be fast", "standard auth", "nice UI"), do not accept it. Ask what "fast" means in numbers. Ask which auth flow. Ask what "nice" looks like concretely. Vague inputs produce vague specs.
- **Name contradictions immediately.** If the user says "simple MVP" but describes 15 features, call it out. If they want "real-time" but also "serverless with cold starts", surface the tension. Do not silently collect conflicting requirements.
- **Say no.** If scope is unrealistic, if the tech choice doesn't fit the problem, if the user is solving the wrong problem — say so directly with reasoning. Propose an alternative. Being agreeable is not being helpful.
- **Demand specifics.** "What happens when X fails?" is always a valid question. "Walk me through exactly what the user sees" is always a valid request. Abstractions are not requirements.
- **Hold the line on coherence.** Every answer must fit with every other answer. When a new piece of information contradicts an earlier one, stop and resolve it before continuing. Do not accumulate contradictions hoping they'll sort themselves out later.

### Calibrate Depth

Assess the user's starting point from their first message and pick a track:

| Signal | Track | Typical rounds |
|---|---|---|
| Vague idea ("something for tracking habits") | **Full discovery** — explore problem space broadly | 5–10 |
| Partial concept ("CLI tool that syncs dotfiles across machines") | **Focused discovery** — clarify core, probe edges | 3–6 |
| Detailed vision ("React dashboard with auth, these 5 endpoints...") | **Fast-path** — challenge assumptions, fill gaps, confirm | 1–3 |

Even on the fast-path, do not rubber-stamp. A detailed description is not necessarily a coherent one. Probe for contradictions, missing error handling, and unstated assumptions.

### Discovery Areas

These are not sequential steps. They are **dimensions of understanding**. Every user response potentially updates multiple dimensions. After each response, reassess which dimension has the most uncertainty and probe there next.

**Problem & Purpose**
- What problem does this solve? What's the current workaround?
- What does success look like concretely — not "users are happy" but observable, testable outcomes?
- Why does this need to exist? Is there an existing tool that already does this? If so, what's specifically wrong with it?

**Users & Context**
- Who uses it? What's their technical level?
- Is there an existing codebase, repo, or system this extends?
- How many users? 1, 10, 1000, 1M? This changes everything about the architecture.

**Core Functionality**
- What are the 3–5 most important actions?
- For each: trigger → input → expected output. No exceptions — if the user can't describe the input and output, the feature isn't understood well enough.
- What is explicitly out of scope? Push for this — unbounded scope is the #1 spec killer.
- What's the single most important thing this product does? If you had to ship only one feature, which one?

**Platform & Stack**
- Form factor: CLI, web app, API, library, desktop app, extension, bot, etc.
- Tech stack preferences or mandates — and *why*. "I like React" is different from "the team has 3 years of React experience." Challenge arbitrary choices.
- OS/environment constraints, offline requirements

**Data & State**
- What's stored? Where? Who owns it?
- Privacy, compliance, or sensitivity concerns?
- What's the source of truth? If there are multiple data stores, how do they stay consistent?

**Integrations**
- External services, APIs, auth requirements
- Interop with existing tools or workflows
- What happens when an external dependency is down? This is not optional — every integration needs a failure mode.

**Hard Constraints**
- Performance/latency/throughput targets — in numbers, not adjectives
- Budget, timeline, licensing, regulatory mandates
- Non-negotiable technical requirements (must run offline, must be single binary, etc.)

**Complexity Assessment** *(informs decomposition and agent assignment)*
- How many distinct technical concerns are there? (UI, API, storage, auth, infra, data pipeline, ML, etc.)
- Are there natural ownership boundaries where one part could be built independently?
- Which specialist agents will be needed and where?

Ask **1–3 questions per message**. Skip areas the user has already addressed.

### Techniques

**Concrete over abstract.** When answers are vague, ask for a specific scenario: "Walk me through a typical session from open to close." One good scenario is worth five abstract requirement statements. If the user can't walk through a scenario, the feature isn't ready to spec.

**Propose and react.** When the user is stuck, offer a concrete option: "Would a single YAML config file work, or do you need per-project overrides?" Reacting to a proposal is easier than generating requirements from scratch. But be honest about tradeoffs — don't present the easy option without mentioning what it costs.

**Playback.** Every 3–4 exchanges, summarize understanding in 2–3 sentences. Ask the user to confirm or correct. Catches drift early. Use playback aggressively when the conversation feels like it's meandering.

**Challenge feasibility.** If what's described is impractical (scope too large for the platform, fundamental technical barriers, conflicting requirements), say so immediately. Propose a feasible alternative. Do not silently collect an infeasible spec. Be specific about *why* it's infeasible — "that would require X which conflicts with your constraint Y."

**Expose hidden complexity.** Users routinely underestimate: auth, error handling, multi-tenancy, offline/sync, migrations, and "admin" features. When these are relevant, ask about them even if the user didn't bring them up. "You mentioned multiple users — how do you handle permissions?" is never a wasted question.

**Cut scope proactively.** If the user describes more than what's realistic for a v1, say so. Propose what to cut and why. A focused product that ships beats an ambitious one that doesn't.

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
- All core functionality is understood with **concrete input/output examples** — not descriptions, actual examples
- Scope boundaries (in/out) are explicit and the user has confirmed them
- Hard constraints are identified with specific numbers where applicable
- Contradictions are resolved — not deferred, resolved
- The product vision is coherent: every piece fits with every other piece
- Remaining unknowns are implementation decisions the Architect can make autonomously, not product decisions

Announce the transition: "I have a clear picture. Handing off to the Architect to produce the spec."

---

## Phase 2: Architect Orchestration

After Discovery, the top-level Claude launches the Architect agent with a single Agent tool call:

- **Name**: `architect`
- **Mode**: `auto`
- **Prompt**: Include all discovery context collected from the user (problem, users, core functionality, platform, data, integrations, constraints, complexity assessment). Instruct the Architect to execute Phases 2a–2e and return a summary of what was produced, any unresolved issues, and open questions for the user.

The Architect runs autonomously from here. The top-level Claude waits for the Architect to return before proceeding to Phase 3 (Validation).

---

### Phase 2a: Synthesis — Master Spec

Write the spec to `SPEC.md` in the working directory.

Adapt to the product. Omit sections that don't apply. Add sections the product demands.

### Master Spec Structure

```markdown
# [Product Name] — Specification

## Overview
- **One-liner**: What this does in one sentence.
- **Problem**: What it solves, and what the current alternative is.
- **Target user**: Who, and their technical level.
- **Success criteria**: Observable outcomes that mean v1 is working.

## Scope
### In scope (v1)
Ordered list of features/capabilities by priority. Item 1 is the last thing
to cut; the final item is the first to cut if implementation hits a wall.

For each item:
- Description
- Concrete example (sample input → expected output, or scenario walkthrough)
- Edge cases and error behavior

### Out of scope (v1)
Explicit exclusions. Anything a reasonable person might assume is included
but isn't.

### Future considerations
Ideas surfaced during discovery, parked for later. Not commitments.

## Scenarios
Key end-to-end workflows described as concrete narratives:

**Scenario: [Name]**
1. User does X with input Y
2. System responds with Z
3. User sees / gets / receives W

Include the happy path and 1–2 important failure/edge paths per scenario.

## Data Model
- Entities and their attributes
- Relationships
- Storage location and format (files, DB, in-memory, external service)
- Data the user owns vs. data fetched from external sources

## External Interfaces
- APIs consumed (with auth method)
- APIs exposed (with endpoint sketches if relevant)
- File formats read/written
- Integration points with other tools

## Constraints
- Hard performance/latency/throughput targets
- Platform and environment requirements
- Mandatory tech stack choices
- Licensing or compliance requirements

## UI/UX Overview
*(Include only if the product has a user-facing interface.)*
- Key screens, views, or command structure
- Navigation or interaction flow
- Important look-and-feel preferences expressed by the user

## Domain Decomposition
*(See Phase 3 for full structure.)*

## Agent Assignments
*(See Phase 3 for full structure.)*

## Decision Log
Assumptions and judgment calls made during spec writing. Each entry:
- **Decision**: What was decided
- **Rationale**: Why (user stated, inferred from context, or best judgment)
- **Reversible**: Yes/No — flags decisions the user should double-check

## Open Questions
Unresolved items with disposition:
- **Agents decide during spec generation**: [item] — criteria or heuristic
- **Requires user input before proceeding**: [item] — what specifically is needed
```

### Writing Principles

- **Dense, not verbose.** Every sentence should carry information. No filler.
- **Concrete over general.** "Accepts `--format json|csv|table`, defaults to `table`" beats "supports multiple output formats."
- **Priority is load-bearing.** The ordered in-scope list tells agents what to protect and what to sacrifice under pressure.
- **Distinguish requirement strength.** "must" (hard), "should" (strong preference), "could" (nice-to-have).
- **Examples are requirements.** A sample input/output pair is a concrete, testable contract.
- **Reference existing context.** If there's an existing repo or system, reference it by name/path.

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

For every domain boundary:

```markdown
## Domain Decomposition

### Domains

#### [domain-name]
- **Owns**: What this domain is solely responsible for
- **Tech stack**: Language/framework if constrained
- **Build order**: Can start immediately / blocked by [other domain]

### Interface Contracts

#### [domain-a] → [domain-b]: [contract name]
- **Mechanism**: REST API / gRPC / function call / shared file / message queue
- **Contract**:
  - Endpoint or function signature
  - Request shape (with example)
  - Response shape (with example)
  - Error cases and codes
- **Owner**: Which domain owns the contract definition (the provider)

### Shared Definitions
- **Entity schemas**: Canonical definitions for cross-boundary entities
- **Error format**: Standard error response shape
- **Auth token format**: If multiple domains validate auth
- **Naming conventions**: Path style, field casing, enum format

### Build Order
1. `storage` — no dependencies
2. `auth` — depends on storage
3. `api` — depends on storage + auth
4. `frontend` — depends on api contracts (can stub)
```

### Agent Assignment Matrix

The Architect produces an explicit assignment table in the master spec:

```markdown
## Agent Assignments

| Domain | Backend | Frontend | DevOps | Security | QA | Product Design | Tech Writing |
|--------|---------|----------|--------|----------|----|----------------|--------------|
| api    | ✓       |          | ✓      | ✓        | ✓  |                | ✓            |
| frontend |       | ✓        |        | ✓        | ✓  | ✓              |              |
| storage | ✓      |          | ✓      | ✓        | ✓  |                |              |
| auth   | ✓       |          |        | ✓        | ✓  |                | ✓            |

### Execution Plan

**Parallel batch 1** (no dependencies):
- storage × [Backend, DevOps, Security, QA]

**Parallel batch 2** (depends on storage):
- auth × [Backend, Security, QA, Tech Writing]

**Parallel batch 3** (depends on storage + auth):
- api × [Backend, DevOps, Security, QA, Tech Writing]

**Parallel batch 4** (depends on api contracts):
- frontend × [Frontend, Security, QA, Product Design]

Within each batch, all agent calls execute in parallel.
```

The execution plan respects both domain dependency order (topological sort) and maximizes parallelism within each batch.

---

### Phase 2c: Agent Spec Generation

The Architect launches specialist agents using the Agent tool, following the execution plan's batch order. All agents within a batch run in parallel. Each agent writes its section of `specs/SPEC-{domain}.md` directly.

Each agent receives: the master spec, its domain context (ownership, contracts, shared definitions), and its role-specific instructions. Agents in later batches also receive the domain specs produced by earlier batches.

#### Agent Base Prompt

Every agent receives this context, filled in by the Architect:

```
You are the {agent.role} specialist for the [{domain.name}] domain of a
larger system. A Software Architect has defined the master spec and your
assignment. Stay strictly within your role and domain scope.

## Master Spec
{masterSpec}

## Your Domain
- **Name**: {domain.name}
- **Owns**: {domain.owns}
- **Tech stack**: {domain.techStack}
- **Depends on**: {domain.dependencies}

## Interface Contracts You Provide
{domain.exposedContracts}

## Interface Contracts You Consume
{domain.consumedContracts}

## Shared Definitions
{sharedDefinitions}

## Prior Specs (from domains you depend on)
{priorSpecs — empty for batch 1, populated for later batches}

---

{agentRoleInstructions}

Write your output as your section of `specs/SPEC-{domain.name}.md`.

Be concrete. Use actual names, types, and structures. Do not restate the
master spec — reference it, extend it. Stay dense: no filler.
```

#### Role-Specific Instructions

**Backend**
```
Produce a domain spec covering:
1. Internal architecture: components, modules, key abstractions. Name the
   structs/classes/modules.
2. Data ownership: what this domain stores, schema details, migrations.
3. Contract implementation: for each interface you provide, detail the
   implementation approach. For each you consume, detail call patterns
   and failure handling.
4. Performance-critical paths and optimization approach.
5. Build plan: ordered implementation steps, each independently testable.
```

**Frontend**
```
Produce a domain spec covering:
1. Component hierarchy: top-level layout, page components, shared components.
   Name them.
2. State management: what state lives where (local, global store, URL, server).
   Data flow for key interactions.
3. Routing structure and navigation flow.
4. API integration: which contracts are consumed, loading/error states,
   optimistic updates if applicable.
5. Accessibility requirements: keyboard nav, screen reader, ARIA patterns.
6. Build plan: ordered implementation steps, each independently testable.
```

**DevOps**
```
Produce a domain spec covering:
1. Build pipeline: steps from commit to deployable artifact. Linting, testing,
   building, packaging.
2. CI/CD: trigger conditions, environments (dev/staging/prod), promotion gates.
3. Containerization: Dockerfile strategy, base images, multi-stage builds
   if applicable.
4. Infrastructure: what's needed (compute, storage, networking, DNS, CDN).
   Infrastructure-as-code approach if relevant.
5. Monitoring and observability: what to measure, alerting thresholds,
   log aggregation.
6. Environment configuration: secrets management, env vars, config files.
```

**Security**
```
Produce a domain spec covering:
1. Threat model: enumerate attack surfaces for this domain. What can go wrong.
2. Auth/authz: how identity and permissions are enforced within this domain.
   Token validation, session handling, permission checks.
3. Input validation: all external inputs, validation rules, sanitization.
4. Secrets management: what secrets exist, how they're stored and rotated.
5. Dependency audit: known-vulnerable patterns to avoid, supply chain concerns.
6. Compliance: relevant regulatory requirements and how they're met.
```

**QA**
```
Produce a domain spec covering:
1. Test strategy: unit/integration/e2e split and rationale for this domain.
2. Test plan: specific test cases derived from the domain's scenarios and
   edge cases. Include inputs and expected outputs.
3. Integration test boundaries: what requires other domains, minimal stubs
   needed for isolation.
4. Acceptance criteria: for each feature in this domain, the observable
   conditions that confirm it works.
5. Regression scope: what existing behavior must be preserved as new
   features are added.
6. Non-functional tests: performance, load, security (surface-level)
   if applicable.
```

**Product Design**
```
Produce a domain spec covering:
1. Information architecture: what content and actions are exposed to the user
   in this domain. Hierarchy and grouping.
2. User flows: step-by-step interaction sequences for key tasks. Include
   decision points and error recovery.
3. Interaction patterns: form behavior, feedback mechanisms, loading states,
   empty states, error states.
4. Wireframe descriptions: for each key screen/view, describe layout, content
   zones, and interactive elements in enough detail to implement without
   a visual mockup.
5. Design system constraints: typography, spacing, color usage rules,
   component reuse expectations.
6. Copy guidelines: tone, terminology, error message style, label conventions.
```

**Tech Writing**
```
Produce a domain spec covering:
1. Documentation inventory: what docs are needed for this domain (API
   reference, user guide, developer guide, CLI help, README section).
2. API documentation: for each exposed contract, the doc structure —
   endpoint, params, examples, error codes, rate limits.
3. User-facing copy: onboarding flow text, help text, tooltips, error
   messages. Provide draft copy where possible.
4. Developer onboarding: what a new contributor needs to know to work on
   this domain. Setup, architecture overview, key decisions.
5. Changelog strategy: what constitutes a notable change, format, audience.
6. README contribution: this domain's section of the project README.
```

---

### Phase 2d: Peer Review & Revision

After all batches complete, agents read each other's specs and revise their own. Each agent reviews specs from its own domain and adjacent domains sharing interface contracts. All review-revise agents run in parallel.

Each agent:
1. Identifies contradictions, gaps, interface mismatches, and self-corrections
2. Updates its section of `specs/SPEC-{domain}.md` in place
3. Returns a summary of what it changed and what issues remain in other agents' specs

---

### Phase 2e: Architect Final Review & CLAUDE.md

The Architect reviews all domain specs and the review summaries. It checks for:
- Unresolved contradictions between agents
- Contract consistency across domain boundaries
- Completeness of coverage for all assigned roles
- Alignment with the master spec
- Cross-cutting consistency (auth flows, error formats, naming conventions)

The Architect edits any `specs/SPEC-{domain}.md` that needs fixing — it is the tiebreaker when agents disagree. Then it:
- Appends an `## Architect Review` section to `SPEC.md` (issues found, resolutions, open questions)
- Writes `CLAUDE.md` to the project root

### Output Structure

```
project/
├── CLAUDE.md
├── SPEC.md
└── specs/
    ├── SPEC-storage.md
    ├── SPEC-auth.md
    ├── SPEC-api.md
    └── SPEC-frontend.md
```

### CLAUDE.md Generation

After the final review, the Architect generates a `CLAUDE.md` file in the project root. This is the project's living source of truth for all agents that will build the product. The Architect derives it from the master spec and domain specs.

#### CLAUDE.md Structure

```markdown
# [Product Name]

## Project Summary
[1-2 paragraph summary derived from SPEC.md Overview section.]

## Architecture

**Tech stack:** [Languages, frameworks, databases, infrastructure from the spec.]

**Components:**
- **[Component name]**: [What it does, how it communicates.]
[One bullet per major component/domain.]

## Technical Standards
- **Markdown**: Line-wrap at 100 characters. Only use ASCII characters.
[Add project-specific standards from the spec: code style, naming conventions,
 formatting rules, etc.]

## Quality Standards
Quality is non-negotiable. Every agent MUST uphold these standards at all times.

### Code Coverage
The project targets **100% code coverage**. Every new feature, bug fix, or
refactor MUST include tests that cover all code paths -- happy paths, error
paths, and edge cases. If a line of code exists, a test must exercise it.
Coverage regressions are treated as build failures.

[Insert project-specific coverage commands and thresholds here, grouped by
 component. Derive from the tech stack.]

### Test Quality
Tests MUST be meaningful. Do not write tests that exist solely to inflate
coverage numbers. Each test must assert observable behavior that matters. If
a test would still pass after deleting the code it covers, it is a bad test.

### CI Health
The DevOps agent MUST routinely inspect GitHub Actions health:
- **No false positives**: A flaky or spurious CI failure MUST be investigated
  and fixed immediately. If a test fails intermittently, the root cause must be
  found and resolved -- do not re-run and hope for green.
- **No false negatives**: CI must actually catch real problems. Periodically
  verify that disabling a feature or introducing a known bug causes the expected
  gate to fail.
- **Pipeline hygiene**: Unused workflows, stale caches, and unnecessary steps
  must be cleaned up. CI should be fast and reliable.

### Code Review Rigor
Every PR must be reviewed with the assumption that bugs exist in it. Reviewers
must check:
- Edge cases and error handling
- Test coverage of the changed code paths
- Consistency with existing patterns and contracts
- Security implications of the change

Do not approve a PR because it "looks fine." Verify it.

## Key Features
[Bulleted list of v1 features derived from the spec's In Scope section.]

## Mandatory Process Rules
The following rules MUST be followed by each Claude process/agent, for each
change being made. There are no exceptions.

### Lifecycle of a Change

#### Codebase Exploration
Each process/agent MUST explore the relevant portions of the codebase as
indicated by the task at hand.

#### Worktree Isolation
Each Claude process/agent MUST work in a separate git worktree and associated
branch. Create the worktree as a sibling directory (`[project]-wt-<name>`) to
the project source root, and prefix the branch name with `bug/`, `feat/`, etc.

#### Change Implementation Loop
Always implement a change in small incremental commits. A commit MUST be
composed of a self-contained unit of logic that positively improves the overall
system. No commit MUST break any test in the repository. Before committing a
change to `git`, make sure all tests pertinent to the component you are working
on run successfully, and make sure that the code format and lint checks pass.
Rebase on top of `main` frequently to reduce the chances of merge conflicts.

**Squash before merge**: Each PR MUST be merged as a single commit. Before the
final push, squash all commits on the branch into one via interactive rebase
(`git rebase -i origin/main`, mark all but the first as `squash`). Write a
meaningful commit message that describes _what_ and _why_.

Once you are done working on your branch, make sure you run the full test suite.
If a test fails anywhere, think hard about why it failed and bias towards fixing
the root cause rather than artificially making the test pass.

[Insert project-specific test, lint, format, and type-check commands here,
 grouped by component. Derive from the tech stack and domain specs.]

#### Pull Request
Once a branch passes the required gates, the process/agent rebases the branch on
top of `main` and then creates a GitHub PR and monitors CI to make sure all gates
pass. In case of failure, the process/agent applies the "Change Implementation
Loop" process to unblock the CI job. Upon success, the process/agent notifies
the team lead that the PR is ready for merge.

It is the responsibility of the team lead to merge outstanding PRs. The team lead
MUST come up with an ordering that aims to minimize merge conflicts. The only
allowed merge strategy is "rebase+merge". Once a PR is merged, notify the agent
to clean up its worktree.

### Self-Updating Context (CLAUDE.md Auto-Amendment)
CLAUDE.md MUST be amended whenever a learning or course correction occurs:
- **Autonomous**: When any process/agent discovers something important during
  development (e.g., a new convention, a gotcha, a pattern that works or fails),
  they MUST update the relevant section of CLAUDE.md.
- **User-directed**: When the user gives an instruction that changes how the
  project works, the receiving agent MUST update CLAUDE.md immediately.

CLAUDE.md is the project's living source of truth. Stale context leads to
repeated mistakes.

### Progress Tracking
Every code change MUST be tracked in the relevant `PROGRESS-<prefix>.md` file
using the established format (Task ID, Description, Difficulty, Acceptance
Criteria, Status, Notes). After updating the component ledger, the change MUST
be rolled up into `PROGRESS.md` by the team lead. This MUST NEVER be skipped --
untracked work is invisible work, and invisible work causes coordination failures.

| Agent                | Prefix | Scope                                    |
|----------------------|--------|------------------------------------------|
| Software Architect   | ARC    | Cross-cutting architecture, spec consistency |
[One row per assigned specialist agent, with prefix and scope derived from the
 agent assignment matrix.]

## Agent Communication
Agents should DM each other directly (via SendMessage) for technical questions,
API contract clarifications, and coordination -- don't wait for the team lead to
relay. Route status updates and task completions through the team lead as usual.
```

#### Generation Rules

- **Derive, don't invent.** Every section must trace back to the master spec or domain specs. Do not add requirements not in the spec.
- **Fill in concrete commands.** The test/lint/format sections must have actual runnable commands, derived from the tech stack choices in the spec. Do not leave placeholders.
- **Agent table must match assignments.** The Progress Tracking table must list exactly the agents assigned in the master spec, with appropriate prefixes and scopes.
- **Project name in worktree pattern.** Replace `[project]` with the actual project name.

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
6. **Domain boundary review**: "Here's how I split the system. Do these ownership lines make sense?"
7. **Contract review**: "These are the interfaces between domains. Shapes correct? Anything missing?"
8. **Agent output review**: Present each domain's spec suite. Highlight what changed during peer review and what the Architect corrected.
9. **Architect review summary**: Walk through the Architect Review section of `SPEC.md` — what was caught, what was fixed, what needs user input.
10. **Final integration review**: "Here's how the pieces fit together. Does the full picture match your vision?"

Iterate until confirmed. Update spec files in place with each revision. Re-launch affected agents if master spec changes affect domain assignments or contracts.

---

## Output Files

| Project type | Files produced |
|---|---|
| Single-domain | `SPEC.md` + `CLAUDE.md` |
| Multi-domain | `CLAUDE.md` + `SPEC.md` (master) + `specs/SPEC-{domain}.md` per domain (consolidated agent specs) |

---

## Anti-Patterns

- **Don't interrogate.** If the user clearly knows what they want, accept it and move on.
- **Don't front-load.** Never dump all questions in one message. This is a conversation.
- **Don't cargo-cult.** No "As a user, I want X so that Y" unless requested. Concrete scenarios are more useful.
- **Don't defer everything.** When either choice is fine, pick one and document it in the Decision Log.
- **Don't spec implementation in the master spec.** The master spec captures *what* and *why*. Agent specs go deeper into *how* within their scoped (domain, role) cell.
- **Don't ignore the repo.** If the user has existing code, the spec should reference it.
- **Don't decompose prematurely.** A project that fits in one agent's head should stay as one spec.
- **Don't hand-wave contracts.** `GET /api/tasks?status=active → { tasks: Task[], cursor: string }` is a contract. "The frontend calls the API" is not.
- **Don't assign agents blindly.** A pure backend service doesn't need a Product Design agent. The Architect's job is to assign agents where they add value, not to run every agent everywhere.
- **Don't ignore cross-domain consistency.** The whole point of the Architect role is to catch integration issues that no single agent can see. Always run the consistency check.
- **Don't skip re-generation.** When the master spec changes materially (new domain, changed contracts), re-launch affected agents. Stale domain specs are worse than no domain specs.
