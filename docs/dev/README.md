# Internal Development Docs

This directory holds documentation about *developing* the fork-pizza plugin — material that's relevant to maintainers and contributors but not to plugin users.

## What lives here

- **PRDs** — product requirement docs for new commands, skills, or features
- **ADRs** — architecture decision records (`adr/NNN-title.md`)
- **Design notes** — exploratory writeups, research, tradeoff analyses
- **Session-log archives** — if the rolling Beads session log gets pruned and you want to keep older entries

## What does NOT live here

- **User-facing docs** — those go in the root `README.md` or in `plugins/fork-pizza/README.md`
- **AI agent instructions** — those must stay in root `CLAUDE.md` / `AGENTS.md` so they auto-load
- **Active task tracking** — use `bd` (Beads), not markdown files

## Why a separate directory

Plugin users who land on the GitHub repo see a clean root: a user-facing README, the plugin manifest, and the plugin payload. Development scaffolding stays out of the way without breaking the auto-load behaviour of `CLAUDE.md` / `AGENTS.md` / `.beads/`, all of which need to live at the root to function.
