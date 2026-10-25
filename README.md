# Dotfiles

Configuration for the robot arm development environment.

## Contents

| Path | What it configures |
|---|---|
| `nvim/init.lua` | Neovim — C++/CMake/ROS setup, native LSP, treesitter, git, quickfix |
| `yazi/*.toml` | Yazi file browser — catppuccin theme, keybindings, git-aware listing |
| `git/ignore` | Global gitignore — C++ build output, CMake, ROS, Python, credentials |
| `git/attributes` | Global gitattributes — LF endings, `diff=cpp` for C/C++, `diff=python` |
| `.zshrc` | zsh — oh-my-zsh, ROS sourcing, 300+ aliases and helper functions |
| `.clang-format` | LLVM style, C++17, 100 columns |
| `.colcon_defaults` | colcon — symlink-install, 2 workers, console output |
| `autostart/ibus-daemon.desktop` | Chinese input method (ibus) starts with GNOME |
| `ros2_ws/.gitignore` | Excludes vendored upstream repos from your commits |

## Restore

```bash
bash ~/dotfiles/restore.sh
```

Then `exec zsh` to reload the shell.

## What is NOT here (and why)

- **`~/.gitconfig`** — not tracked, because it contains your `user.email`.
  The aliases and formatting settings are the reusable part and live in
  `git/ignore` + `git/attributes`.
- **`~/.oh-my-zsh/`** — a third-party checkout; reinstall with
  `bash ~/setup_zsh.sh`.
- **Neovim plugins** — the config is deliberately plugin-free so it works
  with no network access. See `README.md` in the project root for how to
  add LazyVim.
- **`~/bin/`** — nvim and yazi binaries, not config. Reinstall with the
  setup scripts.
