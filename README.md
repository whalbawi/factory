# Factory

A pipeline of Claude Code skills that takes software products from idea to
production. Factory formalizes the process of using Claude to build software
into a repeatable, systematic workflow: ideation, specification, prototyping,
setup, build, retrospective, QA, security, and deployment.

## What Factory Does

Factory provides 10 Claude Code skills that cover the entire software
development lifecycle. You can run the full pipeline with `/genesis`, or
invoke any skill independently.

```text
/ideation -> /spec -> /prototype -> /setup -> /build -> /retro -> /qa -> /security -> /deploy
```

| Skill | Purpose |
|-------|---------|
| `/genesis` | Orchestrator — guides you through the full pipeline |
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

Clone the repo and run the installer:

```bash
git clone https://github.com/whalbawi/factory.git
cd factory
./install.sh
```

The installer offers two modes:

- **Global** — symlinks skills to `~/.claude/skills/`. Available in all
  projects. Updates automatically when you pull the repo.
- **Local** — copies skills to `./skills/` in the current directory.
  Versioned with your project. Manual updates.

You can also pass flags directly:

```bash
./install.sh --global      # non-interactive global install
./install.sh --local       # non-interactive local install
./install.sh --uninstall   # remove globally installed skills
```

## Usage

### Full pipeline (new project)

```text
> /genesis

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

If you close your terminal mid-pipeline, just invoke `/genesis` again.
It reads `.factory/state.json` and offers to resume where you left off.

## How It Works

### Pipeline state

Every skill updates `.factory/state.json` on invocation and completion,
even when invoked standalone. This keeps pipeline state consistent and
lets `/genesis` know what has been done.

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

## Requirements

- [Claude Code](https://claude.com/claude-code) CLI
- Git
