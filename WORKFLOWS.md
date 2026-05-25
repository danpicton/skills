# Workflows

Common multi-skill sequences for situations that don't have a single skill.

## Tightening an existing project

Use this when a project has accumulated complexity, missing documentation, or an unclear structure.

1. **[`/grill-with-docs`](./skills/engineering/grill-with-docs/SKILL.md)** — build a shared vocabulary (`CONTEXT.md`) and surface decisions worth recording as ADRs. Best starting point even if the code already exists.
2. **[`/improve-codebase-architecture`](./skills/engineering/improve-codebase-architecture/SKILL.md)** — find deepening opportunities: muddy module boundaries, unnecessary complexity, things that don't match the language in `CONTEXT.md`.
3. **[`/triage`](./skills/engineering/triage/SKILL.md)** / **[`/to-prd`](./skills/engineering/to-prd/SKILL.md)** — prioritise the backlog of improvements, then spec out the bigger ones before diving in.

The order matters: `grill-with-docs` first gives the architecture skill a shared language to reason against. Skip it if `CONTEXT.md` already exists and is current.

Use **[`/zoom-out`](./skills/engineering/zoom-out/SKILL.md)** at any point on areas of the codebase you haven't touched in a while before making changes there.
