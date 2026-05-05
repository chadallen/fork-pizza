---
description: Turns recent conversation context (or a PRD file) into tasks and an epic. Prints a proposal inline for the user to review, then creates the tasks on approval.
argument-hint: "[path/to/PRD.md]"
---

# Create Tasks

Turns recent conversation context into tasks (and an epic if the work warrants it). The agent prints a structured proposal inline, the user reviews and requests edits, and the agent creates the tasks when they confirm.

Use this when:
- You've discussed a feature or set of changes in chat
- You have a PRD or spec file to ingest: `/fork-pizza:create-tasks PRD.md`
- The work is well-enough defined to break into tasks

---

## Usage

```
/fork-pizza:create-tasks              # use preceding conversation to create tasks
/fork-pizza:create-tasks PRD.md       # ingest a PRD or spec file
```

---

## Step 0: Bootstrap check

If `.beads/` does not exist, run `bd init` before proceeding — this initializes the task tracker for the project transparently.

```bash
[ -d ".beads" ] || bd init
```

---

## Step 1: Gather context

**If a file path was provided as an argument** (e.g., `PRD.md`):
- Read the file in full.
- Use it as the primary source for tasks, epics, and acceptance criteria.
- Summarize the scope to the user before proceeding: "I see N features/phases in this doc. I'll break them into tasks."

**If no file path was provided:**
- Use the preceding conversation as context.
- Decide if there is enough context to start creating tasks. If not, ask the user to describe the work. Ask follow-up questions until you have enough to write at least one task.

---

## Step 2: Decide structure

- **Single task:** Trivial change, one file or one clear action. Skip the epic, create one task.
- **Epic with tasks:** Multi-step work, crosses multiple files, has internal dependencies, or benefits from being tracked as a unit.

Default to an epic when there are 3 or more tasks.

---

## Step 3: Print the proposal

Print the proposal directly in your response using this format:

```markdown
# Task Proposal — [Feature or work summary]

## Epic (if applicable)

**Title:** [Short imperative title]
**Description:** [1-2 paragraphs on the goal and scope]

## Tasks

### 1. [Task title]

**Description:** [What needs to be done. Files to modify. Implementation approach if non-obvious.]
**Design:** [Architectural context the implementer needs — patterns to follow, constraints, relevant data models. Omit if the description covers it.]
**Acceptance:** [Verifiable outcome — tests pass, feature works as X]
**Depends on:** [None | task numbers]

### 2. [Task title]

**Description:** ...
**Design:** ...
**Acceptance:** ...
**Depends on:** 1
```

Keep task descriptions concise — 2-5 sentences. Don't write the full implementation in the description.

---

## Step 4: Wait for approval

After printing the proposal, tell the user:

> Review the proposal above. Edit requests welcome — "drop task 2", "add a caching task", "merge 3 and 4", "reorder". Reply "go" when ready and I'll create the tasks.

Wait for the user. Don't create any tasks yet.

**React to free-text edit requests inline** — if the user says "drop task 2, add a caching layer task," apply those changes and re-print the revised proposal so the user sees exactly what will be created.

---

## Step 5: Create the tasks

When the user confirms, create from the approved proposal:

### If there's an epic

```bash
bd create "<Epic Title>" -t epic \
  --description="<epic description from proposal>" \
  --json
```

Capture the epic ID.

### Create each task

```bash
bd create "<Task Title>" -t task -p <priority> \
  --parent <epic-id> \
  --description="<task description>" \
  --design="<design field from proposal, if present>" \
  --acceptance="<acceptance criteria>" \
  --json
```

Omit `--parent` if there's no epic.

**Priority:** Assign priority (1 = highest) based on your understanding of the project — importance, urgency, and how critical the task is to unblocking others. The user can adjust during the approval step.

For descriptions with backticks or special characters, write to a temp file and use `--description="$(cat /tmp/task-N.md)"`.

### Add dependencies

```bash
bd dep add <dependent-task-id> <dependency-task-id>
```

Argument order: dependent first, then what it depends on.

---

## Step 6: Add more tasks if needed

Ask the user if they want to add another task. If yes, repeat Steps 3-5. For additional tasks that belong to an existing epic, just create them with `--parent <epic-id>`.

---

## Step 7: Commit

```bash
git add .beads/
git commit -m "feat: create [epic/tasks] for <work summary>"
bd dolt push
```

---

## Step 8: Summary

Print:
- Epic ID and title (if created)
- Task count and IDs
- Dependency summary (e.g., "task 2 depends on task 1; task 3 depends on tasks 1 and 2")
- Next step — tell the user explicitly:
  - To build autonomously: run `/fork-pizza:build-tasks <epic-id> --auto`
  - To work tasks manually: you're already in a session — just start working the first ready task.

Do NOT offer to start building or begin implementation. Your job ends here.

---

## Key principles

- **Conversation is the source.** Don't invent tasks that weren't mentioned.
- **Derive acceptance criteria from the source.** Prefer observable behavior ("tapping X shows Y") over implementation details ("function Z returns true").
- **Re-print after edits.** If the user requests changes, show the revised proposal so they see exactly what will be created.
- **Default to smaller tasks.** Tasks should be 30-90 minute chunks of work.
- **Chain sequential tasks.** A flat list where every task has "Depends on: None" means everything becomes ready at once. Set explicit dependencies for naturally sequential work.
- **Use `--json`.** All bd commands use `--json` for reliable parsing.
