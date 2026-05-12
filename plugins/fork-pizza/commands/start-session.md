---
description: Orients the agent at the start of a coding session. Reads the Session Log and task state, flags missing ADRs, surfaces ready tasks, and proposes a plan for user approval. Also trampolines to the right next step if Beads isn't set up yet.
---

# Start Session

Run this procedure exactly. Do NOT write any code or make any changes until the user explicitly approves the plan.

If Beads' own SessionStart hook is configured (via `bd setup claude`), task context is already injected by `bd prime`. Build on that context — don't duplicate it.

## Step 0: Trampoline — check prerequisites

### Check for bd

```bash
command -v bd >/dev/null 2>&1 && echo "BD_FOUND" || echo "BD_MISSING"
```

If `BD_MISSING`:
- Print: "Beads (bd) is not installed. Install it first:"
  - macOS: `brew install beads`
  - Other platforms: https://github.com/steveyegge/beads
- Print: "After installing, re-run `/fork-pizza:start-session`."
- Stop here.

### Check for .beads/

```bash
[ -d ".beads" ] && echo "BEADS_DIR_EXISTS" || echo "BEADS_DIR_MISSING"
```

If `BEADS_DIR_MISSING`:
- Run `bd init` to initialize the task tracker for this project.
- If `bd init` fails (e.g., bd is not installed), print: "Beads could not be initialized. Make sure `bd` is installed and re-run `/fork-pizza:start-session`."
- Stop here only if init fails. Otherwise continue.

## Step 1: Check project state

Run `git status` and `git log --oneline -5`.

- If the working tree is dirty, stop and tell the user. Don't proceed until they decide what to do with the uncommitted work.
- Note the current branch.
- The most recent commit message often summarizes what happened last session.

## Step 2: Read the Session Log and create this session's issue

Each session gets its own Beads issue tagged `session-log`. Find the most recent closed one to read the last session recap, then create a new issue for this session.

### 2a: Find the last session recap

```bash
bd list --label session-log --status=closed --json
```

Parse the JSON result. Sort by `closed_at` descending and take the first entry. If the CLI doesn't sort, sort in the script.

**If no closed session-log issues exist** (first run in this project):
- Also check for an open session-log issue (`bd list --label session-log --status=open --json`). If one exists, this is a resumed first session — skip the PRD check and proceed to Step 3 (the session issue already exists).
- Otherwise, this is the first session. Create the session issue now (Step 2b below), then check for a PRD:
  ```bash
  [ -f "PRD.md" ] && echo "PRD_EXISTS" || echo "PRD_MISSING"
  ```
- **If `PRD_MISSING`:**
  - Print: "This is your first session and no PRD.md was found. Create a PRD.md in the project root describing what you want to build, then re-run `/fork-pizza:start-session`."
  - Stop here.
- **If `PRD_EXISTS`:**
  - Read PRD.md and print: "First session detected. I found a PRD — here's a proposed set of tasks based on it:" followed by a bulleted list of suggested tasks (title + one-line description each).
  - Print: "Run `/fork-pizza:create-tasks` to turn these into tracked tasks, or tell me how you'd like to adjust them."
  - Stop here.

**If closed session-log issues exist:**
- Run `bd show <most-recent-id> --json` and read the `notes` field.
- This is the last session recap.
- If the notes reference an active epic ID, note it for Step 5.

### 2b: Create this session's issue

```bash
bd create "Session — $(date +%Y-%m-%d)" -t task --label session-log \
  --description="Session log entry. Managed by /fork-pizza:start-session and /fork-pizza:end-session." \
  --json
```

Save the returned issue ID — `/fork-pizza:end-session` will write to it and close it.

## Step 3: Scan for missing ADRs

If `docs/adr/` exists, review the most recent Session Log entry. If it mentions an architectural decision that doesn't have a corresponding ADR, note it. Don't create it now — surface it in the session plan (Step 6) so the user can decide.

## Step 4: Project health check

Check whether the project has a test suite and linter configured. These are not blockers, but their absence weakens code review and increases the chance of regressions shipping undetected.

