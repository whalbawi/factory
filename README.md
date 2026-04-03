# Factory

A pipeline of Claude Code skills that takes software products from idea to
production. Factory formalizes the process of using Claude to build software
into a repeatable, systematic workflow: ideation, specification, prototyping,
setup, build, retrospective, QA, security, and deployment.

## What Factory Does

Factory provides 10 Claude Code skills that cover the entire software
development lifecycle. You can run the full pipeline with `/factory`, or
invoke any skill independently.

```text
/ideation -> /spec -> /prototype -> /setup -> /build -> /retro -> /qa -> /security -> /deploy
```

| Skill | Purpose |
|-------|---------|
| `/factory` | Orchestrator — guides you through the full pipeline |
| `/ideation` | Brainstorm features for new or existing products |
| `/spec` | Turn an idea into a detailed, buildable specification |
| `/prototype` | Quick throwaway implementations to compare alternatives |
| `/setup` | Project scaffolding, CI/CD, deployment infra, telemetry |
| `/build` | Agent teams construct the product in parallel worktrees |
| `/retro` | Team retrospective — mandatory checkpoint after build |
| `/qa` | Structured quality control beyond "tests pass" |
| `/security` | Security audit and deployment gate |
| `/deploy` | Ship to alpha, staging, or production |

## Installation

### Option 1: Global install (available everywhere)

Copy each skill to your Claude Code skills directory:

```bash
# From the factory repo root
for skill in skills/*/; do
  name=$(basename "$skill")
  mkdir -p ~/.claude/skills/"$name"
  cp "$skill"SKILL.md ~/.claude/skills/"$name"/SKILL.md
done
```

### Option 2: Project-local (versioned with your project)

Copy the `skills/` directory into your project. Claude Code discovers
skills in the project directory automatically.

```bash
cp -r /path/to/factory/skills/ ./skills/
```

### Option 3: Global install with symlinks (versioned + available everywhere)

Symlink from the Factory repo to the global skills directory. Updates to
the repo are reflected immediately.

```bash
for skill in skills/*/; do
  name=$(basename "$skill")
  mkdir -p ~/.claude/skills/"$name"
  ln -sf "$(pwd)/$skill"SKILL.md ~/.claude/skills/"$name"/SKILL.md
done
```

**Note:** The `/spec` skill is installed separately. If you don't already
have it, copy it from `~/.claude/skills/spec/` or install it from its own
repository.

## Usage

### Full pipeline (new project)

```text
> /factory

Let's build something. Do you have an idea already, or want to brainstorm?
```

Factory will guide you through each phase, confirming at every transition.
You can skip phases, go back to earlier phases, or exit and resume later.
Pipeline state is saved in `.factory/state.json`.

### Individual skills (existing project)

Invoke any skill directly when you need it:

```text
> /ideation          # Brainstorm new features
> /spec              # Spec out a feature
> /prototype         # Try different approaches
> /qa                # Run quality checks
> /security          # Security audit
> /deploy            # Ship it
> /retro             # Team sync
```

### Resuming an interrupted pipeline

If you close your terminal mid-pipeline, just invoke `/factory` again.
It reads `.factory/state.json` and offers to resume where you left off.

## How It Works

### Pipeline state

Every skill updates `.factory/state.json` on invocation and completion,
even when invoked standalone. This keeps pipeline state consistent and
lets `/factory` know what has been done.

### Deployment environments

Factory sets up three deployment environments via Fly.io:

- **Alpha** (`{app}-alpha`) — opt-in deploys by agents during build
- **Staging** (`{app}-staging`) — promoted after QA passes
- **Prod** (`{app}`) — promoted after security clears + user confirms

### Agent teams

The `/build` skill uses an agent team model where specialist agents work
in parallel git worktrees:

| Agent | Prefix | Role |
|-------|--------|------|
| Software Architect | ARC | Orchestration, task breakdown, merge coordination |
| Backend | BE | APIs, data layer, business logic |
| Frontend | FE | UI components, client-side logic |
| DevOps | OPS | Infrastructure, CI/CD, deployment configs |
| Security | SEC | Auth, input validation, hardening |
| QA | QA | Test authoring, coverage, integration tests |
| Product Design | PD | UX flows, accessibility, interaction patterns |
| Tech Writing | TW | Documentation, user-facing copy |

Not all agents are active for every project. The Architect assigns based
on the project's domain decomposition.

## Repository Structure

```text
factory/
  CLAUDE.md                    # Factory project conventions
  SPEC.md                      # Master specification
  README.md                    # This file
  .markdownlint.json           # Markdown linting config
  .github/workflows/ci.yml     # CI pipeline
  scripts/
    check-contracts.sh         # Contract consistency checker
    check-crossrefs.sh         # Cross-reference checker
    validate-frontmatter.sh    # YAML frontmatter validator
  skills/
    factory/SKILL.md           # Pipeline orchestrator
    ideation/SKILL.md          # Brainstorming
    prototype/SKILL.md         # Quick alternatives
    setup/SKILL.md             # Scaffolding + infra
    build/SKILL.md             # Agent-team construction
    retro/SKILL.md             # Team retrospective
    qa/SKILL.md                # Quality control
    security/SKILL.md          # Security gate
    deploy/SKILL.md            # Deployment
  specs/
    SPEC-core-skills.md        # Shared conventions index
    SPEC-orchestration.md      # Orchestrator spec
    SPEC-ideation.md           # Per-skill specs
    SPEC-spec.md
    SPEC-prototype.md
    SPEC-setup.md
    SPEC-build.md
    SPEC-retro.md
    SPEC-qa.md
    SPEC-security.md
    SPEC-deploy.md
    SPEC-monitor.md            # v1.1
```

## Requirements

- [Claude Code](https://claude.com/claude-code) CLI
- Git
- GitHub CLI (`gh`) for PR workflows
- Fly.io CLI (`fly`) for deployment (optional — adapts to other targets)
