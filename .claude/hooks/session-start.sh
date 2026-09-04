#!/bin/bash
# DPOS SessionStart hook — runs on every Claude Code session (cloud AND local).
#
# Why: sessions never see each other's conversations, only git. A session that starts
# with a stale view of the remote reports stale conclusions. This fetches first and
# prints who-changed-what so the agent (and you) start from the real state.
set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo .)}" || exit 0

TRUNK="main"

# 1. Never reason from a stale remote. Failure here must not block the session.
git fetch --all --prune --quiet 2>/dev/null || echo "  (offline — branch map may be stale)"

echo ""
echo "════ DPOS branch map ═════════════════════════════════════════════════"
printf "  %-42s %-11s %s\n" "BRANCH" "LAST COMMIT" "vs $TRUNK"
git for-each-ref --sort=-committerdate refs/remotes/origin \
  --format='%(refname:short)|%(committerdate:short)' | while IFS='|' read -r ref date; do
  short="${ref#origin/}"
  [ "$short" = "HEAD" ] && continue
  counts=$(git rev-list --left-right --count "origin/$TRUNK...$ref" 2>/dev/null || echo "0	0")
  behind=$(echo "$counts" | cut -f1); ahead=$(echo "$counts" | cut -f2)
  if [ "$short" = "$TRUNK" ]; then rel="(trunk)"; else rel="+$ahead / -$behind"; fi
  printf "  %-42s %-11s %s\n" "$short" "$date" "$rel"
done

# 2. Where this session is standing.
echo ""
echo "  you are on: $(git rev-parse --abbrev-ref HEAD) @ $(git log -1 --format='%h %ad' --date=short)"
UNPUSHED=$(git log --oneline @{u}.. 2>/dev/null | wc -l | tr -d ' ')
[ "${UNPUSHED:-0}" -gt 0 ] && echo "  ⚠  $UNPUSHED unpushed commit(s) — push before switching machines"
[ -n "$(git status --porcelain 2>/dev/null)" ] && echo "  ⚠  uncommitted changes in the working tree"

# 3. The handoff document is the shared brain — surface its heading.
if [ -f DEVLOG.md ]; then
  echo ""
  grep -m1 '^_Last updated' DEVLOG.md | sed 's/^/  DEVLOG /'
  echo "  Read DEVLOG.md + CLAUDE.md before acting. State the branch you inspected in any finding."
fi
echo "══════════════════════════════════════════════════════════════════════"
echo ""

# 4. Cloud sandboxes start empty — make the backend runnable without a round trip.
if [ "${CLAUDE_CODE_REMOTE:-}" = "true" ] && [ ! -d server/node_modules ]; then
  echo "  installing server dependencies (first run in this sandbox)…"
  (cd server && npm install --no-audit --no-fund >/dev/null 2>&1 && npx prisma generate >/dev/null 2>&1) \
    && echo "  server deps ready." || echo "  ‼ server dependency install failed — run it manually."
fi

exit 0