**Detect the stack** from file extensions, `package.json`, `pyproject.toml`, `Makefile`, `*.xcodeproj`, etc.

**Check for a test runner:**

| Stack | Look for | Recommended |
|-------|----------|-------------|
| TypeScript/JS | `vitest` or `jest` in devDependencies, or a `test` script in package.json | `vitest` (ESM-native, fast) |
| Python | `pytest` in `pyproject.toml` or `requirements*.txt`, or a `tests/` dir | `pytest` |
| Swift/iOS | `*Tests.swift` files in an XCTest target | XCTest (built-in) |
| Go | `*_test.go` files | `go test` (built-in) |

**Check for a linter:**

| Stack | Look for | Recommended |
|-------|----------|-------------|
| TypeScript/JS | `eslint.config.*`, `.eslintrc.*`, or `eslint` in devDependencies | `eslint` with flat config |
| Python | `ruff.toml`, `[tool.ruff]` in pyproject.toml, or `ruff` in dependencies | `ruff` |
| Swift/iOS | `.swiftlint.yml` or `swiftlint` in build phases | `swiftlint` |

**Check for type checking** (if applicable):

| Stack | Look for | Recommended |
|-------|----------|-------------|
| TypeScript | `tsc --noEmit` in a script, or `tsconfig.json` | `tsc --noEmit` |
| Python | `mypy` or `pyright` in dependencies | `mypy` with strict mode |

Record what's present and what's missing — surface it in Step 6.

## Step 5: Check task state

If Beads' hook already ran `bd prime`, you have most of this. Otherwise run:

- `bd ready --json` — next ready tasks
- `bd blocked --json` — blocked tasks
- If the Session Log references an active epic, run `bd list --parent <epic-id> --json` to see all tasks and their status

Also run `bd list --assignee="$(git config user.name)" --status=open --json` to find tasks assigned to the current user. These are human-owned — don't claim or work them without being asked.

**Context check:** Review the ready tasks' `description` and `design` fields. If they provide enough context, stop here. If tasks reference product requirements that aren't clear from the fields alone, read the relevant section of PRD.md. Read PRD.md in full only as a last resort.

## Step 6: Present the session plan

Print for the user:

1. **Last session recap** — 2-3 sentences from the most recent Session Log entry (or "First session — no history yet.").
2. **Active epic status** — If the Session Log references an active epic: count of open/in_progress/closed tasks. Example: "`project-12` (Phase 3): 2 closed, 1 in progress, 4 open."
3. **Next ready task(s)** — Top 1-3 tasks from `bd ready`, each with ID and title.
4. **Your tasks** — Any open tasks assigned to the current user. List each with ID and title. These are human-owned — don't claim or work them without being asked.
5. **Proposed focus** — What you recommend working on this session. Default to the highest-priority ready task. If the remaining tasks in the active epic are well-specified, mention that `/fork-pizza:build-tasks <epic-id>` could run them autonomously.
6. **Project health** — If Step 4 found missing test suite, linter, or type checker, list them here with the recommended tool for the detected stack. Offer to help set them up before starting new work: "Would you like me to add [vitest/eslint/etc.] before we start? It takes a few minutes and strengthens future code reviews."
7. **CLAUDE.md drift** — If the last Session Log entry contains a `**CLAUDE.md drift:**` note (deferred from a previous end-session), surface it here. Offer to fix it before starting new work.
8. **Missing ADRs** — If Step 3 found any undocumented architectural decisions from recent sessions, list them here. Offer to create them before starting new work.
9. **Blockers or questions** — Anything from `bd blocked`, or anything ambiguous where you want clarification before starting.
10. **Estimated scope** — Rough sense of how much fits in this session.

## Step 7: Wait

Do NOT proceed until the user approves the plan, modifies it, or gives a different direction. Do not write code until you have explicit approval.

Once approved:

- Claim the task: `bd update <task-id> --claim --json`
- Begin work.
- Commit frequently with the issue ID in parens: `git commit -m "Add X (<task-id>)"`. This enables orphan detection at session end.
