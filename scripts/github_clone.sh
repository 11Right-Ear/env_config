#!/usr/bin/env bash
# ============================================================
#  GitHub access helper
#
#  GitHub rate-limits unauthenticated git access from shared IPs.
#  This script finds a working route to clone a repository.
#
#  Usage:
#    bash ~/github_clone.sh <owner/repo> [dest-dir] [branch]
#
#  Example:
#    bash ~/github_clone.sh folke/lazy-vim ~/.local/share/nvim/lazy/lazy-vim main
# ============================================================
set -uo pipefail

REPO="${1:?usage: github_clone.sh <owner/repo> [dest] [branch]}"
DEST="${2:-$(basename "$REPO")}"
BRANCH="${3:-}"

# Normalise "owner/repo" into a URL
BASE="https://github.com/${REPO}.git"
if [ -n "$BRANCH" ]; then
  BASE="${BASE}"  # branch is passed to git clone, not the URL
fi

echo "=========================================="
echo " GitHub clone: $REPO"
echo " Destination : $DEST"
echo " Branch      : ${BRANCH:-<default>}"
echo "=========================================="

# --- Route 1: SSH (needs your key registered on GitHub) ---
if [ -f "$HOME/.ssh/id_ed25519" ]; then
  echo "[1/4] Trying SSH (git@github.com)..."
  rm -rf "$DEST"
  if GIT_TERMINAL_PROMPT=0 timeout 300 git clone --filter=blob:none --depth 1 \
      ${BRANCH:+--branch "$BRANCH"} \
      "git@github.com:${REPO}.git" "$DEST" 2>/dev/null; then
    echo "      -> OK via SSH"
    exit 0
  fi
  echo "      -> SSH failed (key not registered?)"
fi

# --- Route 2: direct HTTPS ---
echo "[2/4] Trying direct HTTPS..."
rm -rf "$DEST"
if GIT_TERMINAL_PROMPT=0 timeout 300 git clone --filter=blob:none --depth 1 \
    ${BRANCH:+--branch "$BRANCH"} \
    "$BASE" "$DEST" 2>/dev/null; then
  echo "      -> OK via HTTPS"
  exit 0
fi
echo "      -> HTTPS failed"

# --- Route 3: HTTP proxies (work for release assets; some also proxy git) ---
for PROXY in \
  "https://ghfast.top/https://github.com/" \
  "https://gh-proxy.com/https://github.com/" \
  "https://ghproxy.net/https://github.com/" ; do
  echo "[3/4] Trying proxy: $(echo "$PROXY" | cut -d/ -f3)..."
  rm -rf "$DEST"
  TARGET="${PROXY}${REPO}.git"
  if GIT_TERMINAL_PROMPT=0 timeout 300 git clone --filter=blob:none --depth 1 \
      ${BRANCH:+--branch "$BRANCH"} \
      "$TARGET" "$DEST" 2>/dev/null; then
    echo "      -> OK via $PROXY"
    exit 0
  fi
done

# --- Route 4: wait for the rate limit and retry direct ---
echo "[4/4] Waiting 120s for GitHub rate limit, then retrying..."
sleep 120
rm -rf "$DEST"
if GIT_TERMINAL_PROMPT=0 timeout 600 git clone --filter=blob:none --depth 1 \
    ${BRANCH:+--branch "$BRANCH"} \
    "$BASE" "$DEST" 2>/dev/null; then
  echo "      -> OK after backoff"
  exit 0
fi

echo "=========================================="
echo " All routes failed."
echo
echo " Most likely cause: GitHub rate-limits anonymous git"
echo " access from your IP."
echo
echo " Fix (one time):"
echo "   1. Add your SSH key to GitHub:"
echo "      cat ~/.ssh/id_ed25519.pub"
echo "      -> paste at github.com/settings/ssh/keys"
echo "   2. Re-run this script — it will use SSH."
echo "=========================================="
exit 1
