#!/usr/bin/env bash
# squash-and-push.sh
#
# Squashes the entire current committed tree into a single orphan commit,
# force-pushes it to the pre-configured "deploy" remote, then hard-resets
# the local branch back to origin.
#
# Usage:
#   bash scripts/squash-and-push.sh [deploy-branch] [commit-message]
#
# Examples:
#   bash scripts/squash-and-push.sh
#   bash scripts/squash-and-push.sh main
#   bash scripts/squash-and-push.sh master "chore: deploy"
#
# Prerequisites:
#   git remote add deploy <url>   ← must be done once beforehand

set -euo pipefail

# ── Arguments ────────────────────────────────────────────────────────────────
DEPLOY_BRANCH="${1:-master}"
COMMIT_MSG="${2:-"Initial commit: migrate to Astro + Tailwind CSS"}"

DEPLOY_REMOTE="deploy"

# ── Validate ──────────────────────────────────────────────────────────────────
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "ERROR: Not inside a git repository."
  exit 1
fi

if ! git remote get-url "$DEPLOY_REMOTE" &>/dev/null; then
  echo "ERROR: Remote '$DEPLOY_REMOTE' is not configured."
  echo "       Run: git remote add deploy <url>"
  exit 1
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
LOCAL_HEAD=$(git rev-parse HEAD)
DEPLOY_URL=$(git remote get-url "$DEPLOY_REMOTE")

# Warn about uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "WARNING: You have uncommitted changes. They will NOT be included in the squashed commit."
  echo "         Run 'git add -A && git commit' first if you want them included."
  echo ""
  read -rp "Continue anyway? [y/N] " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Branch  : $CURRENT_BRANCH (HEAD: ${LOCAL_HEAD:0:7})"
echo "  Remote  : $DEPLOY_REMOTE → $DEPLOY_URL"
echo "  Target  : $DEPLOY_BRANCH"
echo "  Message : $COMMIT_MSG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Step 1: Create a single orphan commit from the current committed tree ─────
#    git commit-tree <tree> -m <msg>  creates a new commit with no parents.
echo "→ Squashing entire tree into one commit..."
SQUASHED=$(git commit-tree HEAD^{tree} -m "$COMMIT_MSG")
echo "  Squashed SHA: $SQUASHED"

# ── Step 2: Force-push to the deploy remote ───────────────────────────────────
echo "→ Force-pushing to $DEPLOY_REMOTE/$DEPLOY_BRANCH..."
git push "$DEPLOY_REMOTE" "$SQUASHED:refs/heads/$DEPLOY_BRANCH" --force
echo "  ✓ Pushed."

# ── Step 3: Reset local branch back to origin ─────────────────────────────────
echo "→ Fetching origin..."
git fetch origin

ORIGIN_REF="origin/$CURRENT_BRANCH"
if ! git rev-parse "$ORIGIN_REF" &>/dev/null; then
  echo "WARNING: '$ORIGIN_REF' does not exist on origin. Skipping local reset."
  echo "         Reset manually with: git reset --hard origin/<branch>"
else
  echo "→ Resetting '$CURRENT_BRANCH' to $ORIGIN_REF..."
  git reset --hard "$ORIGIN_REF"
  echo "  ✓ Local branch restored to origin."
fi

echo ""
echo "✓ All done."
echo "  Squashed commit $SQUASHED pushed to $DEPLOY_URL ($DEPLOY_BRANCH)."
echo "  Local '$CURRENT_BRANCH' is now at $(git rev-parse --short HEAD) (origin)."


