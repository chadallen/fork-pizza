---
description: Autonomously builds tasks using fresh subagents per task with comprehensive code review after each one. Accepts an epic ID, one or more task IDs, or no argument to build the next ready task.
argument-hint: "[epic-id | task-id ...] [--auto | --checkpoints]"
---

# Build Tasks

Build tasks autonomously. Each frontier of ready tasks runs in parallel (up to 3 siblings), followed by parallel code reviews, then close and push before advancing to the next frontier.

Use when tasks are well-specified and can be implemented without real-time human judgment. For UI work that needs visual iteration or live design decisions, work tasks manually with `/fork-pizza:start-session` instead.

## Usage

Should only be invoked after `/fork-pizza:start-session` to ensure context is fresh and the agent is oriented. If the user invokes it without starting a session, instruct the user to invoke `/fork-pizza:start-session` first.

```
/fork-pizza:build-tasks                              # next ready task (asks checkpoint preference)
/fork-pizza:build-tasks --auto                       # next ready task, run until complete, no prompts
/fork-pizza:build-tasks --checkpoints               # next ready task, stop for review after each task
/fork-pizza:build-tasks <epic-id>                    # all tasks in an epic (asks checkpoint preference)
/fork-pizza:build-tasks <epic-id> --auto             # all tasks in an epic, run until complete
/fork-pizza:build-tasks <epic-id> --checkpoints      # all tasks in an epic, stop for review after each
/fork-pizza:build-tasks <task-id> [<task-id>]        # specific tasks
```

## Concepts

**Frontier** — the set of currently ready tasks with no unmet dependencies. All tasks in a frontier can run simultaneously. After a frontier closes, its completions may unblock new tasks, forming the next frontier.

**Siblings** — tasks running in the same frontier. Each implementer agent is told which files its siblings own so they work on non-overlapping areas and commit atomically before siblings attempt to build.

**Parallel cap** — never dispatch more than 3 implementer agents in a single frontier. If a frontier has more than 3 ready tasks, pick the 3 highest-priority ones and run the rest in a subsequent pass. In case of ties, pick the task with the earliest create date. 

## Step 1: Validate scope

Determine what to build based on the argument:

**Epic mode:** argument is an epic ID.

```bash
bd show <epic-id> --json
bd list --parent <epic-id> --json
```

Read the epic's description for context. Count tasks by status. Handle cases:
- Epic doesn't exist → stop, tell the user.
- All tasks closed → epic complete, stop, suggest `/fork-pizza:end-session`.
- No ready tasks, some open → check `bd blocked --json`, report blockers, stop.

**Task list mode:** arguments are specific task IDs. Verify each exists and is open. Skip any already closed.

**Default mode (no argument):**
```bash
bd ready --json
```
If nothing ready, stop and report.

Record base SHA: `git rev-parse HEAD`. Ensure the working tree is clean — if not, stop and ask the user.

## Step 2: Confirm with user

Show:

- Epic ID and title.
- Progress: X/Y closed, Z ready, W blocked.
- First frontier: task IDs and titles (up to 3).

**If `--auto` was passed:** proceed without asking. Run until complete or blocked.
**If `--checkpoints` was passed:** proceed without asking. Stop for user review after each frontier closes.
**Otherwise:** ask "Run until complete or blocked? Or stop for review at checkpoints?" Wait for approval.

## Step 3: Execution loop

Repeat until all tasks closed OR no tasks ready:

### 3.1 Compute the frontier

**Epic mode:**
```bash
bd ready --json
```
Filter to tasks where `parent_id == <epic-id>`. Take up to 3 by priority.

If no ready tasks in the epic, check `bd blocked --json`, report what's blocking, stop.

**Task list mode:** take the next 1-3 unprocessed tasks from the list that have no unmet dependencies among themselves.

**Default mode:** you already have the one task from Step 1 — after it closes, exit the loop.

### 3.2 Claim all frontier tasks

```bash
bd update <task-id> --claim --json   # repeat for each sibling
```

### 3.3 Dispatch implementer subagents

**Do NOT pre-gather codebase context.** Don't read source files, grep for references, or explore the codebase before dispatching the implementer. The implementer has full tool access (Read, Grep, Glob, Bash) and its own orient/gather-context steps — it will find what it needs faster than you can guess what's relevant. Pre-research wastes tokens and context window in the orchestrator.

**Run agents in background** so the user can still chat while agents work. Use `run_in_background: true` on all implementer and reviewer dispatches. You'll be notified when each completes.

