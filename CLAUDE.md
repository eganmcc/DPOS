# DPOS — working agreement for Claude sessions

This file is loaded automatically by every Claude Code session — cloud, VS Code, and CLI.
It exists because sessions cannot see each other: **git is the only channel between surfaces.**
Two agents on two machines will otherwise reach confident, contradictory conclusions.

## Before you act

1. **Read `DEVLOG.md`.** It is the cross-machine handoff — current status, next steps, and the
   traps already solved. The SessionStart hook prints its date and a branch map at startup.
2. **Know which branch you are on, and how stale it is.** `main` is the trunk. If a feature branch
   is far ahead of it, the trunk is not the current truth — check the branch map.

## Reporting findings about the code

**Always state the branch and commit date you inspected.** Not "the code does X" but
"on `beta-1` (3 Sep), the code does X". A finding without provenance is unverifiable, and this
project has several long-lived branches at different dates — a claim true on one is false on another.

If a finding contradicts what the user sees in the running app, assume your ref is stale before
assuming the app is wrong: `git fetch --all` and check every branch, not just the checked-out one.

## Branches

- One branch per work stream, cut from the trunk. Name it for the work, not the tool.
- **Never push onto a branch another session is working on.** Merge the trunk in instead.
  (`claude/us3-void-implementation-3zl5oh` accumulated 23 unrelated commits this way and stopped
  being reviewable as a single change.)
- Never push directly to `main`. Never commit `server/.env` or anything under `.env*`.
- Push before switching machines. An unpushed commit is invisible to every other surface.

## Money and stock

The constitution (`.specify/memory/constitution.md`) governs; it is the top gate. In practice:

- Anything that touches orders, payments or inventory ships **with an integrity test** in
  `server/test/`. "It works when I tap it" is not verification for money paths.
- Corrections are append-only: void, refund, cancel and revise add new records and new inventory
  movements. Never rewrite a completed order, its lines, or a captured payment.
- The server recomputes every amount. Client-sent totals are display-only.

## Spec-Driven Development

Work flows Constitution → Spec → Plan → Tasks → Implement, with artifacts in `specs/001-pos-mvp/`.
When behaviour changes, amend the artifact **before or with** the code, not after — the constitution
bump for open bills (v1.2.0) is the pattern to follow.

## Testing

```bash
cd server && npm test     # jest + supertest against Postgres (local or sandbox, never RDS)
```
A cloud sandbox cannot reach AWS RDS and has no Android emulator: run backend tests against a local
Postgres there, and do device testing locally. Report failures as findings with their output — do
not "fix" a failing test by weakening its assertion; if a test is stale because the product changed,
say so explicitly and update it to the new contract.
