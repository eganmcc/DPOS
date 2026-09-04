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

## Branches — trunk-based on `main`

- **`main` is the only long-lived branch. Commit there.** It is always deployable and is what EC2
  ships; the integrity suite (`cd server && npm test`) is the gate that keeps it green.
- Cut a **short-lived** branch only for risky or parallel work, then merge it back and delete it.
  Long-lived branches are what made "the code" ambiguous before — a cloud session once reported a
  feature missing because it read a branch six days stale.
- **Never push onto a branch another session is working on.** Merge the trunk in instead.
  (`claude/us3-void-implementation-3zl5oh` accumulated 23 unrelated commits this way and stopped
  being reviewable as a single change.)
- Never commit `server/.env` or anything under `.env*`.
- Push before switching machines. An unpushed commit is invisible to every other surface.
- Deleting a **fully-merged** branch loses nothing (its commits live on in `main`); record the tip
  SHA in the DEVLOG deletion ledger so it can be recreated with `git branch <name> <sha>`.

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
cd server && npm test     # jest + supertest — 8 suites / 35 tests
```
The suite builds an **isolated `Test <uuid>` merchant** per run and tears it down afterwards
(`cleanupMerchant` in `test/fixtures.ts`), so it never touches demo/production data.

- **Prefer a local/sandbox Postgres.** A cloud sandbox can't reach AWS RDS anyway, so run there
  against local Postgres; point `DATABASE_URL` at a throwaway DB when you can.
- **Running against RDS is tolerated, not the default.** Local `server/.env` currently points at
  RDS; the suite's per-run isolation + self-cleanup make this safe in practice (verified 2026-09-05),
  but it still writes transient tenants to the production DB — don't do it casually, and never from a
  shared/CI runner.
- Do **device** testing locally (no Android emulator in the sandbox).
- Report failures as findings **with their output**. Never "fix" a failing test by weakening its
  assertion; if a test is stale because the product changed, say so explicitly and update it to the
  new contract.