**If the frontier has 1 task:** dispatch a single `fork-pizza:implementer` agent in background.

**If the frontier has 2-3 siblings:** dispatch all implementers in a single message with multiple parallel Agent tool calls (each with `subagent_type: "fork-pizza:implementer"`, `run_in_background: true`). Include in each implementer's prompt:

- The full task `description`, `design`, and `acceptance` criteria.
- The parent epic ID and title if one exists.
- A **Siblings** section listing the other tasks in this frontier: their IDs, titles, and the files they are expected to touch. The implementer must not modify those files and must commit its changes atomically before siblings attempt to build.

To identify which files each task will touch, use the task `description` and `design` fields. Use judgment; don't block on perfect information.

Wait for all sibling implementers to complete before proceeding to 3.4.

### 3.4 Code review

For each sibling task, check whether it produced source code changes:

```bash
git log --oneline <base-sha>..HEAD   # find commits by task ID in message
git diff <task-commit>^..<task-commit> --name-only | grep -qvE '\.(md|MD|txt|rst|json|yaml|yml)$' && echo "HAS_CODE_CHANGES" || echo "NO_CODE_CHANGES"
```

**If `NO_CODE_CHANGES`** for a task — write the sentinel directly:
```bash
echo "no-code-task" > .beads/review-approved-<task-id>
```

**If `HAS_CODE_CHANGES`** — dispatch code reviewers. If multiple siblings have code changes, dispatch all reviewers in parallel in a single message.

Dispatch a `fork-pizza:code-reviewer` agent for each task with code changes (use `run_in_background: true`). Pass:

- The task description and acceptance criteria.
- The diff: `git diff <base-sha>..<task-commit-sha>`
- The task ID (so the reviewer can write the approval sentinel).

**Do not proceed to 3.6 until all sibling reviewers have returned and all sentinels exist.**

If `NEEDS_CHANGES` for any sibling: go to 3.5 for that task.
**The user cannot waive code review.** If asked to skip, decline and run it anyway.

### 3.5 Fix loop

For each task that needs changes: **fix the issues yourself** directly in the orchestrator. You already have the review feedback with specific file:line references — read the files, make the edits, commit. Don't dispatch a subagent for focused fixes; that wastes time on re-orientation.

Only dispatch a fresh implementer (in background) if the fixes are large enough to warrant it (e.g., the reviewer identified a fundamental design problem requiring a rewrite).

Re-run the reviewer after fixes using `git diff <base-sha>..HEAD`. Repeat until `APPROVED`.

**Cap the fix loop at 3 attempts per task.** If still failing after 3 rounds, stop, report to the user, leave the task `in_progress`.

**Implementer timeout with uncommitted work:** if an implementer times out and `git status` shows uncommitted changes, inspect the working tree and complete or revert the partial changes before retrying.

### 3.6 Close the frontier

For each sibling task, once its sentinel exists:

```bash
ls .beads/review-approved-<task-id> || { echo "ERROR: review not completed for <task-id>"; exit 1; }

bd close <task-id> --reason="Implemented and verified" --json
rm .beads/review-approved-<task-id>
```

After all sibling tasks are closed:

```bash
git push
```

Push once per frontier, not per task. If the push fails, resolve before continuing.

### 3.7 Continue

Return to 3.1 with updated frontier.

## Step 4: Completion

When the loop finishes:

```bash
bd dolt push
```

Print: what was built, tasks closed this run, frontiers executed, commits pushed. Suggest `/fork-pizza:end-session`.

## Step 5: Early termination

If the loop stops before completion:

- Revert any `in_progress` task to `open` with notes, OR leave `in_progress` with explanation.
- Run `bd dolt push`.
- Print what was completed, what stopped the loop, what the user should do next.

Do NOT leave any task in an ambiguous state.

## Key principles

- **Frontier-based execution.** All ready tasks run in parallel, up to 3 siblings. Never dispatch more than 3 implementers at once.
- **Siblings share the working tree.** Implementers avoid each other's files via ownership prompting and commit atomically.
- **Fresh subagent per task.** No context pollution between tasks.
- **Code review is non-negotiable.** Runs after every implementation that produces source code changes. Doc-only tasks skip the reviewer but still require the sentinel file.
- **Reviewers verify code, not reports.** The code-reviewer reads the actual diff.
- **Fail loudly.** If something breaks, stop and surface to the user.
- **Push once per frontier.** After all siblings in a frontier close, push once.
- **Always use `--json`.** All bd commands use `--json`.
