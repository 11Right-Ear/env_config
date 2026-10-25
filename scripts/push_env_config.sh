#!/usr/bin/env bash
# ============================================================
#  Create the `env_config` repository on GitHub and push.
#
#  Requires a GitHub personal access token with the `repo` scope.
#  Create one at:
#      https://github.com/settings/tokens/new
#      -> Fine-grained tokens -> Generate
#      -> Repository access: Public repositories (Read and write)
#      -> Permissions: Repository permissions -> Contents: Read and write
#
#  Usage:
#      export GH_TOKEN=ghp_xxxxxxxxxxxx
#      bash ~/push_env_config.sh
# ============================================================
set -euo pipefail

REPO_NAME="env_config"
REPO_DESC="Robot arm development environment — setup guide and dotfiles"
DOTFILES="$HOME/dotfiles"
ACCOUNT="11Right-Ear"

if [ -z "${GH_TOKEN:-}" ]; then
    echo "=========================================="
    echo " GH_TOKEN is not set."
    echo
    echo " Create a token at:"
    echo "   https://github.com/settings/tokens/new"
    echo "   (Fine-grained token, Contents: Read and write)"
    echo
    echo " Then run:"
    echo "   export GH_TOKEN=ghp_xxxxxxxxxxxx"
    echo "   bash ~/push_env_config.sh"
    echo "=========================================="
    exit 1
fi

GH="$HOME/bin/gh"
export GH_TOKEN

echo ">>> Creating $ACCOUNT/$REPO_NAME ..."
if "$GH" repo view "$ACCOUNT/$REPO_NAME" >/dev/null 2>&1; then
    echo "    repository already exists"
else
    "$GH" repo create "$ACCOUNT/$REPO_NAME" \
        --description "$REPO_DESC" \
        --public \
        --source "$DOTFILES" \
        --remote origin \
        --push
    echo "    created"
fi

cd "$DOTFILES"

# Make sure the remote points at the SSH URL
git remote remove origin 2>/dev/null || true
git remote add origin "git@github.com:${ACCOUNT}/${REPO_NAME}.git"

echo ">>> Pushing main ..."
git push -u origin main

echo
echo "=========================================="
echo " Done: https://github.com/${ACCOUNT}/${REPO_NAME}"
echo "=========================================="
