---
description: Creates and manages Architecture Decision Records in docs/adr/. Proposes a title and one-sentence summary before writing anything. Invoked automatically by end-session when architectural decisions are detected.
---

# ADR — Architecture Decision Records

Write and manage ADRs in `docs/adr/`. ADRs capture the *why* behind architectural choices so future agents and humans don't have to reverse-engineer rationale from code.

This command is usually invoked by other commands when they detect an architectural decision. It can also be invoked directly.

## When to create an ADR

Create one when ALL of these are true:

- A choice was made between multiple viable options (alternatives were actually considered).
- The decision affects how future code will be structured.
- Reversing it later would require non-trivial work.
- The "why" wouldn't be obvious from reading the code alone.

Do NOT create one for:

- Standard practices for the language or framework.
- Bug fixes or one-off implementation choices.
- Decisions where there was no real alternative.
- Style, formatting, or naming conventions (those belong in CLAUDE.md).

## Step 1: Propose before writing

Before writing any ADR, show the user:

- **Proposed title** — short, imperative: "Use Supabase over SwiftData", "Choose JWT over session cookies"
- **One-sentence summary** — what was decided and why, in plain language.

Wait for a quick confirm. If the user says it's not worth recording, drop it. A rejected proposal costs one message. A rejected full ADR costs real tokens.

## Step 2: Write the ADR

ADRs live in `docs/adr/`. File naming: `NNNN-<slug>.md` where NNNN is zero-padded and sequential. Check existing files to determine the next number.

If `docs/adr/` doesn't exist, create it.

Template:

```markdown
# ADR-NNNN: <Title>

**Date:** YYYY-MM-DD
**Status:** Accepted

## Context

What problem are we solving? What constraints matter? Keep it to 2-4 sentences.

## Decision

What we chose. One or two sentences.

## Alternatives Considered

What else was on the table and why it was rejected. A few sentences per alternative. Focus on the ones that were genuinely viable.

## Consequences

What this gets us and what it costs us. Include tradeoffs and things this makes harder later. Be honest about downsides.
```

Keep the whole thing short. A good ADR is half a page, not two pages.

## Step 3: Commit

```bash
git add docs/adr/NNNN-<slug>.md
git commit -m "adr: NNNN — <title>"
```

Don't bundle ADRs with code commits. They're their own logical change.

## Superseding an ADR

When a decision changes, don't edit the old ADR. Write a new one that references it:

- In the new ADR's Context section: "This supersedes ADR-NNNN (<title>)."
- Update the old ADR's Status line: change `Accepted` to `Superseded by ADR-MMMM`.

## Batch creation

When called by a migration or scan, you may need to create multiple ADRs for existing decisions:

1. Scan existing docs (CLAUDE.md, PRD.md, README, etc.) for past decisions that meet the criteria.
2. Propose all of them as a batch — show the list of titles.
3. User approves/rejects/modifies the list.
4. Write the approved ones. Use the date the decision was originally made if known; otherwise use today.

## Key principles

- **Propose first, write second.** Never write a full ADR without a quick confirm from the user.
- **Short beats thorough.** Half a page. If someone needs more detail, they can read the code.
- **Append-only.** Don't edit old ADRs. Supersede them.
- **The agent decides when.** Other commands check for ADR-worthy decisions and invoke this one. The user doesn't have to remember.
