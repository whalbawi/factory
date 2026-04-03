# /ideation — Divergent Brainstorming for Structured, Actionable Feature Ideas

`/ideation` is a conversational skill that guides the user through divergent
brainstorming, then converges on prioritized, structured feature ideas. It produces
`IDEATION.md` — a document that captures explored ideas, selected candidates, and
parked alternatives. The output feeds directly into `/spec`.

## Contract

| Field | Value |
|-------|-------|
| **Required inputs** | None |
| **Optional inputs** | Existing codebase, prior `IDEATION.md` |
| **Outputs** | `IDEATION.md` |
| **Failure** | Partial `IDEATION.md` with `status: incomplete` |

When optional inputs are present, the skill uses them to ground brainstorming in the
current product reality rather than starting from a blank slate.

## Category

**Conversational skill** (heavy user interaction).

This skill is dialog-driven from start to finish. Every step involves asking the user
questions, presenting options, and incorporating their responses. There are no
autonomous or agentic phases. The skill cannot run unattended.

## Process

### Step 1: Context Gathering

Read existing codebase (if any), existing spec, existing ideation docs. Understand the
current product and its users. If a prior `IDEATION.md` exists, review parked ideas —
they may be relevant to this session.

### Step 2: Problem Space Exploration

Ask the user about:

- Biggest friction points for users
- Requests they've received
- Competitive gaps
- Technical debt that's blocking progress
- Adjacent problems the product could solve

Do not rush this step. The quality of ideation depends on understanding the problem
space deeply before generating solutions.

### Step 3: Idea Generation

Generate 5-8 feature ideas. For each:

- One-line description
- Problem it solves
- Effort estimate (S/M/L)
- Impact estimate (S/M/L)
- Technical feasibility notes
- Dependencies on existing features

### Step 4: Prioritization

Present an effort/impact matrix. Help user select 1-3 ideas to pursue. The matrix
makes tradeoffs visible — high-impact/low-effort ideas are obvious wins, but
high-effort/high-impact ideas deserve discussion too.

### Step 5: Deep Dive

For selected ideas, flesh out:

- User stories (concrete scenarios, not Agile boilerplate)
- Technical approach sketch
- Risks and unknowns
- Relationship to existing features

### Step 6: Output

Write `IDEATION.md` using the output template below.

## State Tracking

Every invocation of `/ideation` must update `.factory/state.json`, whether the skill
is invoked standalone or via the `/genesis` orchestrator. This ensures pipeline state
remains consistent and resumable.

### On Start

When `/ideation` begins, update (or create) `.factory/state.json`:

```json
{
  "phases": {
    "ideation": {
      "status": "in_progress",
      "started_at": "2026-04-03T10:00:00Z"
    }
  }
}
```

If the state file does not exist, create it with the `ideation` phase entry. If it
exists, merge — do not overwrite other phases.

### On Completion

When `/ideation` finishes successfully:

```json
{
  "phases": {
    "ideation": {
      "status": "completed",
      "started_at": "2026-04-03T10:00:00Z",
      "completed_at": "2026-04-03T10:45:00Z",
      "outputs": ["IDEATION.md"]
    }
  }
}
```

### On Failure

If `/ideation` cannot complete (user abandons session, error, etc.):

```json
{
  "phases": {
    "ideation": {
      "status": "failed",
      "started_at": "2026-04-03T10:00:00Z",
      "failed_at": "2026-04-03T10:30:00Z",
      "failure_reason": "User ended session before idea selection"
    }
  }
}
```

On failure, write a partial `IDEATION.md` with whatever was produced so far. Include
`status: incomplete` in the document header so downstream skills know the output is
not finalized.

### State File Creation

If no `.factory/state.json` exists when `/ideation` is invoked:

1. Create the `.factory/` directory if it does not exist.
2. Initialize `state.json` with the ideation phase entry.
3. Proceed normally.

This is critical for standalone invocations where the orchestrator has not already
created the state file.

## Output Template

```markdown
# Ideation: [Product Name] — [Date]

## Context
[Current product state, what prompted ideation]

## Ideas Explored

### [Idea Name]
- **Description**: ...
- **Problem**: ...
- **Effort**: S/M/L
- **Impact**: S/M/L
- **Feasibility**: ...
[Repeat for each idea]

## Selected for Development

### [Selected Idea]
- **Scenarios**: ...
- **Technical approach**: ...
- **Risks**: ...
- **Next step**: Feed into `/spec`

## Parked Ideas
[Ideas not selected, preserved for future]
```

## Mindset

Be generative, not critical. This is the one phase where wild ideas are welcome.
Critique comes later during `/spec`. But do not confuse generative with unstructured
— every idea must have a concrete problem it solves.

## Anti-Patterns

- **Premature critique**: Do not shoot down ideas during generation (step 3). The
  prioritization step (step 4) is where filtering happens.

- **Skipping problem space exploration**: Jumping straight to idea generation
  produces shallow, obvious ideas. Step 2 is where the insight lives.

- **Ungrounded ideas**: Every idea must tie back to a real problem. "Wouldn't it be
  cool if..." without a problem statement is noise.

- **Over-scoping selected ideas**: The deep dive (step 5) is a sketch, not a spec.
  Keep it lightweight — `/spec` handles the detailed specification.

- **Ignoring prior work**: If `IDEATION.md` already exists or there is an existing
  codebase, the skill must read and reference it. Do not brainstorm in a vacuum when
  context is available.

- **Monologue mode**: This is a conversational skill. If you are generating ideas
  without asking the user questions, you are doing it wrong. Every step should
  involve the user.
