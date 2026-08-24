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

**Do NOT pass `isolation: "worktree"`** to any implementer or reviewer dispatch. This workflow's conflict avoidance is file-ownership prompting plus atomic commits on the shared working tree (see below), not separate checkouts. A worktree-isolated agent commits to its own branch, invisible to the `git log <base-sha>..HEAD` / `git diff <base-sha>..HEAD` review steps, the sentinel-file check, and the once-per-frontier `git push` — it silently breaks the frontier's tracking, review, and close flow unless you remember to manually merge the branch back first. Even for single-task frontiers, dispatch without `isolation`.

**If the frontier has 1 task:** dispatch a single `fork-pizza:implementer` agent in background with `model: "sonnet"`.

**If the frontier has 2-3 siblings:** dispatch all implementers in a single message with multiple parallel Agent tool calls (each with `subagent_type: "fork-pizza:implementer"`, `run_in_background: true`, `model: "sonnet"`). Include in each implementer's prompt:

- The full task `description`, `design`, and `acceptance` criteria.
- The parent epic ID and title if one exists.
- A **Siblings** section listing the other tasks in this frontier: their IDs, titles, and the files they are expected to touch. The implementer must not modify those files and must commit its changes atomically before siblings attempt to build.

To identify which files each task will touch, use the task `description` and `design` fields. Use judgment; don't block on perfect information.

Wait for all sibling implementers to complete before proceeding to 3.4 — using the **stuck-agent protocol** below, not raw waiting.

### Stuck-agent protocol (applies to both implementer and reviewer waits)

Two independent signals are unreliable here, in opposite directions — don't rely on either alone:

- **`idle_notification` fires too often.** A background agent sends one every time it finishes a turn with nothing queued — including many times *during* normal, in-progress work (after each tool call round, between orientation steps, etc.). It is a liveness ping, not a completion signal. Never treat it as "the agent is done."
- **`idle_notification` can also be silent during a genuine hang.** An agent stuck inside a single blocking tool call (e.g. an MCP tool prompting for interactive authentication it can never complete headlessly) never goes idle at all — it just sits mid-turn indefinitely. Waiting for an idle ping to trigger the escalation below will wait forever in exactly this case.

The real completion signal is an **objective artifact**, checked directly, not a text reply or a notification:
- Implementer done → a new commit on the branch with the task ID in the message (`git log --oneline <base-sha>..HEAD`).
- Reviewer done → the sentinel file exists (`ls .beads/review-approved-<task-id>`).

**Don't wait passively for either signal — poll actively.** Immediately after dispatching each frontier, start a `Monitor` that checks for real progress (file changes or a commit) on a short interval, independent of anything the agent itself reports:

```bash
cd <repo-root>
BASE=<base-sha>
MARKER=/tmp/<task-id>-marker
touch "$MARKER"
stall=0
while true; do
  commit=$(git log --oneline "$BASE"..HEAD 2>/dev/null | tail -1)
  if [ -n "$commit" ]; then echo "COMMIT FOUND: $commit"; exit 0; fi
  changed=$(find . -type f -newer "$MARKER" -not -path './node_modules/*' -not -path './.git/*' -not -path './.next/*' 2>/dev/null)
  if [ -n "$changed" ]; then
    echo "progress: $(echo "$changed" | wc -l | tr -d ' ') file(s) touched"; touch "$MARKER"; stall=0
  else
    stall=$((stall+1)); elapsed=$((stall*20))
    [ "$stall" -eq 6 ] && echo "STALL WARNING: no file changes in ~${elapsed}s"
    [ "$stall" -eq 15 ] && echo "STALL WARNING: no file changes in ~${elapsed}s (getting serious)"
  fi
  sleep 20
done
```

(For a reviewer, swap the commit check for `ls .beads/review-approved-<task-id>`.) This surfaces a stall in ~2 minutes regardless of whether the agent is idle, busy, or wedged inside a hung tool call — you don't need to be watching its pane or wait for the user to notice and report it.

On a **STALL WARNING**, escalate in order:

