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

- Target length: under 120 lines.
- Session history, progress tracking, and architecture decisions do NOT belong here.
- Keep to: project description, stack, build/test commands, hard constraints, and project-specific conventions.

## scratch.md

Always in `.gitignore`. Never read by agents. Used for ephemeral working notes only.

## Session Log

One Beads issue per session tagged `session-log`. Each session creates its own issue, writes a summary to its notes, and closes it at session end.

- `/fork-pizza:start-session` finds the most recent closed `session-log` issue for the last session recap, then creates a new one for the current session.
- `/fork-pizza:end-session` writes the session summary into the open `session-log` issue's notes and closes it.
- Never write session history to CLAUDE.md or any other file — the Session Log issues are the only durable record.
- History is preserved in Dolt — no trimming needed.
