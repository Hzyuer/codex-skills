# Run Mode

Use Run Mode when the user wants to execute commands, run a service, start a demo, or validate behavior manually.

## Flow

1. Identify the exact command or workflow to run.
2. Draft or update `RUNBOOK.md` before execution when the workflow has more than one step or should be repeatable.
3. Ask for permission before creating `RUNBOOK.md`.
4. Ask for permission before running each command or command group.
5. Report command output, exit status, and observed behavior.
6. Record durable results in `SessionMemory.md` after the user authorizes document updates.
7. Pause before the next command or investigation step.

## `RUNBOOK.md` Template

````markdown
# RUNBOOK.md

## Goal

Describe what this run validates.

## Preconditions

- Required environment variables, services, files, and dependencies.

## Commands

```bash
# One command per step with expected working directory.
```

## Expected Result

- Describe success signals and acceptable warnings.

## Troubleshooting

- List known failure modes and next checks.

## Last Run

- YYYY-MM-DD: Command, exit status, result, and follow-up.
````

## Command Rules

- Prefer read-only or low-risk commands first.
- Do not install packages, start long-running services, open GUI apps, or use network access without explicit permission.
- If a command fails, explain the failure and ask before changing files or running a broader diagnostic.
