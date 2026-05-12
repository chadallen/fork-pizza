---
description: Closes completed tasks, checks for ADR-worthy decisions, writes a Session Log entry, commits all changes, and pushes to remote. Session is not complete until git push and bd dolt push both succeed.
---

# End Session

Run this procedure exactly. Do NOT write any project code during this procedure. The session is NOT done until the final `git push` and `bd dolt push` succeed.

**Mode reset:** The `--auto` and `--checkpoints` flags are scoped to `/fork-pizza:build-tasks` only. They do NOT carry over to this procedure. Even if the previous skill ran in auto mode, every step here that asks for user input MUST wait for the user's response. Do not skip confirmations or make changes without approval.

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

## Step 4: CLAUDE.md drift check

Check whether CLAUDE.md references things that no longer exist. This catches documentation rot before it misleads a future session.

### 4.1 Scan for stale references

If CLAUDE.md exists, scan it for:

- **File paths** — any path that looks like `src/...`, `docs/...`, `*.ts`, `*.py`, etc. Check each against the filesystem. Flag any that don't exist.
- **Scripts/commands** — references to `pnpm <script>`, `npm run <script>`, `make <target>`, etc. Check against `package.json` scripts (or Makefile, pyproject.toml). Flag any that are missing.
- **Line count** — if CLAUDE.md exceeds 120 lines, note it.

Skip paths inside code fences that are clearly examples or templates (e.g., `output/*.pdf` globs, env var examples).

### 4.2 Check for missing additions

Review what changed this session. Flag if any of these happened but CLAUDE.md doesn't reflect them:

- New build/test/lint command added
- New hard constraint or convention established
- File or directory referenced by CLAUDE.md was renamed or moved

### 4.3 Report and offer

**If no drift found:** print "CLAUDE.md is current." and move on.

**If drift found:** print the specific items, then ask:

> "CLAUDE.md has N stale reference(s). Want me to update it before we close out?"

- **If yes:** make the edits, keep under 120 lines, commit with the other session-end work.
- **If no:** note the drift in the Session Log entry (Step 5) so start-session can re-surface it: `**CLAUDE.md drift:** <brief list of stale items>`.

## Step 5: Write Session Log entry and close the session issue

Find this session's open session-log issue:

```bash
bd list --label session-log --status=open --json
```

There should be exactly one (created by `/fork-pizza:start-session`). If none exists, create one now:

```bash
bd create "Session — $(date +%Y-%m-%d)" -t task --label session-log \
  --description="Session log entry. Managed by /fork-pizza:start-session and /fork-pizza:end-session." \
  --json
```

Write the session summary directly into the issue's notes field — no prepending, no concatenation:

```bash
SESSION_LOG_ID=<id from query above>

NOTES="### $(date +%Y-%m-%d)
<features shipped, tasks closed (with IDs), key decisions made>
**Next session:** <1-2 recommended task IDs and titles>"

bd update "$SESSION_LOG_ID" --notes="$NOTES" --json
```

Then close the issue:

```bash
bd close "$SESSION_LOG_ID" --reason="Session complete" --json
```

Keep entries specific. End each with a "**Next session:**" line naming 1-2 recommended tasks by ID.

## Step 6: Check for ADR-worthy decisions

Review what happened this session. Did any decisions meet the ADR criteria?

- A choice between multiple viable options where alternatives were actually considered.
- Affects how future code will be structured.
- Non-trivial to reverse.
- The "why" isn't obvious from the code.

If yes, invoke `/fork-pizza:adr` for each one — propose the title and summary, write on approval. If nothing qualifies, move on.

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
