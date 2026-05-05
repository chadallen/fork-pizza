# Claude Workflow — Conventions

These conventions are injected into every Claude session via the plugin's SessionStart hook.
They apply to all projects using this workflow. Project-specific rules go in CLAUDE.md.

## Beads CLI

- All `bd` commands use `--json` for reliable parsing.
- When Beads' own SessionStart hook is configured (via `bd setup claude`), it must use `bd prime --stealth` (not `bd prime` or `bd sync`) to avoid noisy terminal output.
- Use `bd close <id1> <id2> ...` to close multiple issues at once when they share the same closing context. Use individual `bd close <id> --reason="..." --json` when each needs a distinct reason (e.g., end-session).

## Commit Format

Include the task ID in every commit: `git commit -m "<message> (<task-id>)"`

This enables orphan detection at session end and links code changes to the task that motivated them.

## Agent Model

Never hardcode a model in agent or skill frontmatter — always use `model: inherit`.

## CLAUDE.md

- Target length: under 80 lines.
- Session history, progress tracking, and architecture decisions do NOT belong here.
- Keep to: project description, stack, build/test commands, hard constraints, and project-specific conventions.

## scratch.md

Always in `.gitignore`. Never read by agents. Used for ephemeral working notes only.

## Session Log

One Beads issue per project tagged `session-log` holds the running session history.

- `/fork-pizza:start-session` auto-creates it on first use.
- `/fork-pizza:end-session` prepends a dated entry to the `notes` field and trims to the last 5 entries.
- Never write session history to CLAUDE.md or any other file — the Session Log is the only durable record.
- The most recent entry (first in notes) is the "last session recap" for `/fork-pizza:start-session`.
