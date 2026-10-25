# Dotfiles

Configuration for the robot arm development environment.

## Contents

| Path | What it configures |
|---|---|
| `nvim/init.lua` | Neovim — C++/CMake/ROS setup, native LSP, treesitter, git, quickfix |
| `yazi/theme.toml` | Yazi file browser — **Nord** theme (Yazi 0.4.2 format) |
| `yazi/keymap.toml` | Yazi keybindings |
| `yazi/yazi.toml` | Yazi main config |
| `tabby/config.yaml` | Tabby terminal — **Nord** scheme, zsh profile, CJK font |
| `git/ignore` | Global gitignore — C++ build output, CMake, ROS, Python, credentials |
| `git/attributes` | Global gitattributes — LF endings, `diff=cpp` for C/C++, `diff=python` |
| `.zshrc` | zsh — oh-my-zsh, **Powerlevel10k**, ROS sourcing, 300+ aliases and helper functions |
| `.p10k.zsh` | Powerlevel10k prompt config, incl. custom ROS 2 / CMake segments |
| `.clang-format` | LLVM style, C++17, 100 columns |
| `.colcon_defaults` | colcon — symlink-install, 2 workers, console output |
| `autostart/ibus-daemon.desktop` | Chinese input method (ibus) starts with GNOME |
| `ros2_ws/.gitignore` | Excludes vendored upstream repos from your commits |

## Restore

```bash
bash ~/dotfiles/restore.sh
```

Then `exec zsh` to reload the shell.

## Version-sensitive files

Two config sets are **tied to a specific program version** and will silently
stop working if you upgrade:

| Program | Version | Notes |
|---|---|---|
| Yazi | **0.4.2** | `theme.toml` uses the 0.4.2 schema (`[manager]`, `[status]`, `[filetype]` with inline style tables). Yazi 25.x uses a completely different flat format, and its `[palettes.NAME]` mechanism does not exist in 0.4.2. |
| Yazi | **0.4.2** | Config files must be named `yazi.toml`, `keymap.toml`, `theme.toml`. The 25.x names (`yazi-keymap.toml`, `yazi-theme.toml`) are ignored by 0.4.2. |
| Tabby | 1.0.238 | `terminal.colorScheme` is a full colour object, not a scheme name string. |

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
