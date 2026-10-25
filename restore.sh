#!/usr/bin/env bash
# ============================================================
#  Restore dotfiles to a fresh machine.
#
#  Usage:  bash ~/dotfiles/restore.sh
# ============================================================
set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME}"

echo "=========================================="
echo " Restoring dotfiles from $DOTFILES"
echo "=========================================="

# ---- Neovim ----
if [ -f "$DOTFILES/nvim/init.lua" ]; then
    mkdir -p "$HOME_DIR/.config/nvim"
    cp "$DOTFILES/nvim/init.lua" "$HOME_DIR/.config/nvim/init.lua"
    echo "  ✓ nvim/init.lua"
fi

# ---- Yazi ----
if [ -d "$DOTFILES/yazi" ]; then
    mkdir -p "$HOME_DIR/.config/yazi"
    cp "$DOTFILES/yazi/"*.toml "$HOME_DIR/.config/yazi/"
    echo "  ✓ yazi configs"
fi

# ---- Git ----
if [ -d "$DOTFILES/git" ]; then
    mkdir -p "$HOME_DIR/.config/git"
    cp "$DOTFILES/git/ignore" "$DOTFILES/git/attributes" "$HOME_DIR/.config/git/"
    echo "  ✓ git ignore + attributes"
fi

# ---- Shell ----
if [ -f "$DOTFILES/.zshrc" ]; then
    cp "$DOTFILES/.zshrc" "$HOME_DIR/.zshrc"
    echo "  ✓ .zshrc"
fi

# ---- Formatting / build defaults ----
[ -f "$DOTFILES/.clang-format" ]      && cp "$DOTFILES/.clang-format" "$HOME_DIR/"      && echo "  ✓ .clang-format"
[ -f "$DOTFILES/.colcon_defaults" ]   && cp "$DOTFILES/.colcon_defaults" "$HOME_DIR/"   && echo "  ✓ .colcon_defaults"

# ---- Autostart ----
if [ -d "$DOTFILES/autostart" ]; then
    mkdir -p "$HOME_DIR/.config/autostart"
    cp "$DOTFILES/autostart/"*.desktop "$HOME_DIR/.config/autostart/"
    echo "  ✓ autostart entries"
fi

# ---- ROS workspace ignore ----
if [ -f "$DOTFILES/ros2_ws/.gitignore" ]; then
    mkdir -p "$HOME_DIR/ros2_ws"
    cp "$DOTFILES/ros2_ws/.gitignore" "$HOME_DIR/ros2_ws/"
    echo "  ✓ ros2_ws/.gitignore"
fi

echo
echo "=========================================="
echo " Done. Files were copied into \$HOME."
echo " Restart your shell:  exec zsh"
echo "=========================================="