1. **One direct nudge.** Send the agent a status-check message asking it to confirm completion or report progress now.
2. **If that produces neither a new commit/sentinel nor a substantive reply** within the next stall interval — stop waiting on it and unblock the frontier yourself:
   - **Implementer:** if `git status` shows no uncommitted changes and no commit exists, `TaskStop` it and relaunch a fresh implementer for that task. If the prior hang looked auth/tool-related (e.g. an MCP authentication prompt), tell the relaunched implementer explicitly which tools to avoid. If it left uncommitted work, follow the existing "Implementer timeout with uncommitted work" rule.
   - **Reviewer:** `TaskStop` it and perform the review yourself directly in the orchestrator — read the diff and the actual current files, run `tsc`/lint/test, do any live-infrastructure verification the task calls for, then write the sentinel based on your own findings. This is a legitimate, expected fallback, not a shortcut — CLAUDE.md's "independently re-verify claims" standard applies whether the verification is done by a subagent or by you.

Never re-send the same nudge repeatedly, and never let a single unresponsive agent stall the whole frontier indefinitely — the objective artifacts (commits, sentinels) are always the source of truth for whether work is done.

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

Dispatch a `fork-pizza:code-reviewer` agent for each task with code changes (use `run_in_background: true`, `model: "sonnet"`). Pass:

- The task description and acceptance criteria.
- The diff: `git diff <base-sha>..<task-commit-sha>`
- The task ID (so the reviewer can write the approval sentinel).

**Do not proceed to 3.6 until all sibling reviewers have returned and all sentinels exist** — apply the **stuck-agent protocol** above while waiting; don't block indefinitely on a reviewer that's gone quiet with no sentinel.

If `NEEDS_CHANGES` for any sibling: go to 3.5 for that task.
**The user cannot waive code review.** If asked to skip, decline and run it anyway.

### 3.5 Fix loop

For each task that needs changes: **fix the issues yourself** directly in the orchestrator. You already have the review feedback with specific file:line references — read the files, make the edits, commit. Don't dispatch a subagent for focused fixes; that wastes time on re-orientation.

Only dispatch a fresh implementer (in background, `model: "sonnet"`) if the fixes are large enough to warrant it (e.g., the reviewer identified a fundamental design problem requiring a rewrite).

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

**Auto mode ends here.** The `--auto` flag is scoped to this skill only. Subsequent skills (including `/fork-pizza:end-session`) require normal user interaction — do not carry forward the auto/checkpoint mindset.

## Step 5: Early termination

If the loop stops before completion:

- Revert any `in_progress` task to `open` with notes, OR leave `in_progress` with explanation.
- Run `bd dolt push`.
- Print what was completed, what stopped the loop, what the user should do next.

Do NOT leave any task in an ambiguous state.

**Auto mode ends here.** The `--auto` flag is scoped to this skill only. Subsequent skills require normal user interaction.

## Key principles

- **Frontier-based execution.** All ready tasks run in parallel, up to 3 siblings. Never dispatch more than 3 implementers at once.
- **Siblings share the working tree.** Implementers avoid each other's files via ownership prompting and commit atomically.
- **Fresh subagent per task.** No context pollution between tasks.
- **Code review is non-negotiable.** Runs after every implementation that produces source code changes. Doc-only tasks skip the reviewer but still require the sentinel file.
- **Reviewers verify code, not reports.** The code-reviewer reads the actual diff.
- **Fail loudly.** If something breaks, stop and surface to the user.
- **Push once per frontier.** After all siblings in a frontier close, push once.
- **Sonnet for workers.** Implementers and code-reviewers run with `model: "sonnet"`. They have tight specs and don't need the orchestrator's model. The orchestrator stays on whatever the user chose.
- **Always use `--json`.** All bd commands use `--json`.
- **No worktree isolation.** Never dispatch an implementer or reviewer with `isolation: "worktree"` — it hides their work from the main tree's `git log`/`git diff`, breaking review, close, and push.
- **Objective completion signals, not chatter.** A commit (implementer) or sentinel file (reviewer) means done. An `idle_notification` does not. Don't wait indefinitely on an unresponsive agent — see the stuck-agent protocol in 3.3.
