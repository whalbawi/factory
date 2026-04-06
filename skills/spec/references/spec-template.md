# Master Spec Template

This is the complete template structure for `SPEC.md`. Adapt to the product:
omit sections that don't apply, add sections the product demands.

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
- Concrete example (sample input -> expected output, or scenario walkthrough)
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

Include the happy path and 1-2 important failure/edge paths per scenario.

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

## Sprint Plan
*(Produced during Phase 2b when the project has multiple sprints.
Omitted for single-sprint projects with 8 or fewer tasks.)*

| Sprint | Tasks | Priority Tier | Dependencies |
|--------|-------|---------------|--------------|
| 1 | T1, T2, T3, T4 | P0 (core functionality) | None |
| 2 | T5, T6, T7 | P1 (essential features) | Sprint 1 complete |

### Sprint 1: [Goal]
- **Tasks**: T1 (description), T2, T3, T4
- **Parallel batches**: Batch 1 [T1], Batch 2 [T2, T3], Batch 3 [T4]
- **Checkpoint criteria**: [Concrete, testable statement of what this sprint delivers]

### Sprint 2: [Goal]
- **Tasks**: T5, T6, T7
- **Parallel batches**: Batch 1 [T5, T6, T7]
- **Checkpoint criteria**: [Concrete, testable statement]

## Decision Log
Assumptions and judgment calls made during spec writing. Each entry:
- **Decision**: What was decided
- **Rationale**: Why (user stated, inferred from context, or best judgment)
- **Reversible**: Yes/No -- flags decisions the user should double-check

## Open Questions
Unresolved items with disposition:
- **Agents decide during spec generation**: [item] -- criteria or heuristic
- **Requires user input before proceeding**: [item] -- what specifically is needed
```

## Domain Decomposition Template

For every domain boundary, use this structure in `SPEC.md`:

```markdown
## Domain Decomposition

### Domains

#### [domain-name]
- **Owns**: What this domain is solely responsible for
- **Tech stack**: Language/framework if constrained
- **Build order**: Can start immediately / blocked by [other domain]

### Interface Contracts

#### [domain-a] -> [domain-b]: [contract name]
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
1. `storage` -- no dependencies
2. `auth` -- depends on storage
3. `api` -- depends on storage + auth
4. `frontend` -- depends on api contracts (can stub)
```

## Agent Assignment Matrix Template

The Architect produces an explicit assignment table in the master spec:

```markdown
## Agent Assignments

| Domain | Backend | Frontend | DevOps | Security | QA | Product Design | Tech Writing |
|--------|---------|----------|--------|----------|----|----------------|--------------|
| api    | x       |          | x      | x        | x  |                | x            |
| frontend |       | x        |        | x        | x  | x              |              |
| storage | x      |          | x      | x        | x  |                |              |
| auth   | x       |          |        | x        | x  |                | x            |

### Execution Plan

**Parallel batch 1** (no dependencies):
- storage x [Backend, DevOps, Security, QA]

**Parallel batch 2** (depends on storage):
- auth x [Backend, Security, QA, Tech Writing]

**Parallel batch 3** (depends on storage + auth):
- api x [Backend, DevOps, Security, QA, Tech Writing]

**Parallel batch 4** (depends on api contracts):
- frontend x [Frontend, Security, QA, Product Design]

Within each batch, all agent calls execute in parallel.
```
