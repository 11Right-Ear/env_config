#!/usr/bin/env bash
# ============================================================
#  Delete the two project repositories from GitHub.
#
#  Requires a classic personal access token with BOTH scopes:
#      repo  AND  delete_repo
#
#  The `delete_repo` scope can only be granted when the token is
#  created — it cannot be added to an existing token.
#
#  Create one at:
#      https://github.com/settings/tokens/new
#      -> "Generate new token (classic)"
#      -> tick: repo  AND  delete_repo
#
#  Usage:
#      export GH_TOKEN=ghp_xxxxxxxxxxxx
#      bash ~/dotfiles/scripts/delete_project_repos.sh
# ============================================================
set -uo pipefail

REPOS=(ros2_ws cpp-projects)
ACCOUNT="11Right-Ear"
GH="$HOME/bin/gh"

if [ -z "${GH_TOKEN:-}" ]; then
    echo "=========================================="
    echo " GH_TOKEN is not set."
    echo
    echo " Create a CLASSIC token with the 'repo' AND"
    echo " 'delete_repo' scopes:"
    echo "   https://github.com/settings/tokens/new"
    echo "   -> Generate new token (classic)"
    echo "   -> tick 'repo' and 'delete_repo'"
    echo
    echo " Then:"
    echo "   export GH_TOKEN=ghp_xxxxxxxxxxxx"
    echo "   bash ~/dotfiles/scripts/delete_project_repos.sh"
    echo "=========================================="
    exit 1
fi

export GH_TOKEN

# Verify the token has the scope we need
SCOPES=$(curl -s -H "Authorization: token $GH_TOKEN" \
    "https://api.github.com/user" -D - -o /dev/null 2>/dev/null \
    | grep -i "^x-oauth-scopes:" | tr -d '\r' | awk '{print $2}')

echo ">>> Token scopes: $SCOPES"

if ! echo "$SCOPES" | grep -q "delete_repo"; then
    echo
    echo "=========================================="
    echo " This token is missing the 'delete_repo' scope."
    echo
    echo " It has: $SCOPES"
    echo " It needs: repo, delete_repo"
    echo
    echo " A classic token's scopes are fixed at creation"
    echo " time — you cannot add delete_repo afterwards."
    echo
    echo " Delete the repos by hand instead (30 seconds):"
    echo "   https://github.com/$ACCOUNT/ros2_ws/settings"
    echo "   https://github.com/$ACCOUNT/cpp-projects/settings"
    echo "   -> scroll to the bottom -> Danger Zone"
    echo "   -> 'Delete this repository'"
    echo "=========================================="
    exit 1
fi

for repo in "${REPOS[@]}"; do
    echo ">>> Deleting $ACCOUNT/$repo ..."
    if "$GH" repo delete "$ACCOUNT/$repo" --yes 2>&1 | tail -1; then
        echo "    deleted"
    else
        echo "    FAILED"
    fi
done

echo
echo ">>> Remaining repos:"
"$GH" repo list "$ACCOUNT" --limit 100 --json name --jq '.[].name' 2>/dev/null | sort
