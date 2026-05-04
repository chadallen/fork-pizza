# fork-pizza

An autonomous coding workflow for Claude Code. Sub-agents implement tasks in parallel, reviewers check the work, and you stay in the loop at the level you want.

## What it does

1. **Task tracking** — [Beads](https://github.com/steveyegge/beads) keeps tasks small and well-defined. Epics group related work. Dependencies are tracked.
2. **Autonomous build loop** — `/fork-pizza:build-tasks` runs implementer agents in parallel (up to 3 per frontier), followed by 8-dimensional code review. You approve the plan and walk away.
3. **Session orientation** — `/fork-pizza:start-session` reads a Session Log issue and your task state, surfaces what's next, and waits for your go-ahead.
4. **ADRs** — Architecture Decision Records capture why you made the choices you did, so future agents don't re-litigate them.

## Requirements

- Claude Code (Pro or Max subscription)
- **[Beads](https://github.com/steveyegge/beads)** — task tracker for AI agents

```bash
brew install beads    # macOS
```

For other platforms, see the [Beads installation docs](https://github.com/steveyegge/beads).

## Install

```bash
/plugin install github.com/chadallen/fork-pizza
```

Or install a specific version (recommended — see [Risks: /plugin update](#risks)):

```bash
/plugin install github.com/chadallen/fork-pizza@v0.1.0
```

## Setup

```
1. /init                                  # Claude Code built-in — creates CLAUDE.md
2. /plugin install github.com/chadallen/fork-pizza
3. /fork-pizza:start-session         # tells you "install bd" if missing
4. brew install beads
5. /fork-pizza:start-session         # tells you "describe work to get started"
6. /fork-pizza:create-tasks          # describe work; Claude drafts a proposal
7. /fork-pizza:start-session         # shows ready tasks
8. /fork-pizza:build-tasks           # agents implement, review, close, push
9. /fork-pizza:end-session           # writes Session Log, pushes everything
```

`/fork-pizza:start-session` always tells you what's next — same pattern as `git status`. You don't need to remember the flow.

## Commands

| Command | When |
|---|---|
| `/fork-pizza:start-session` | Beginning of every session. Reads Session Log and task state, proposes a plan. |
| `/fork-pizza:create-tasks` | After brainstorming — turns conversation or a PRD file into tasks. |
| `/fork-pizza:build-tasks` | Autonomous build loop. Runs implementers, reviewers, and closures. |
| `/fork-pizza:end-session` | End of every session. Writes Session Log entry, commits, pushes. |
| `/fork-pizza:adr` | Record an architectural decision. Usually invoked automatically by end-session. |

### Keyboard tip

All commands autocomplete — type `/fork-pizza:` and press Tab to see the picker.

### build-tasks flags

```
/fork-pizza:build-tasks                    # next ready task (asks: run to completion or checkpoints?)
/fork-pizza:build-tasks --auto             # run until complete, no prompts
/fork-pizza:build-tasks --checkpoints      # stop for review after each task
/fork-pizza:build-tasks <epic-id>          # all tasks in an epic
/fork-pizza:build-tasks <task-id>          # one specific task
```

## Skills (auto-invoked, not user-facing)

The `implementer` and `code-reviewer` agents automatically load a language skill at the start of each task based on the files being touched. You don't invoke these directly.

| Skill | Language |
|---|---|
| `typescript-developer` | TypeScript / JavaScript |
| `python-developer` | Python |
| `ios-developer` | Swift / iOS |

## Session Log

There is no `plan.MD`. Instead, one Beads issue per project tagged `session-log` holds the running session history. `/start-session` creates it on first run. `/end-session` prepends a dated entry and keeps the last 5. The result shows up in `bd show` — nothing to maintain manually.

## Migrating from the old clone-based workflow

If you previously cloned the repo into your project and copied files to `~/.claude/skills/` or `~/.claude/agents/`, remove those copies before installing the plugin:

```bash
# Remove stale global copies
rm -rf ~/.claude/skills/start-session \
       ~/.claude/skills/end-session \
       ~/.claude/skills/build-tasks \
       ~/.claude/skills/create-tasks \
       ~/.claude/skills/adr \
       ~/.claude/agents/implementer.MD \
       ~/.claude/agents/code-reviewer.MD

# The plugin installs to its own cache — no collision with project-local .claude/
```

Also: `plan.MD` is no longer maintained. The Session Log issue replaces it. You can delete `plan.MD` from your project after migration.

## Versioning

`"version": "0.1.0"` in the manifest — consumers only get updates when you explicitly run `/plugin update`. See the Risks section below on why `/plugin update` may be unreliable.

Breaking changes (renaming a command, changing hook contracts) will bump the minor version. Additive changes (new commands, new skills) bump the patch version.

## Risks

### `/plugin update` may not actually update

There are open Claude Code issues ([#15642](https://github.com/anthropics/claude-code/issues/15642), [#29071](https://github.com/anthropics/claude-code/issues/29071)) where `/plugin update` runs `git fetch` but doesn't fast-forward the local cache. Until these are fixed, upgrade by reinstalling:

```bash
/plugin uninstall fork-pizza
/plugin install github.com/chadallen/fork-pizza@<new-tag>
```

### Hook trust model

The SessionStart hook runs `scripts/inject-conventions.sh` automatically each session. This script is controlled by the plugin author. Pin to a tag (`@v0.1.0`) so you control when you take updates, and review the hook diff before upgrading.

## Contributing

Language skills (TS, Python, iOS today) are the most frequent addition request. Before adding a new language: consider whether a companion plugin (`fork-pizza-rust`, etc.) would be a better fit than expanding this one. The core workflow is language-agnostic; the skills are additive.

PRs that change command behavior (start-session, end-session, build-tasks, create-tasks) should include a note on what breaks for existing users.

## License

MIT — see [LICENSE](LICENSE).
