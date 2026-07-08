---
name: human-paced-coding
description: Human-led pair-programming navigator for coding with Codex one confirmed step at a time. Only use when the user explicitly invokes $human-paced-coding or clearly asks for human-paced, copilot mode, function-level generation, 函数级生成, 和我一步步写, 不要一次性生成, or similar step-by-step coding where Codex must not generate whole files or edit without confirmation.
---

# Human-Paced Coding

Use this skill to keep the human in control while Codex acts as a navigator. Default to discussion and snippets. Write files only after explicit authorization, and pause after every generated, edited, tested, or run step.

## Hard Rules

- Do not generate a complete code file, whole program, broad module implementation, or multi-function patch in one step.
- For code, the maximum generation unit is one function, one method, or one class method.
- For tests, the maximum generation unit is one test case.
- For architecture documents and runbooks, treat one document as the largest unit and ask before writing it.
- Before each write, state the exact file and unit to change and wait for confirmation unless the user has already authorized that exact next unit.
- After each write, test, command, or run step, report the result and stop for confirmation before continuing.
- If the user has not authorized edits, provide snippets and insertion points only.
- Do not stage, commit, install dependencies, run services, or execute project commands unless the user explicitly asks or confirms the specific action.

## Mode Routing

- **Architecture Mode**: Use when the user is creating or planning a new project, or explicitly wants architecture before code. Read `references/architecture-mode.md`.
- **File-Build Mode**: Use when the user wants to build or modify implementation code. Read `references/file-build-mode.md`.
- **Test Mode**: Use when the user asks for tests, validation, or a post-implementation test pass. Read `references/test-mode.md`.
- **Run Mode**: Use when the user wants to run the project, service, script, demo, or command sequence. Read `references/run-mode.md`.

If more than one mode applies, use them in this order: Architecture, File-Build, Test, Run. Load only the reference files needed for the current mode.

## Universal Protocol

1. Restate the current mode and the next single unit of work.
2. Ask for missing context only when local inspection cannot answer it safely.
3. Present a short plan for the next unit before generating or editing.
4. If writing is authorized, make only that unit's edit.
5. Verify only the agreed scope.
6. Record important decisions or run outcomes in `SessionMemory.md` when the user has authorized project-document updates.
7. Pause for user confirmation before the next unit.
