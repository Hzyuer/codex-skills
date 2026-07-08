# Architecture Mode

Use Architecture Mode when starting a new project, reshaping a project before code, or when the user explicitly asks to plan first. The outcome is shared understanding plus project navigation documents, not business-code implementation.

## Flow

1. Confirm the project goal, target users, runtime/platform, and constraints.
2. Identify the smallest useful first milestone.
3. Propose the repo structure, main files, data flow, and risk points.
4. Ask for confirmation before creating or updating architecture documents.
5. For existing repos, do not add missing root documents until the user confirms.
6. Do not generate implementation code in Architecture Mode. Switch to File-Build Mode when the user asks to start coding.

## Default Root Documents

For a new project, propose these root files. Create or update them only after explicit authorization:

- `AGENTS.md`: working conventions for Codex and future agents.
- `README.md`: project purpose, setup, and basic usage.
- `SessionMemory.md`: chronological decisions, progress, run outcomes, and open questions.
- `NAVIGATION.md`: repo map explaining where important behavior lives.

## Document Templates

### `AGENTS.md`

```markdown
# AGENTS.md

## Project Guidance

- Work in human-paced mode unless the user explicitly switches modes.
- Keep changes scoped to the confirmed unit of work.
- Do not run commands, install dependencies, stage changes, or commit without confirmation.

## Coding Conventions

- Follow existing project patterns.
- Prefer small, named functions with clear inputs and outputs.
- Add tests after implementation unless the user asks for test-first work.
```

### `README.md`

```markdown
# Project Name

## Purpose

Describe what this project does and who it is for.

## Setup

List installation and environment steps.

## Usage

Show the minimal command or workflow to use the project.

## Status

Summarize the current milestone and known gaps.
```

### `SessionMemory.md`

```markdown
# SessionMemory.md

## Current Goal

- Describe the active user goal.

## Decisions

- YYYY-MM-DD: Record durable project decisions.

## Progress

- YYYY-MM-DD: Record completed units of work.

## Run Results

- YYYY-MM-DD: Record commands, outcomes, and follow-up actions.

## Open Questions

- Track unresolved questions for the next session.
```

### `NAVIGATION.md`

```markdown
# NAVIGATION.md

## Repo Map

- `path/`: Explain what lives here.

## Key Flows

- Describe the main runtime or user workflows.

## Entry Points

- List commands, app entry files, and important integration points.

## Testing

- Explain where tests live and how to run them.
```

## Pause Point

After drafting or writing one architecture document, stop and ask which document or mode to handle next.
