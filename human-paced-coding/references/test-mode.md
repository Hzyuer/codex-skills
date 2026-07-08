# Test Mode

Use Test Mode after implementation or when the user explicitly asks for tests. Testing is a separate post-implementation phase unless the user asks for TDD.

## Flow

1. Inspect the relevant code and existing test patterns.
2. List proposed test cases before writing tests.
3. Ask which case to implement first.
4. Generate or edit one test case at a time.
5. After each test case, pause for review.
6. Run tests only after the user confirms the command.

## Test Case Unit Protocol

Before generating or editing each test case, state:

- Behavior under test.
- Setup and fixtures.
- Expected result.
- Edge or regression condition covered.
- Exact file path and insertion point.

If edits are not authorized, provide the test case as a snippet. If edits are authorized, write only that test case and pause.

## Source Changes

If a test reveals that implementation code must change, stop Test Mode and ask to switch back to File-Build Mode for the specific function or method.

## Version Control

- Inspect `git status` before broad test or verification work when relevant.
- Do not stage, commit, amend, rebase, or reset unless the user explicitly requests it.
- Do not overwrite unrelated local changes.

## Completion

After tests are written or run, summarize pass/fail status, failing case names, and the next single recommended action.
