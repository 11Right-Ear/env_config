# Dotfiles

Configuration for the robot arm development environment.

> **`SETUP.md` is the canonical document.** It contains the complete
> provisioning guide, the daily-use reference, and every known pitfall.
> This README only describes how this repository is organised.

## Restore on a new machine

```bash
bash ~/dotfiles/restore.sh
```

Then `exec zsh` to reload the shell.

## Layout

| Path | What it configures |
|---|---|
| `SETUP.md` | **The canonical document** — provisioning guide + daily-use reference |
| `nvim/init.lua` | Neovim — C++/CMake/ROS setup, native LSP, treesitter, git, quickfix |
| `yazi/yazi.toml` | Yazi main config |
| `yazi/keymap.toml` | Yazi keybindings |
| `yazi/theme.toml` | Yazi theme — Nord Polar Night (Yazi 0.4.2 format) |
| `tabby/config.yaml` | Tabby terminal — Nord scheme, zsh profile, CJK font |
| `tabby/launch_tabby.sh` | Tabby launcher (Wayland → XWayland bridge) |
| `git/ignore` | Global gitignore — C++ build output, CMake, ROS, Python, credentials |
| `git/attributes` | Global gitattributes — LF endings, `diff=cpp`, `diff=python` |
| `.zshrc` | zsh — oh-my-zsh, **Powerlevel10k**, ROS sourcing, 300+ aliases |
| `.p10k.zsh` | Powerlevel10k prompt config, incl. custom ROS 2 / CMake segments |
| `.clang-format` | LLVM style, C++17, 100 columns |
| `.colcon_defaults` | colcon — symlink-install, 2 workers, console output |
| `autostart/ibus-daemon.desktop` | Chinese input method (ibus) starts with GNOME |
| `ros2_ws/.gitignore` | Excludes vendored upstream repos from your commits |

## What is NOT here (and why)

- **`~/.gitconfig`** — not tracked, because it contains your `user.email`.
  The reusable parts (aliases, formatting) live in `git/ignore` +
  `git/attributes`.
- **`~/.oh-my-zsh/`** — a third-party checkout; reinstall with the
  oh-my-zsh installer, then the plugins.
- **Neovim plugins** — the config is deliberately plugin-free so it works
  with no network access. See `SETUP.md` for how to add LazyVim.
- **`~/bin/`** — nvim and yazi binaries, not configuration.
- **`~/ros2_ws/`** and **`~/dev/cpp-projects/`** — separate git repos,
  because they contain actual project code.

## Version-pinned files

Two configs are tied to an exact program version and will **silently stop
working** if the program is upgraded:

| Program | Pinned to | If upgraded |
|---|---|---|
| Yazi | **0.4.2** | `theme.toml` / `keymap.toml` must be rewritten for the 25.x schema, and renamed to `yazi-theme.toml` / `yazi-keymap.toml`. |
| Tabby | 1.0.238 | The `terminal.colorScheme` object shape may change. |

Check the program version before editing either config.

## The other repositories

| Repository | Contents |
|---|---|
| `~/ros2_ws` | The ROS 2 workspace — `robot_arm_core` package with the IK solver. Vendored upstream repos (navigation2, moveit2) are gitignored so commits stay clean. |
| `~/dev/cpp-projects` | Standalone C++/CMake projects — `robot_arm_planner` with 89 unit tests. |
