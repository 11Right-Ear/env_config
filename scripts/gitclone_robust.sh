#!/usr/bin/env bash
# ============================================================
#  Robust git-clone helper for flaky/rate-limited networks.
#  Tries several GitHub proxies in turn, with backoff.
# ============================================================
# Usage: gitclone_robust.sh <url> <dest-dir> [branch]
set -uo pipefail

URL="$1"
DEST="$2"
BRANCH="${3:-}"

# --- Mirror prefixes that work over plain HTTPS git ---
MIRRORS=(
  ""                                       # direct
  "https://ghfast.top/https://github.com/"  # release-asset proxy (works for git too on some mirrors)
)

# --- Extra wait between attempts (seconds) ---
BACKOFF=(5 15 30 60 90)

echo ">>> Cloning $URL -> $DEST (branch: ${BRANCH:-default})"

for attempt in $(seq 1 12); do
  wait_s="${BACKOFF[$(( attempt > ${#BACKOFF[@]} ? ${#BACKOFF[@]}-1 : attempt-1 ))]}"

  # Try direct first, then mirrors
  for prefix in "${MIRRORS[@]}"; do
    if [ -z "$prefix" ]; then
      target="$URL"
    else
      # strip https://github.com/ from URL and re-prefix
      target="${prefix}${URL#https://github.com/}"
    fi

    rm -rf "$DEST"
    if [ -n "$BRANCH" ]; then
      GIT_TERMINAL_PROMPT=0 timeout 300 git clone --filter=blob:none --depth 1 \
        --branch "$BRANCH" "$target" "$DEST" >/dev/null 2>&1
    else
      GIT_TERMINAL_PROMPT=0 timeout 300 git clone --filter=blob:none --depth 1 \
        "$target" "$DEST" >/dev/null 2>&1
    fi

    if [ -d "$DEST" ] && [ -n "$(ls -A "$DEST" 2>/dev/null)" ]; then
      echo "    OK (attempt $attempt via ${prefix:-direct})"
      exit 0
    fi
  done

  echo "    attempt $attempt failed, waiting ${wait_s}s..."
  sleep "$wait_s"
done

echo "    FAILED after all attempts"
exit 1
