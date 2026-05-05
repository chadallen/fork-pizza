# Plugin Developer Notes

## Local development

To develop the plugin locally, add the repo as a local marketplace:

```
/plugin marketplace add /path/to/fork-pizza
/plugin install fork-pizza@fork-pizza
```

If local install isn't supported, copy the plugin to the global cache directly and restart Claude Code.

## Upgrade path for users

Because `/plugin update` has known issues (see README), document upgrades as:

```
/plugin uninstall fork-pizza
/plugin marketplace add chadallen/fork-pizza
/plugin install fork-pizza@fork-pizza
```

## Version contract

**Patch bump (0.1.x → 0.1.y):** additive only — new commands, new skills, new docs. Existing commands unchanged.

**Minor bump (0.1.x → 0.2.0):** behavioral changes to existing commands, but backward-compatible for most users. Call out what changes in the release notes.

**Major bump (0.x.y → 1.0.0):** breaking changes — renamed commands, changed hook contracts, dropped skills. Provide a migration guide.

## Adding a language skill

1. Create `skills/<language>/SKILL.md` following the format of the existing skills.
2. The skill is auto-invoked by implementer and code-reviewer when they detect files of that type.
3. Update the skills table in README.md.
4. No changes to the agents or commands needed.

## Hook contract

The SessionStart hook runs `scripts/inject-conventions.sh`. The script:

- Checks for `bd` on PATH and exits 0 with a soft warning if missing.
- Cats `${CLAUDE_PLUGIN_ROOT}/docs/conventions.md` to stdout (injected into context).
- Always exits 0 — a non-zero exit would block session startup.

If you change the convention rules, update `docs/conventions.md`. The hook picks them up automatically on next session.

## The session-log tag

`session-log` is a reserved Beads tag. The workflow assumes exactly one issue per project has this tag. Don't use it for other purposes. The tag was chosen over a title prefix because it's queryable (`bd list --tag=session-log --json`) and survives renames.

## Namespace

All user-facing commands get the `fork-pizza:` prefix automatically. References in docs and agent prompts should use the full prefixed form: `/fork-pizza:start-session`, not `/start-session`.

## Testing the plugin

Smoke test checklist:

1. Install into a fresh project directory with no `.beads/`.
2. Run `/fork-pizza:start-session` → expect "install bd" (if bd missing) or `.beads/` gets initialized.
3. With bd installed, run `/fork-pizza:start-session` → expect "Create a PRD.md" (if no PRD) or a proposed task list (if PRD exists).
4. Run `/fork-pizza:create-tasks` and describe a small feature → proposal printed inline, tasks created on approval.
5. Run `/fork-pizza:start-session` → expect ready task summary.
6. Run `/fork-pizza:build-tasks --auto` → implementer runs, reviewer runs, task closes, push succeeds.
7. Run `/fork-pizza:end-session` → Session Log entry written, push succeeds.
