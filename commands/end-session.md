---
description: Closes completed tasks, checks for ADR-worthy decisions, writes a Session Log entry, commits all changes, and pushes to remote. Session is not complete until git push and bd dolt push both succeed.
---

# End Session

Run this procedure exactly. Do NOT write any project code during this procedure. The session is NOT done until the final `git push` and `bd dolt push` succeed.

## Step 0: Check for unprocessed proposal

Before doing anything else, check if `.beads/proposal.md` exists:

```bash
ls .beads/proposal.md 2>/dev/null && echo "PROPOSAL_EXISTS" || echo "NO_PROPOSAL"
```

**If `PROPOSAL_EXISTS`** — tasks were planned but never created. Creating them now preserves that work.

Read `.beads/proposal.md` and create the tasks exactly as `/claude-workflow:create-tasks` step 4 would:

1. If the proposal includes an epic, create it first: `bd create "<title>" -t epic -p 1 --description="..." --json`
2. Create each task: `bd create "<title>" -t task -p 1 --parent <epic-id> --description="..." --design="..." --acceptance="..." --json`
3. Add dependencies: `bd dep add <dependent> <dependency>`
4. Delete the proposal: `rm .beads/proposal.md`
5. Tell the user: "Found unprocessed proposal — created X tasks from it before ending session."

Do NOT silently delete `proposal.md` without creating the tasks. If anything is ambiguous, stop and ask rather than guessing.

**If `NO_PROPOSAL`** — continue to Step 1.

---

## Step 1: Close completed tasks

For each task completed this session:

- Verify the work is actually done (tests pass, acceptance criteria met).
- Close: `bd close <task-id> --reason="<brief summary>" --json`

For tasks started but not finished:

- Update with progress notes: `bd update <task-id> --notes="<what's done, what's next>" --json`
- Leave as `in_progress` (resume next session) or revert to `open` (let someone else take it).

Never leave a task `in_progress` just because the session ended without deciding.

## Step 2: Check for orphans

`bd doctor` only works in server mode. Skip it in embedded mode (the default):

```bash
if [ -d ".beads/embeddeddolt" ]; then
  echo "Embedded mode — skipping bd doctor."
else
  bd doctor
fi
```

## Step 3: Commit session work

- Stage and commit uncommitted work. Include issue IDs: `"<message> (<task-id>)"`.
- If `scratch.md` exists (any casing), ensure it's in `.gitignore`. Do NOT read it.
- Don't push yet — one push at the end.

## Step 4: Update CLAUDE.md (if needed)

Only update if this session changed project-level rules, conventions, tooling, or dependencies. If nothing changed, skip entirely.

Justifies an edit: new build/test command, new hard rule, removed/renamed something it references. Does NOT belong: progress tracking, session history, architecture decisions (→ ADR).

Keep under 80 lines.

## Step 5: Write Session Log entry

Find the session-log issue:

```bash
bd list --tag=session-log --json
```

If none exists, create it first (see `/claude-workflow:start-session` Step 2 for the create command).

Write a new dated entry and prepend it to the issue's notes, trimming to the 5 most recent entries:

```bash
SESSION_LOG_ID=<id from query above>
EXISTING=$(bd show "$SESSION_LOG_ID" --json | jq -r '.notes // ""')

# Build the new entry — fill in actual content below
NEW_ENTRY="### $(date +%Y-%m-%d)
<features shipped, tasks closed (with IDs), key decisions made>
**Next session:** <1-2 recommended task IDs and titles>"

# Prepend new entry and keep only last 5 (entries start with ###)
COMBINED=$(printf '%s\n\n%s' "$NEW_ENTRY" "$EXISTING")
TRIMMED=$(echo "$COMBINED" | awk '/^### /{count++} count<=5{print}')

bd update "$SESSION_LOG_ID" --notes="$TRIMMED" --json
```

Keep entries specific. End each with a "**Next session:**" line naming 1-2 recommended tasks by ID.

## Step 6: Check for ADR-worthy decisions

Review what happened this session. Did any decisions meet the ADR criteria?

- A choice between multiple viable options where alternatives were actually considered.
- Affects how future code will be structured.
- Non-trivial to reverse.
- The "why" isn't obvious from the code.

If yes, invoke `/claude-workflow:adr` for each one — propose the title and summary, write on approval. If nothing qualifies, move on.

## Step 7: Commit docs

Commit: `docs: end-of-session update — <brief summary>`. Include any task IDs closed this session.

## Step 8: Land the plane

**This step is non-negotiable. The session is not complete until both pushes succeed.**

1. `git pull --rebase` — pull any remote changes first.
2. `git push` — push everything.
3. `git status` — must show "up to date with origin/<branch>".
4. `bd dolt push` — push task data to remote.
5. If any step fails, resolve the issue and retry. Do not give up.

Do NOT end the session with unpushed work. Do NOT tell the user "ready to push when you are." Push it yourself.

## Step 9: Session summary

```bash
bd ready --json
```

Print for the user:

- What was accomplished (2-3 sentences).
- Tasks closed this session (with IDs).
- **Next session focus:** If 5 or fewer tasks are ready, recommend the top 1-2 by ID and title. If more than 5 are ready, flag it: "X tasks ready — consider whether dependencies are fully set up."
- Any items needing user attention (manual testing, decisions, external dependencies).
- Confirmation that everything is pushed and the working tree is clean.

Then prompt: **"Session complete. Run `/clear` to reset the context window before your next session."**
