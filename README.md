# fork-pizza

An autonomous coding workflow for Claude Code. Sub-agents implement tasks in parallel, code reviewers check the work, and you stay in the loop at the level you want. Atomic tasks and state preservation mean you can clear the context window frequently without losing your place (but the liberal use of sub-agents running in their own context means you won't need to clear as frequently anyway). 

## What it does

1. **Task tracking** — [Beads](https://github.com/steveyegge/beads) keeps tasks small and well-defined. Epics group related work. Dependencies are tracked.
2. **Session orientation** — `/fork-pizza:start-session` reads a Session Log and current tasks from Beads, surfaces what's next, and waits for your go-ahead.
3. **Autonomous build loop** — `/fork-pizza:build-tasks` runs implementer agents in parallel (up to 3 per frontier), followed by 8-dimensional code review. You approve the plan and walk away.
4. **ADRs** — Architecture Decision Records capture why you made the choices you did, so future agents don't re-litigate them.

## Requirements

- Claude Code (Pro or Max subscription)
- **[Beads](https://github.com/steveyegge/beads)** — task tracker for AI agents

```bash
brew install beads    # macOS
```

For other platforms, see the [Beads installation docs](https://github.com/steveyegge/beads).

## Install

```
/plugin marketplace add chadallen/fork-pizza
/plugin install fork-pizza@fork-pizza
```

> **SSH users:** If you get a "Permission denied (publickey)" error, run `gh auth login` to set up HTTPS credentials, or add `export GH_TOKEN=<your-pat>` to your shell config.


## Usage

You need to write a PRD.md and put it in the root of your project's working folder. You can use whatever format you want (obviously you should collaborate with Claude on this).

Always start with `/fork-pizza:start-session`. Part of its job is to coach you on how to use the workflow, so you don't need to memorize this doc. It's going to look for your PRD the first time you run it, and will complain if you haven't made one yet. 

### Commands

| Command | When |
|---|---|
| `/fork-pizza:start-session` | Beginning of every session. Reads Session Log and task state, proposes a plan based on the current state of the project. You approve or modify the plan in conversation. Sometimes this plan will involve creating new tasks, sometimes the plan is just to build tasks that you didn't complete in previous sessions. |
| `/fork-pizza:create-tasks` | If you have new tasks to create, you can invoke this skill at any time.  |
| `/fork-pizza:build-tasks` | Autonomous build loop. Runs implementers, reviewers, and closures. |
| `/fork-pizza:end-session` | End of every session. Writes Session Log entry, commits, pushes. |

You can also use these conversationally: `use create-tasks to create some new tasks`.

### Keyboard tip

All commands autocomplete — type `/fork-pizza:` and press Tab to see the picker, or type `/start-session` or any command name and press Tab to see the picker.

### build-tasks flags

You can use these explicit flags if you want, or just say something like `build all of the tasks in the plan using --auto mode` and Claude will invoke the skill.

```
/fork-pizza:build-tasks                    # next ready task (asks: run to completion or checkpoints?)
/fork-pizza:build-tasks --auto             # run until complete, no prompts
/fork-pizza:build-tasks --checkpoints      # stop for review after each task
/fork-pizza:build-tasks <epic-id>          # all tasks in an epic
/fork-pizza:build-tasks <task-id>          # one specific task
```

## Skills (auto-invoked, not user-facing)

The `implementer` and `code-reviewer` agents automatically load a language skill at the start of each task based on the files being touched. You don't invoke these directly.

| Skill | Function |
|---|---|
| `typescript-developer` | Write TypeScript / JavaScript |
| `python-developer` | Write Python |
| `ios-developer` | Write Swift / iOS |

### Agent-only commands

| Command | Function |
|---|---|
| `/fork-pizza:adr` | Record an architectural decision. Invoked by `end-session` — not intended for direct use. |

## Session Log

One Beads issue per project tagged `session-log` holds the running session history. `/fork-pizza:start-session` creates it on first run. `/fork-pizza:end-session` prepends a dated entry and keeps the last 5. The result shows up in `bd show` — nothing to maintain manually.


### Hook trust model

The SessionStart hook runs `scripts/inject-conventions.sh` automatically each session. This script is controlled by the plugin author. Pin to a tag (`@v0.1.0`) so you control when you take updates, and review the hook diff before upgrading.

## License

MIT — see [LICENSE](LICENSE).
