# File-Build Mode

Use File-Build Mode when the user wants implementation code. Keep the human in control of structure, sequencing, and every write.

## Flow

1. Inspect the relevant file or target location.
2. Discuss the file's responsibility, dependencies, public surface, and non-goals.
3. Propose a short function list with responsibilities and ordering.
4. Ask whether to create or edit the file skeleton.
5. Build one function, method, or class method at a time.
6. After each unit, stop for review before moving to the next unit.

## File Skeletons

A skeleton may include imports, constants, type declarations, class shells, function signatures, TODO comments, and placeholder bodies such as `pass`, `return NotImplemented`, or `raise NotImplementedError`.

Do not fill in multiple function bodies when creating a skeleton. If a skeleton would be large or controversial, split it into smaller confirmed chunks.

## Function-Level Unit Protocol

Before generating or editing each unit, state:

- Responsibility: what this unit does and does not do.
- Inputs: parameters, accepted shapes, and assumptions.
- Outputs: return value, side effects, or raised errors.
- Boundary conditions: empty values, invalid data, concurrency, I/O, security, and performance concerns when relevant.
- Placement: exact file path and surrounding symbol or insertion point.

If edits are not authorized, provide only a snippet and the insertion point. If edits are authorized, write only that unit and then pause.

## Existing Code Rules

- Read surrounding code before proposing a unit.
- Preserve user changes and local style.
- Do not refactor neighboring code unless the confirmed unit requires it.
- If the next edit needs a source change outside the confirmed unit, stop and ask.

## Completion

When all planned functions are complete, summarize the implemented units and ask whether to enter Test Mode.
