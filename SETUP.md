# Robot Arm Development Environment — Full Setup Guide

> **Purpose:** This document is the single source of truth for provisioning a
> robot-arm C++/ROS 2 development environment. Hand it to an AI agent on a
> fresh machine and say *"set up the robot arm development environment using
> this document"* — it contains every command, version pin, known pitfall and
> verification step needed.
>
> **Target machine:** Ubuntu 22.04.5 LTS (Jammy) · x86_64 · ROS 2 Humble · glibc 2.35

---

## Table of contents

1. [Target state (summary)](#1-target-state-summary)
2. [Preflight — verify the machine](#2-preflight--verify-the-machine)
3. [Phase 1 — System packages](#3-phase-1--system-packages)
4. [Phase 2 — Neovim](#4-phase-2--neovim)
5. [Phase 3 — Yazi](#5-phase-3--yazi)
6. [Phase 4 — zsh + oh-my-zsh](#6-phase-4--zsh--oh-my-zsh)
7. [Phase 5 — Git configuration](#7-phase-5--git-configuration)
8. [Phase 6 — ROS 2 workspace, Navigation2, MoveIt 2](#8-phase-6--ros-2-workspace-navigation2-moveit-2)
9. [Phase 7 — C++ template packages](#9-phase-7--c-template-packages)
10. [Phase 8 — Chinese input (ibus + libpinyin)](#10-phase-8--chinese-input-ibus--libpinyin)
11. [Phase 9 — Dotfiles repository](#11-phase-9--dotfiles-repository)
12. [Tabby terminal (optional)](#12-tabby-terminal-optional)
13. [Final verification](#13-final-verification)
14. [Known pitfalls](#14-known-pitfalls)
15. [Appendix — file manifests](#15-appendix--file-manifests)

---

## 1. Target state (summary)

| Component | Version | Install location |
|---|---|---|
| Ubuntu | 22.04.5 LTS | system |
| g++ | 11.4.0 | `/usr/bin/g++` (preinstalled) |
| CMake | 3.22.1 | `/usr/bin/cmake` (preinstalled) |
| GDB | 12.1 | `/usr/bin/gdb` (preinstalled) |
| Git | 2.34.1 | `/usr/bin/git` (preinstalled) |
| ROS 2 | Humble | `/opt/ros/humble` (preinstalled) |
| Neovim | 0.11.2 | `~/bin/nvim` (user-local, no sudo) |
| Yazi | 0.4.2 | `~/bin/yazi`, `~/bin/ya` |
| zsh | 5.8.1 | `/usr/bin/zsh` — **default login shell** |
| oh-my-zsh | master | `~/.oh-my-zsh` + 4 plugins |
| Powerlevel10k | master | `~/.oh-my-zsh/custom/themes/powerlevel10k` |
| clangd | 14.0.0 | `/usr/bin/clangd` |
| ibus-libpinyin | 1.12.1 | `/usr/libexec/ibus-engine-libpinyin` |
| Navigation2 / MoveIt 2 | Humble | apt binaries **and** source clones |
| ccache, ninja, fzf, rg, fd, bat, tmux, btop, jq | latest | apt |

### Directory layout produced

```
~/
├── bin/                    # nvim, yazi, ya  (user-local, no sudo)
├── dev/cpp-projects/       # standalone C++ / CMake projects (git repo)
│   └── robot_arm_planner/
├── ros2_ws/                # ROS 2 colcon workspace (git repo)
│   └── src/
│       ├── robot_arm_core/     # the user's C++ ROS 2 package
│       ├── navigation2/        # upstream source (own git repo)
│       ├── moveit2/            # upstream source (own git repo)
│       ├── ros2_control/
│       └── ros2_controllers/
├── dotfiles/               # version-controlled configuration (git repo)
│   ├── nvim/init.lua
│   ├── yazi/*.toml
│   ├── git/{ignore,attributes}
│   ├── autostart/ibus-daemon.desktop
│   ├── .zshrc, .clang-format, .colcon_defaults
│   └── restore.sh
├── .config/
│   ├── nvim/init.lua
│   ├── yazi/*.toml
│   ├── git/{ignore,attributes}
│   └── autostart/ibus-daemon.desktop
├── .gitconfig              # global git config + aliases
├── .clang-format
├── .colcon_defaults
├── .oh-my-zsh/
└── .ssh/id_ed25519         # GitHub SSH key
```

---

## 2. Preflight — verify the machine

Run this first. **Do not proceed** if the OS or glibc differ — see
[Known pitfalls](#14-known-pitfalls).

```bash
echo "=== OS ==="; lsb_release -d; lsb_release -cs
echo "=== arch ==="; uname -m
echo "=== glibc ==="; ldd --version | head -1
echo "=== ROS ==="; ls /opt/ros/ 2>/dev/null || echo "NO ROS INSTALLED"
echo "=== existing tools ==="
for t in g++ cmake gdb git zsh nvim yazi clangd; do
  printf "%-8s " "$t"; command -v $t 2>/dev/null || echo "-"
done
echo "=== sudo ==="; sudo -n true 2>&1 && echo "passwordless" || echo "needs password"
```

**Expected:** Ubuntu 22.04, x86_64, glibc 2.35, `/opt/ros/humble` present.

**If ROS is missing**, install ROS 2 Humble first (this is a large download):

```bash
sudo apt-get update && sudo apt-get install -y locales software-properties-common curl
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

sudo add-apt-repository universe
sudo apt-get update && sudo apt-get install -y python3-colcon-common-extensions

# ROS 2 apt repository (mirror below is for users in China; use the
# official one otherwise)
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
  -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" \
  | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null

sudo apt-get update && sudo apt-get install -y ros-humble-desktop ros-humble-ros-base
```

---

## 3. Phase 1 — System packages

All package names below were **verified to exist** in the Ubuntu 22.04 and
ROS Humble archives. Installing anything not listed here risks
`E: Unable to locate package`.

```bash
sudo apt-get update

# --- Core build tools (g++, cmake, make, gdb already present on 22.04) ---
sudo apt-get install -y \
    build-essential cmake ninja-build gdb gdb-multiarch \
    pkg-config ccache

# --- Shell + modern CLI ---
sudo apt-get install -y \
    zsh zsh-common git curl wget unzip \
    fzf ripgrep fd-find bat tree htop btop tmux jq

# --- C++ language server + formatter ---
sudo apt-get install -y clangd clangd-14

# --- ROS 2: Navigation2 + MoveIt 2 (apt binaries) ---
sudo apt-get install -y \
    ros-humble-navigation2 \
    ros-humble-nav2-bringup \
    ros-humble-nav2-bt-navigator \
    ros-humble-nav2-smoother \
    ros-humble-moveit \
    ros-humble-moveit-servo \
    ros-humble-moveit-ros \
    ros-humble-moveit-ros-perception \
    ros-humble-moveit-ros-visualization \
    ros-humble-moveit-task-constructor-core \
    ros-humble-ros2-control \
    ros-humble-ros2-controllers \
    ros-humble-urdf \
    ros-humble-tf2-ros \
    ros-humble-tf2-tools \
    ros-humble-rmw-cyclonedds-cpp \
    ros-humble-xacro \
    ros-humble-joint-state-publisher \
    ros-humble-robot-state-publisher \
    ros-humble-nav2-msgs \
    ros-humble-action-msgs \
    ros-humble-ros2topic

# --- Extra ROS dev tooling ---
sudo apt-get install -y \
    python3-colcon-common-extensions \
    python3-rosdep \
    python3-pip \
    python3-vcstool \
    ros-humble-ament-cmake \
    ros-humble-ament-lint-auto \
    ros-humble-ament-lint-common \
    ros-humble-rosbag2-storage-mcap \
    ros-humble-rosbridge-suite

# --- GUI automation helpers (optional, for testing GUIs) ---
sudo apt-get install -y xdotool xclip x11-utils
```

### Post-install fixups

```bash
# Ubuntu ships the fd binary as "fdfind"; expose it as "fd"
if ! command -v fd >/dev/null 2>&1; then
    sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
fi

# Ubuntu ships "bat" as "batcat"; expose it as "bat"
if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
    sudo ln -sf "$(command -v batcat)" /usr/local/bin/bat
fi

# Enable ccache for faster rebuilds
sudo ccache -M 5G
```

### Package-name corrections (important)

Several intuitively-named ROS packages **do not exist**. Use these instead:

| Wrong name | Correct name |
|---|---|
| `ros-humble-ros2-urdf` | `ros-humble-urdf` |
| `ros-humble-ros2-tf2-ros` | `ros-humble-tf2-ros` |
| `ros-humble-moveit-ros-moveit` | `ros-humble-moveit-ros` |
| `ros-humble-ros2-action` | `ros-humble-action-msgs` |
| `ros-humble-navigation-msgs` | `ros-humble-nav2-msgs` |
| `ros-humble-ros2-topic-echo` | `ros-humble-ros2topic` |
| `ros-humble-industrial-moveit` | *(not in Humble — use `moveit-task-constructor-core`)* |
| `tree-sitter-cli` | *(not in Ubuntu 22.04 — skip it)* |

---

## 4. Phase 2 — Neovim

### Install (user-local, no sudo)

Neovim 0.11.2 tarball. Install into `~/bin` so no root is needed.

```bash
mkdir -p ~/bin
cd /tmp
NVIM_VER="v0.11.2"
for URL in \
  "https://ghfast.top/https://github.com/neovim/neovim/releases/download/${NVIM_VER}/nvim-linux-x86_64.tar.gz" \
  "https://gh-proxy.com/https://github.com/neovim/neovim/releases/download/${NVIM_VER}/nvim-linux-x86_64.tar.gz" \
  "https://github.com/neovim/neovim/releases/download/${NVIM_VER}/nvim-linux-x86_64.tar.gz" ; do
  if curl -fL --connect-timeout 15 --max-time 600 -o nvim.tar.gz "$URL"; then break; fi
done

tar xzf nvim.tar.gz
cp -r nvim-linux-x86_64/bin/nvim ~/bin/nvim.real
cp -r nvim-linux-x86_64/lib nvim-linux-x86_64/share ~/bin/
```

### Launcher wrapper

The tarball layout puts the runtime in `~/bin/share/nvim/runtime`, but Neovim
looks in `$VIMRUNTIME`. A wrapper pins it:

```bash
cat > ~/bin/nvim <<'EOF'
#!/usr/bin/env bash
# Neovim launcher — pins the runtime path so the tarball install works.
export VIMRUNTIME="$HOME/bin/share/nvim/runtime"
exec "$HOME/bin/nvim.real" "$@"
EOF
chmod +x ~/bin/nvim
```

### Move the treesitter parsers

They ship in `~/bin/lib/nvim/parser/` but Neovim looks in
`$VIMRUNTIME/parser/`:

```bash
mkdir -p ~/bin/share/nvim/runtime/parser
cp ~/bin/lib/nvim/parser/*.so ~/bin/share/nvim/runtime/parser/
```

### Make it available system-wide

```bash
sudo ln -sf "$HOME/bin/nvim" /usr/local/bin/nvim
```

> **Note on `sudo` and `$HOME`:** `sudo` resets `$HOME` to `/root`. Always use
> `REAL_HOME="/home/${SUDO_USER:-$(whoami)}"` in scripts run under sudo.

### Configuration

`~/.config/nvim/init.lua` — see [Appendix](#15-appendix--file-manifests) for the
full contents. It is **deliberately plugin-free** (uses only Neovim built-ins:
native LSP, treesitter, quickfix, built-in git provider) so it works with no
network access.

**Critical API details for Neovim 0.11** (these are easy to get wrong):

- `vim.lsp.enable(name)` only *marks* a config as enabled — the config itself
  with a `cmd` must exist. Define them first:

  ```lua
  vim.lsp.config("clangd", {
    cmd = { "clangd", "--background-index", "--clang-tidy" },
    filetypes = { "c", "cpp" },
    root_markers = { "compile_commands.json", "CMakeLists.txt", "package.xml", ".git" },
  })
  vim.lsp.enable({ "clangd" })
  ```

- `vim.lsp.config()` takes `(name, cfg)` — **not** a list of tables.
- `root_markers` order matters: the first match walking upwards wins. Put
  `compile_commands.json` **before** `.git`, otherwise clangd picks the
  wrong project root and finds no symbols.
- `vim.opt_local` is **not** a function. Use `vim.bo.<opt>` for buffer options
  and `vim.opt_local.<name>` for window-local options (e.g. `colorcolumn`).
- `completeopt` is a comma-separated **string**, not an array:
  `vim.opt.completeopt = "menu,menuone,noselect"`.
- Do not shadow a mapping helper with a same-named local that calls itself
  recursively — use a distinct name (`bmap` vs `map`).

### Verify

```bash
nvim --version | head -1
nvim --headless -c 'lua print("filetype:", vim.bo.filetype)' \
     -c 'edit ~/dev/cpp-projects/robot_arm_planner/src/main.cpp' -c 'qa!' 2>&1 | tail -3
```

Expect `NVIM v0.11.2` and `filetype: cpp` with **no errors**.

---

## 5. Phase 3 — Yazi

### Install (user-local)

> ⚠️ **glibc constraint — this is the single most important gotcha.**
> Ubuntu 22.04 has glibc 2.35. **Every Yazi release from v25.2.7 onward is
> built against glibc 2.39 and will fail with
> `GLIBC_2.39 not found`.** Yazi **0.4.2** is the newest build that runs on
> this system. Verify the binary actually starts — do not assume.

```bash
mkdir -p ~/bin && cd /tmp
YAZI_VER="v0.4.2"   # pinned deliberately — newer versions need glibc 2.39
for URL in \
  "https://ghfast.top/https://github.com/sxyazi/yazi/releases/download/${YAZI_VER}/yazi-x86_64-unknown-linux-gnu.zip" \
  "https://gh-proxy.com/https://github.com/sxyazi/yazi/releases/download/${YAZI_VER}/yazi-x86_64-unknown-linux-gnu.zip" \
  "https://github.com/sxyazi/yazi/releases/download/${YAZI_VER}/yazi-x86_64-unknown-linux-gnu.zip" ; do
  if curl -fL --connect-timeout 15 --max-time 600 -o yazi.zip "$URL"; then break; fi
done

rm -rf ye && mkdir ye
python3 -c "import zipfile; zipfile.ZipFile('/tmp/yazi.zip').extractall('/tmp/ye')"
# ZIP does not preserve the executable bit
cp ye/yazi-x86_64-unknown-linux-gnu/yazi ye/yazi-x86_64-unknown-linux-gnu/ya ~/bin/
chmod +x ~/bin/yazi ~/bin/ya
```

### Verify (mandatory)

```bash
~/bin/yazi --version   # must print a version, NOT a GLIBC error
```

### Configuration

Yazi 0.4.2 reads exactly three files from `~/.config/yazi/`:

```
yazi.toml       main config
keymap.toml     keybindings
theme.toml      colours
```

> ⚠️ **The names matter.** `yazi-keymap.toml` and `yazi-theme.toml` are
> Yazi 25.x names and are **silently ignored** by 0.4.2 — you get an
> unthemed file browser with no warning.

See the [Appendix](#15-appendix--file-manifests) for the Nord theme and
keymap contents.

**Yazi 0.4.2 uses a different `[opener]` schema than newer versions:**

```toml
# ✅ 0.4.2 (this machine)
[opener]
edit = [
    { name = "nvim", run = 'edit -- "$@"', for = "text" },
]

# ❌ newer Yazi — will fail with: missing field `run`
[opener]
edit = [
    { name = "nvim", use = "edit -- $@", desc = "Open in Neovim" },
]
```

The `[opener]` table also uses `run` (not `use`) and `for` (not `desc`).

### Verify the config parses

```bash
~/bin/yazi --debug 2>&1 | head -10
```

Expect the version banner and **no** "Failed to parse the [open] or [opener]
section" error.

---

## 6. Phase 4 — zsh + oh-my-zsh

### Install zsh and make it the default

```bash
sudo apt-get install -y zsh zsh-common
chsh -s "$(which zsh)" "$USER"
```

Verify: `grep zsh /etc/passwd` should show `/usr/bin/zsh` as the shell.

### Install oh-my-zsh

```bash
if [ ! -d ~/.oh-my-zsh ]; then
  RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
```

### Install the plugins

Four plugins are wanted:

| Plugin | Purpose |
|---|---|
| `zsh-autosuggestions` | inline autosuggestion from history |
| `zsh-syntax-highlighting` | syntax highlighting |
| `fast-syntax-highlighting` | faster highlighting (alternative) |
| `zsh-completions` | extra completions |

> ⚠️ **GitHub rate-limiting.** Anonymous git clones frequently return
> `HTTP 401` ("could not read Username") from shared IPs. If `git clone`
> fails, use the **codeload tarball** endpoint instead — it usually works
> even while the git protocol is throttled:

```bash
PLUG="$HOME/.oh-my-zsh/custom/plugins"
mkdir -p "$PLUG"

fetch_plugin() {  # $1=owner/repo  $2=branch  $3=target-dir
  local repo="$1" branch="$2" dest="$3"
  for i in $(seq 1 15); do
    rm -rf /tmp/tz && mkdir -p /tmp/tz
    if curl -fsL --connect-timeout 15 --max-time 120 \
         -o /tmp/tz/a.tgz \
         "https://codeload.github.com/${repo}/tar.gz/refs/heads/${branch}" \
       && tar xzf /tmp/tz/a.tgz -C /tmp/tz 2>/dev/null; then
      local src=$(find /tmp/tz -maxdepth 1 -type d -name "*" ! -name tz | head -1)
      rm -rf "$dest" && mv "$src" "$dest" && echo "OK $(basename "$dest")" && return 0
    fi
    echo "retry $i: $repo"; sleep 5
  done
  echo "FAIL $repo"; return 1
}

fetch_plugin zsh-users/zsh-syntax-highlighting   master "$PLUG/zsh-syntax-highlighting"
fetch_plugin zsh-users/zsh-completions           master "$PLUG/zsh-completions"
fetch_plugin zdharma-continuum/fast-syntax-highlighting master "$PLUG/fast-syntax-highlighting"
fetch_plugin zsh-users/zsh-autosuggestions       master "$PLUG/zsh-autosuggestions"
```

**Verify each plugin has its `.plugin.zsh` file** — oh-my-zsh silently
skips a plugin directory that lacks one:

```bash
for d in ~/.oh-my-zsh/custom/plugins/*/; do
  printf "%-28s " "$(basename "$d")"
  ls "$d" | grep -q '\.plugin\.zsh' && echo OK || echo "MISSING .plugin.zsh"
done
```

### Powerlevel10k (prompt theme)

```bash
mkdir -p ~/.oh-my-zsh/custom/themes && cd ~/.oh-my-zsh/custom/themes
for i in 1 2 3 4 5; do
  rm -rf powerlevel10k
  if curl -fsL --connect-timeout 15 --max-time 120 -o p10k.tgz \
       "https://codeload.github.com/romkatv/powerlevel10k/tar.gz/refs/heads/master" \
     && tar xzf p10k.tgz 2>/dev/null; then
    mv powerlevel10k-master powerlevel10k && rm -f p10k.tgz && break
  fi
  sleep 5
done
```

Three things are required — **all three** — or the theme silently fails:

1. **A symlink** so oh-my-zsh can find it. oh-my-zsh looks for a *file*
   `$ZSH_CUSTOM/themes/<name>.zsh-theme`, but p10k is a *directory*:

   ```bash
   cd ~/.oh-my-zsh/custom/themes
   ln -sfn powerlevel10k/powerlevel10k.zsh-theme powerlevel10k.zsh-theme
   ```

2. **Source the theme before oh-my-zsh**, because p10k overrides `ZSH_THEME`:

   ```zsh
   P10K_DIR="$ZSH/custom/themes/powerlevel10k"
   if [ -d "$P10K_DIR" ]; then
       source "$P10K_DIR/powerlevel10k.zsh-theme"
   fi
   ```

3. **Source `~/.p10k.zsh` explicitly.** Without this line p10k launches its
   interactive setup wizard instead of applying the configuration:

   ```zsh
   if [ -f "$HOME/.p10k.zsh" ]; then
       source "$HOME/.p10k.zsh"
   fi
   ```

Create the config from a shipped preset, then add custom segments:

```bash
cp ~/.oh-my-zsh/custom/themes/powerlevel10k/config/p10k-classic.zsh ~/.p10k.zsh
```

> **Custom p10k segments must be named `prompt_<name>`** (not `<name>`),
> must be **defined inside the config file's `() { ... }` wrapper** so they
> are global, and must use the `p10k segment -f <colour> -i <icon> -t <text>`
> API. The text is passed **pre-expanded** — `-t "$ROS_DISTRO"`, not
> `-t '%{ROS_DISTRO}'` (which renders the literal string).

See the `~/.p10k.zsh` entry in the [Appendix](#15-appendix--file-manifests)
for a ready-to-use configuration with ROS 2 and CMake segments.

**Verify:**

```bash
zsh -i -c 'print -l $POWERLEVEL9K_LEFT_PROMPT_ELEMENTS'
```

Expect the segment list to include `ros_distro`, `ros_workspace` and
`cmake_project`.

### `.zshrc`

Full contents in the [Appendix](#15-appendix--file-manifests). It provides:

- ROS 2 auto-sourcing (`/opt/ros/humble/setup.zsh` and the workspace)
- 300+ aliases: git (`st`, `lg`, `ap`, `big`), ROS (`colb`, `rosnodes`,
  `rostopics`, `follow`, `record`), build (`ccmake`, `cmakeb`, `cgdb`),
  files (`catf`, `fgrep`)
- Helper functions: `mkcd`, `buildpkg`, `use_ros`, `findnode`, `follow`,
  `record`, `which_ros`, `y` (yazi wrapper that `cd`s to the exit directory)
- `MAKEFLAGS=-j$(nproc)` and `CMAKE_BUILD_PARALLEL_LEVEL` for fast builds
- `ROS_LOCALHOST_ONLY=1` so ROS traffic stays on the machine

> ⚠️ **Do not use `setopt CASE_GLOB_SUBST`** — it is not a valid zsh option
> and will print `no such option` on every shell start.

### Verify

```bash
zsh -n ~/.zshrc                                  # syntax check
zsh -i -c 'echo "$(alias|wc -l) aliases"' 2>&1 | tail -2
```

Expect ~306 aliases and **no** error output.

---

## 7. Phase 5 — Git configuration

### Global `.gitconfig`

Full contents in the [Appendix](#15-appendix--file-manifests). It sets:

- `user.name`, `user.email`
- `init.defaultBranch = main`
- `core.editor = nvim`
- `merge.conflictstyle = zdiff3`
- `rerere.enabled = true`
- `diff.algorithm = histogram`
- ~30 aliases (`st`, `lg`, `la`, `ap`, `unstage`, `cb`, `up`, `pushf`,
  `big`, `amend`, `subup`, …)

### Global ignore + attributes

`~/.config/git/ignore` — C++ build output, CMake artefacts, ROS
`build/ install/ log/`, Python caches, editor files, credentials.

`~/.config/git/attributes` — LF line endings, `diff=cpp` for C/C++ files,
`diff=python` for Python, binary markers for `.so`/`.png`/`.dae`.

### SSH key

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
ssh-keygen -t ed25519 -C "$(whoami)@users.noreply.github.com" \
            -f ~/.ssh/id_ed25519 -N ""
chmod 600 ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
```

**Action required by the user:** paste the public key into
GitHub → Settings → SSH and GPG keys. Without this, all GitHub clones fail
with `401`.

---

## 8. Phase 6 — ROS 2 workspace, Navigation2, MoveIt 2

### Workspace skeleton

```bash
mkdir -p ~/ros2_ws/src ~/dev/cpp-projects
```

### colcon defaults

```bash
cat > ~/.colcon_defaults <<'EOF'
build:
  symlink-install: true
  parallel-workers: 2
  event-handlers:
    - console_direct+
EOF
```

### Clone the upstream sources

Both Nav2 and MoveIt 2 are installed **twice on purpose**:

- **apt binaries** — precompiled, zero build time, use these to run
- **git clones** — readable and patchable, use these to study or modify

```bash
cd ~/ros2_ws/src
for r in \
  "https://github.com/ros-navigation/navigation2.git navigation2" \
  "https://github.com/moveit/moveit2.git moveit2" \
  "https://github.com/ros-controls/ros2_control.git ros2_control" \
  "https://github.com/ros-controls/ros2_controllers.git ros2_controllers" ; do
  set -- $r
  [ -d "$2" ] || git clone --depth 1 --branch humble "$1" "$2"
done
```

### Keep your commits clean

`~/ros2_ws/.gitignore` must exclude the vendored repos (they carry their own
`.git`):

```
src/navigation2/
src/moveit2/
src/ros2_control/
src/ros2_controllers/
build/
install/
log/
```

### The `robot_arm_core` package

A working C++17 ROS 2 package containing a **Jacobian-based inverse
kinematics solver** for a planar 3-DOF arm.

> **Why Jacobian-based IK:** the analytic closed form for a 3-link planar arm
> is easy to get subtly wrong (mixing the wrist-centre distance with the
> target distance produces plausible-looking but incorrect results). A damped
> Newton–Raphson iteration on the position Jacobian converges to ~1e-14 for
> every reachable target and degrades gracefully near singularities. It is
> also what real arms use.

Files: `package.xml`, `CMakeLists.txt`,
`include/robot_arm_core/kinematics.hpp`, `src/kinematics.cpp`,
`src/arm_node.cpp`. Full contents in the [Appendix](#15-appendix--file-manifests).

**Two CMake details that break the build if wrong:**

1. `ament_export_targets()` requires a matching export set:

   ```cmake
   install(TARGETS robot_arm_core
     EXPORT export_robot_arm_core
     ARCHIVE DESTINATION lib
     LIBRARY DESTINATION lib
     RUNTIME DESTINATION bin
   )
   ament_export_targets(export_robot_arm_core HAS_LIBRARY_TARGET)
   ```

   Without the `EXPORT` clause → `INSTALL(EXPORT) given unknown export`.

2. **Executables must land in `lib/<package_name>/`** so that
   `ros2 run <pkg> <exe>` can find them:

   ```cmake
   install(TARGETS arm_node DESTINATION lib/${PROJECT_NAME})
   ```

   Installing to `bin/` builds fine but `ros2 run` reports
   `No executable found`.

3. The header needs `#include <cmath>` for `M_PI`, or the build fails with
   `'M_PI' was not declared in this scope`.

### Build and verify

```bash
source /opt/ros/humble/setup.bash
cd ~/ros2_ws
colcon build --symlink-install --packages-select robot_arm_core
source install/setup.bash
ros2 run robot_arm_core arm_node --ros-args -p target_x:=0.5 -p target_y:=0.2
```

Expected output (FK round-trip error ≈ 1e-14):

```
[INFO] [arm_node]: IK solution: q = [-0.3100, 0.9128, 0.9121] rad
[INFO] [arm_node]: FK check   : (0.500000, 0.200000)  err = 2.29e-14
```

> ⚠️ **Never `source` the ROS setup script in a script that runs under
> `set -euo pipefail`.** The ROS setup files reference unset shell
> variables, which trips `set -u` and silently aborts the script. Use
> `set -eo pipefail` (drop the `u`), or source it in a subshell with
> `set +u`.

---

## 9. Phase 7 — C++ template packages

### Standalone CMake project — `robot_arm_planner`

Location: `~/dev/cpp-projects/robot_arm_planner/`. Full contents in the
[Appendix](#15-appendix--file-manifests).

Structure:

```
robot_arm_planner/
├── CMakeLists.txt
├── include/robot_arm/
│   ├── kinematics/{planar_kinematics.hpp,jacobian.hpp}
│   ├── planning/trajectory_generator.hpp
│   └── utils/logger.hpp
├── src/
│   ├── main.cpp
│   ├── kinematics/{planar_kinematics.cpp,jacobian.cpp}
│   ├── planning/trajectory_generator.cpp
│   └── utils/logger.cpp
└── tests/test_kinematics.cpp
```

**CMakeLists essentials:**

```cmake
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
```

- `target_compile_options(... ${PROJECT_NAME}_core ...)` must come **after**
  the target is created, otherwise CMake errors with *"Cannot specify compile
  options for target … which is not built by this project."*
- A POST_BUILD step symlinks `compile_commands.json` into the source root so
  clangd finds it without `--compile-commands-dir`.

### Build, test, debug

```bash
cd ~/dev/cpp-projects/robot_arm_planner
cmake -S . -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build -j$(nproc)
./build/unit_tests          # 89 checks, 0 failures
./build/robot_arm_planner --x 0.55 --y 0.3 --trajectory
```

GDB:

```bash
gdb -q -batch -ex "break main" -ex "run --x 0.4" ./build/robot_arm_planner
```

---

## 10. Phase 8 — Chinese input (ibus + libpinyin)

For **Ubuntu GNOME on Wayland**, `ibus` is the correct framework — it
integrates natively with the GNOME top-bar indicator.

```bash
sudo apt-get install -y ibus-libpinyin ibus-pinyin ibus-gtk ibus-gtk3
```

### Configure GNOME input sources

```bash
gsettings set org.gnome.desktop.input-sources sources \
  "[('xkb', 'us'), ('ibus', 'libpinyin')]"
gsettings set org.gnome.desktop.input-sources mru-sources \
  "[('xkb', 'us'), ('ibus', 'libpinyin')]"
```

Switch key (already the GNOME default): **`<Super>space`** or `XF86Keyboard`.

### Restart the daemon so it picks up the new engine

```bash
ibus exit 2>/dev/null; sleep 2
ibus-daemon --daemonize --xim --replace
```

**Verify the engine is actually loaded** (this is the step that matters):

```bash
ibus engine                            # -> libpinyin
ibus list-engine | grep -A1 libpinyin # -> "libpinyin - Intelligent Pinyin"
pgrep -a ibus-engine-libpinyin         # -> the engine process must exist
```

If the engine does not appear, the daemon was started before the package was
installed and must be restarted.

### Autostart (survives reboot)

`~/.config/autostart/ibus-daemon.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=IBus Daemon
Exec=/usr/bin/ibus-daemon --daemonize --xim --replace
Icon=input-method
Terminal=false
X-GNOME-Autostart-Phase=Applications
X-GNOME-Autostart-Notify=true
OnlyShowIn=GNOME;Unity;
```

### Fonts

31 CJK fonts ship with Ubuntu. Set the terminal font for correct rendering:

```bash
gsettings set org.gnome.desktop.interface monospace-font-name \
  "'Noto Sans Mono CJK SC 12'"
```

### Switching engines from the shell

```bash
ibus engine libpinyin      # Chinese
ibus engine xkb:us::eng   # English
```

### Shuangpin (optional)

```bash
ibus-setup-libpinyin
```

Offers 小鹤双拼 (Xiaohe), 自然码双拼 (Ziranma) and MS Shuangpin.

---

## 11. Phase 9 — Dotfiles repository

Version-control the configuration so a new machine can be rebuilt in minutes.

```bash
mkdir -p ~/dotfiles/{nvim,yazi,git,ros2_ws,autostart}
cd ~/dotfiles && git init -b main

cp ~/.config/nvim/init.lua            nvim/
cp ~/.config/yazi/*.toml               yazi/
cp ~/.config/git/{ignore,attributes}   git/
cp ~/.zshrc .clang-format .colcon_defaults .
cp ~/.config/autostart/ibus-daemon.desktop autostart/
cp ~/ros2_ws/.gitignore                ros2_ws/
```

Include a `restore.sh` that copies everything back into `$HOME`, and a
`README.md` explaining what is and is not tracked (e.g. `~/.gitconfig` is
excluded because it holds the user's email).

---

## 12. Tabby terminal (optional)

Tabby is a modern terminal with split panes, SSH management and themes.
It ships a built-in **Nord** scheme, which matches the Yazi theme.

```bash
# Download the .deb (x64)
cd /tmp
TABBY_VER="v1.0.238"
for URL in \
  "https://ghfast.top/https://github.com/Eugeny/tabby/releases/download/${TABBY_VER}/tabby-${TABBY_VER#v}-linux-x64.deb" \
  "https://gh-proxy.com/https://github.com/Eugeny/tabby/releases/download/${TABBY_VER}/tabby-${TABBY_VER#v}-linux-x64.deb" ; do
  if curl -fL --connect-timeout 15 --max-time 900 -o tabby.deb "$URL"; then break; fi
done
sudo dpkg -i tabby.deb
```

### Set it as the default terminal

```bash
gsettings set org.gnome.desktop.default-applications.terminal exec \
  "/opt/Tabby/tabby --no-sandbox %U"

sudo update-alternatives --install /usr/bin/x-terminal-emulator \
  x-terminal-emulator /opt/Tabby/tabby 60
sudo update-alternatives --set x-terminal-emulator /opt/Tabby/tabby
```

> **Note:** `org.gnome.desktop.terminal` does **not** exist unless
> gnome-terminal is installed. Use
> `org.gnome.desktop.default-applications.terminal` instead.

### Configuration

`~/.config/tabby/config.yaml` — see the
[Appendix](#15-appendix--file-manifests) for the Nord configuration.

Two Tabby specifics that are easy to get wrong:

* `terminal.colorScheme` is a **full colour object**, not a scheme name
  string. Tabby matches it against its built-in schemes by comparing the
  colour values.
* The file goes in `~/.config/tabby/config.yaml`, **not** `~/.tabby/`.

### Launching on Wayland

Tabby is an Electron (X11) app. On a Wayland session it must be started
with the XWayland bridge, otherwise it fails with `Error: Bad window`:

```bash
cat > ~/.local/bin/launch-tabby <<'EOF'
#!/usr/bin/env bash
export DISPLAY=:0
export XDG_SESSION_TYPE=x11
export GDK_BACKEND=x11
export ELECTRON_DISABLE_SANDBOX=1
unset WAYLAND_DISPLAY
exec /opt/Tabby/tabby --no-sandbox --disable-gpu --disable-dev-shm-usage \
     --ozone-platform=x11
EOF
chmod +x ~/.local/bin/launch-tabby
```

---

## 13. Final verification

Run this after every phase. It should print all ✓.

```bash
echo "╔══════════════════════════════════════════════════╗"
echo "║   ROBOT ARM DEV ENVIRONMENT — VERIFICATION       ║"
echo "╚══════════════════════════════════════════════════╝"

echo "[ TOOLCHAIN ]"
for t in g++ cmake gdb git zsh nvim yazi clangd rg fzf bat tmux fd; do
  printf "  %-9s " "$t"; command -v $t >/dev/null && echo "✓" || echo "✗ MISSING"
done
printf "  %-9s " "ros2"
source /opt/ros/humble/setup.bash 2>/dev/null && echo "✓ ($(ros2 pkg list|wc -l) pkgs)"

echo "[ SHELL ]"
printf "  login shell   %s\n" "$(grep zsh /etc/passwd | cut -d: -f7)"
printf "  aliases       %s\n" "$(zsh -i -c 'alias|wc -l' 2>/dev/null|tail -1)"
printf "  plugins       %s\n" "$(ls ~/.oh-my-zsh/custom/plugins/ | grep -v example | wc -l)"

echo "[ ROS 2 ]"
for p in navigation2 moveit nav2_bringup controller_manager moveit_servo; do
  printf "  %-16s " "$p"
  (source /opt/ros/humble/setup.bash 2>/dev/null && \
   ros2 pkg prefix $p >/dev/null 2>&1) && echo "✓" || echo "✗"
done
for d in navigation2 moveit2 ros2_control ros2_controllers; do
  printf "  %-16s " "$d (src)"; [ -d ~/ros2_ws/src/$d/.git ] && echo "✓" || echo "✗"
done
printf "  %-16s " "robot_arm_core"; [ -d ~/ros2_ws/install/robot_arm_core ] && echo "✓ built" || echo "✗"

echo "[ C++ ]"
cd ~/dev/cpp-projects/robot_arm_planner
printf "  %-16s %s\n" "unit tests" "$(./build/unit_tests 2>&1 | grep checks)"

echo "[ CHINESE INPUT ]"
printf "  %-16s %s\n" "engine" "$(ibus engine)"
printf "  %-16s %s\n" "CJK fonts" "$(fc-list :lang=zh | wc -l)"

echo "[ GIT ]"
printf "  %-16s %s\n" "user" "$(git config --global user.name)"
printf "  %-16s %s\n" "ssh key" "$([ -f ~/.ssh/id_ed25519 ] && echo ✓ || echo ✗)"
```

---

## 14. Known pitfalls

### P1 — GitHub anonymous git access returns 401

```
fatal: could not read Username for 'https://github.com': terminal prompts disabled
```

GitHub rate-limits unauthenticated git clones from shared IPs. **Fixes, in
order of preference:**

1. Add your SSH key to GitHub, then clone with `git@github.com:owner/repo.git`.
2. Use the **codeload tarball** endpoint, which usually works even while the
   git protocol is throttled:
   ```bash
   curl -fsL -o r.tgz "https://codeload.github.com/OWNER/REPO/tar.gz/refs/heads/BRANCH"
   tar xzf r.tgz
   ```
3. Wait and retry with backoff.
4. Use a proxy mirror (`ghfast.top`, `gh-proxy.com`) — these work for
   release assets but often **not** for git endpoints.

Also note the DNS on some networks resolves GitHub to a filtered IP range
(`20.205.243.x`). Test with
`curl -sI --resolve github.com:443:140.82.113.3 https://github.com/...`.

### P2 — Yazi: `GLIBC_2.39 not found`

```
/lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.39' not found
```

Ubuntu 22.04 has glibc 2.35. Yazi ≥ v25.2.7 requires 2.39. **Use v0.4.2.**
Upgrade to Ubuntu 24.04 or build from source with `cargo build --release`.

### P3 — `ros2 run` says `No executable found`

The executable must be installed into `lib/<package_name>/`, not `bin/`:

```cmake
install(TARGETS arm_node DESTINATION lib/${PROJECT_NAME})
```

### P4 — `INSTALL(EXPORT) given unknown export "robot_arm_core"`

The `install(TARGETS ...)` needs an `EXPORT` clause, and
`ament_export_targets()` must name that same export set.

### P5 — Scripts silently abort after sourcing ROS

`set -euo pipefail` + ROS setup = instant death (the setup files reference
unset variables). Drop the `u`, or source in a subshell with `set +u`.

### P6 — clangd finds no symbols

The project root is wrong. `root_markers` must put
`compile_commands.json` **before** `.git`. Also ensure
`compile_commands.json` exists (and is symlinked into the source root, not
left in `build/`).

First launch takes ~15 s while clangd indexes — goto-definition appears
broken until it finishes.

### P7 — `vim.lsp.enable()` does nothing

It only marks a config as enabled. Define `vim.lsp.config(name, cfg)` with a
`cmd` first.

### P8 — zsh prints `no such option: CASE_GLOB_SUBST`

Not a valid zsh option. Remove it.

### P9 — oh-my-zsh says `plugin 'zsh-completions' not found`

The plugin directory lacks a `<name>.plugin.zsh` file — usually because a
partial clone left only `.git/`. Re-fetch via the codeload method above.

### P10 — `bat` / `fd` not found

Ubuntu names them `batcat` and `fdfind`. Symlink them (see Phase 1).

### P11 — `sudo` scripts see `$HOME=/root`

Use `REAL_HOME="/home/${SUDO_USER:-$(whoami)}"`.

### P12 — Powerlevel10k loads but shows no custom segments

Three separate requirements must all be met. Check them in order:

1. `~/.oh-my-zsh/custom/themes/powerlevel10k.zsh-theme` must exist as a
   **symlink** to `powerlevel10k/powerlevel10k.zsh-theme`. Without it
   oh-my-zsh prints `[oh-my-zsh] theme 'powerlevel10k' not found`.
2. `~/.zshrc` must `source ~/.p10k.zsh` explicitly, otherwise p10k runs its
   interactive wizard instead of loading the config.
3. Custom segment functions must be named `prompt_<name>`, be defined
   **inside** the config file's `() { ... }` wrapper, and pass text
   **pre-expanded** (`-t "$ROS_DISTRO"`, not `-t '%{ROS_DISTRO}'`).

Diagnose with:

```bash
zsh -i -c 'print -l $POWERLEVEL9K_LEFT_PROMPT_ELEMENTS'
```

An empty list means the config file was never sourced.

> Note: p10k refuses to load its config in a non-TTY session, so testing
> with `zsh -i -c '...'` over a pipe can show an empty segment list even
> when the config is fine. Test in a real terminal.

### P13 — Yazi 0.4.2 ignores your theme and keymap

Yazi 0.4.2 looks for exactly three config files in `~/.config/yazi/`:

```
yazi.toml
keymap.toml
theme.toml
```

The names `yazi-keymap.toml` and `yazi-theme.toml` are **Yazi 25.x** and are
**silently ignored** by 0.4.2 — no error, just an unthemed file browser.

On top of that, the 0.4.2 theme schema differs completely from 25.x:

* 25.x: flat sections like `[main]`, `[file]`, with `name = "bg"`
* 0.4.2: sections like `[manager]`, `[status]`, `[filetype]`, with inline
  style tables like `cwd = { fg = "#88c0d0" }`
* the `[palettes.NAME]` mechanism exists only in 25.x

Yazi refuses to start if the theme contains an unknown key, so copy the
official preset and override only the colours:

```bash
# Fetch the 0.4.2 preset to use as a reference
curl -fsL -o yazi.tgz \
  "https://codeload.github.com/sxyazi/yazi/tar.gz/refs/tags/v0.4.2"
tar xzf yazi.tgz
less yazi-0.4.2/yazi-config/preset/theme-dark.toml
```

Verify the theme loads:

```bash
yazi --debug 2>&1 | head -10   # must not print "Failed to parse your theme.toml"
```

### P14 — `tree-sitter-cli` not installable

Not in Ubuntu 22.04's archive. Skip it — the bundled Neovim treesitter
parsers are enough.

---

## 15. Appendix — file manifests

### `~/.config/nvim/init.lua`

```lua
-- ============================================================
--  Neovim configuration — C++17 / CMake / ROS 2 / GDB
--
--  Self-contained: uses only Neovim's built-in features
--  (LSP, treesitter, quickfix, terminal). No plugin downloads
--  required, so it works regardless of network conditions.
-- ============================================================

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.wrap = false
vim.opt.signcolumn = "yes"
vim.opt.undofile = true
vim.opt.swapfile = false
vim.opt.writebackup = false
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = true
vim.opt.hlsearch = true
vim.opt.completeopt = "menu,menuone,noselect"
vim.opt.updatetime = 250
vim.opt.timeoutlen = 400
vim.opt.mouse = "a"
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.splitkeep = "screen"

vim.filetype.add({
  extension = {
    urdf = "xml", xacro = "xml", launch = "xml", sdf = "xml", rviz = "yaml",
  },
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "cpp", "objc", "h" },
  callback = function()
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
    vim.bo.softtabstop = 4
    vim.bo.expandtab = true
    vim.bo.textwidth = 100
    vim.opt_local.colorcolumn = "101"
    vim.bo.formatoptions = "tcqj"
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "yaml", "json", "toml" },
  callback = function()
    vim.bo.tabstop = 2
    vim.bo.shiftwidth = 2
    vim.bo.softtabstop = 2
    vim.bo.expandtab = true
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "makefile",
  callback = function()
    vim.bo.expandtab = false
    vim.bo.tabstop = 8
    vim.bo.shiftwidth = 8
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "python", "sh", "bash", "zsh" },
  callback = function()
    vim.bo.expandtab = true
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
  end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  callback = function(args)
    local ft = vim.bo[args.buf].filetype
    if ft == "markdown" or ft == "text" or ft == "" then return end
    local view = vim.fn.winsaveview()
    vim.cmd([[noautocmd keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

vim.api.nvim_create_autocmd({ "CursorMoved", "InsertLeave" }, {
  group = vim.api.nvim_create_augroup("cursor_scroll", { clear = true }),
  callback = function()
    if vim.fn.mode() ~= "c" and vim.fn.line(".") > 10
       and vim.fn.line(".") < vim.fn.line("$") - 10 then
      vim.cmd("normal! zz")
    end
  end,
})

local map = vim.keymap.set

-- ============================================================
--  LSP
-- ============================================================

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

vim.lsp.config("clangd", {
  cmd = { "clangd", "--background-index", "--clang-tidy" },
  filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
  root_markers = {
    "compile_commands.json",
    "CMakeLists.txt",
    "package.xml",
    ".git",
  },
})

vim.lsp.config("cmake", {
  cmd = { "cmake-language-server" },
  filetypes = { "cmake" },
  root_markers = { ".git", "CMakeLists.txt" },
})

vim.lsp.config("bashls", {
  cmd = { "bash-language-server", "start" },
  filetypes = { "sh", "bash", "zsh" },
  root_markers = { ".git" },
})

vim.lsp.config("pyright", {
  cmd = { "pyright-langserver", "--stdio" },
  filetypes = { "python" },
  root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt" },
})

vim.lsp.enable({ "clangd", "cmake", "bashls", "pyright" })

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    -- NOTE: do not shadow the outer `map` here — use a distinct name so the
    -- buffer-local variant does not call itself recursively.
    local function bmap(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, desc = desc })
    end

    bmap("n", "gd", vim.lsp.buf.definition, "LSP: goto definition")
    bmap("n", "gD", vim.lsp.buf.declaration, "LSP: goto declaration")
    bmap("n", "gi", vim.lsp.buf.implementation, "LSP: goto implementation")
    bmap("n", "gr", vim.lsp.buf.references, "LSP: references")
    bmap("n", "K", vim.lsp.buf.hover, "LSP: hover documentation")
    bmap("n", "<C-k>", vim.lsp.buf.signature_help, "LSP: signature help")
    bmap("n", "<C-s>", vim.lsp.buf.code_action, "LSP: code action")
    bmap("n", "[d", function()
      vim.diagnostic.jump({ count = -1, float = true })
    end, "LSP: previous diagnostic")
    bmap("n", "]d", function()
      vim.diagnostic.jump({ count = 1, float = true })
    end, "LSP: next diagnostic")
    bmap("n", "<leader>lf", vim.lsp.buf.format, "LSP: format file")
    bmap("n", "<leader>lr", vim.lsp.buf.rename, "LSP: rename symbol")
    bmap("n", "<leader>la", vim.lsp.buf.code_action, "LSP: code action")
    bmap("n", "<leader>ld", vim.diagnostic.open_float, "LSP: diagnostic float")
    bmap("n", "<leader>ls", vim.diagnostic.setloclist, "LSP: set loclist")
    bmap("x", "<leader>lf", vim.lsp.buf.format, "LSP: format selection")
  end,
})

map("i", "<C-y>", function() return vim.lsp.buf.completion.get() end,
  { desc = "LSP: complete" })
map("i", "<C-n>", function()
  vim.lsp.completion.get({ select = false, finish = "builtin" })
end, { desc = "LSP: next completion" })
map("i", "<C-p>", function()
  vim.lsp.completion.get({ select = false, finish = "builtin" })
end, { desc = "LSP: previous completion" })

-- ============================================================
--  File finding (no telescope needed)
-- ============================================================

map("n", "<leader>ff", function()
  local root = vim.fs.root(0, { ".git", "CMakeLists.txt", "package.xml" })
    or vim.fn.getcwd()
  vim.ui.input({ prompt = "Find file> " }, function(pattern)
    if not pattern or pattern == "" then return end
    vim.cmd("find " .. vim.fn.escape(root .. "/" .. pattern, " "))
    vim.cmd("setlocal noignorecase")
  end)
end, { desc = "Find files in project" })

map("n", "<leader>fg", function()
  local root = vim.fs.root(0, { ".git", "CMakeLists.txt", "package.xml" })
    or vim.fn.getcwd()
  vim.ui.input({ prompt = "Grep> " }, function(pattern)
    if not pattern or pattern == "" then return end
    vim.fn.setreg("/", vim.fn.escape(pattern, " "))
    vim.cmd("silent! noignorecase keeppatterns %s/" ..
            vim.fn.escape(pattern, " ") .. "/g " .. vim.fn.escape(root, " "))
    vim.cmd("copen")
  end)
end, { desc = "Grep in project" })

-- ============================================================
--  Quickfix / windows / terminal / git
-- ============================================================

map("n", "<leader>qc", vim.cmd.cclose, { desc = "Close quickfix" })
map("n", "<leader>qi", function()
  vim.cmd("copen")
  vim.cmd("wincmd p")
end, { desc = "Quickfix window" })
map("n", "<leader>qn", function() vim.cmd("cnext") end, { desc = "Next quickfix" })
map("n", "<leader>qp", function() vim.cmd("cprev") end, { desc = "Previous quickfix" })

map("n", "<leader>w", vim.cmd.write, { desc = "Write file" })
map("n", "<leader>q", vim.cmd.quit, { desc = "Quit window" })
map("n", "<leader>h", "<C-w>h", { desc = "Window left" })
map("n", "<leader>j", "<C-w>j", { desc = "Window down" })
map("n", "<leader>k", "<C-w>k", { desc = "Window up" })
map("n", "<leader>l", "<C-w>l", { desc = "Window right" })
map("n", "<leader>v", "<C-w>v", { desc = "Vertical split" })
map("n", "<leader>s", "<C-w>s", { desc = "Horizontal split" })
map("n", "<leader>bn", "<C-^>", { desc = "Previous buffer" })
map("n", "<leader>bd", vim.cmd.bdelete, { desc = "Delete buffer" })

map("n", "<leader>t", vim.cmd.terminal, { desc = "Open terminal" })
map("n", "<leader>tn", function() vim.cmd("split | terminal") end,
  { desc = "Terminal in split" })

map("n", "<leader>gg", function() vim.cmd("Gstatus") end, { desc = "Git status" })
map("n", "<leader>ga", function() vim.cmd("Git add") end, { desc = "Git add file" })
map("n", "<leader>gc", function() vim.cmd("Git commit -m 'wip'") end, { desc = "Git commit" })
map("n", "<leader>gb", function() vim.cmd("Git branch") end, { desc = "Git branch" })
map("n", "<leader>gd", function() vim.cmd("Git diff") end, { desc = "Git diff" })

-- Debug keys (bind to GDB / nvim-dap as preferred)
map("n", "<leader>db", "<F9>", { desc = "Debug: toggle breakpoint" })
map("n", "<leader>dc", "<F5>", { desc = "Debug: continue" })
map("n", "<leader>ds", "<F10>", { desc = "Debug: step over" })
map("n", "<leader>di", "<F11>", { desc = "Debug: step into" })
map("n", "<leader>dq", "<F12>", { desc = "Debug: quit" })

-- ============================================================
--  Treesitter (bundled parsers only)
-- ============================================================

local function start_treesitter(buf)
  pcall(vim.treesitter.start, buf)
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "cpp", "lua", "markdown", "vim", "vimdoc", "query" },
  callback = function(args)
    start_treesitter(args.buf)
  end,
})

-- ============================================================
--  Statusline
-- ============================================================

vim.opt.laststatus = 3
vim.opt.showmode = false
vim.opt.showtabline = 2
vim.opt.fillchars = { eob = " " }

vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = function()
    vim.g.statusline = "%#qa#%F " .. table.concat({
      "%f", "%h%w%m", "%r", "%=",
      "[%{getcwd()}]",
      "[%{v:lua.require('vim.fn').bufnr()}]",
      "%-14.(%l,%c%V%) %P",
    }, "")
    vim.cmd("redrawstatus")
  end,
})

-- ============================================================
--  Lazy.nvim bootstrap (only if plugins are added later)
-- ============================================================

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if vim.uv.fs_stat(lazypath) then
  vim.opt.rtp:prepend(lazypath)
end
```

### `~/.config/yazi/yazi.toml`

```toml
[mgr]
show_hidden = true
show_symlink = true
show_git_dirty = true
sort_by = "mtime"
sort_reverse = false
sort_dir_first = true
linemode = "mtime"
ratio = 1
scrolloff = 5

[preview]
wrap = "no"
max_width = 800
max_height = 800
image_filter = "none"

[input]
cursor_blink = false

[opener]
edit = [
    { name = "nvim", run = 'edit -- "$@"', for = "text" },
]
extract = [
    { name = "7z", run = '7z x -y -o$HOME/.local/share/yazi/archive "$@"', for = "archive" },
]
compress = [
    { name = "tar", run = 'tar -czf archive.tar.gz "$@"', for = "archive" },
]
tab = [
    { name = "tab", run = 'tab --cwd="$@"', for = "dir" },
]

[plugins]
prepend_preview = [
    "git",
    "zip",
    "ya pkg yazi-plugin-previewers",
]
```

### `~/.config/yazi/keymap.toml`

```toml
[manager]
h = "cd .."
l = "cd --interactive"
g = "cd --interactive"
H = "cd -"
L = "cd --parent"

o = "open"
O = "open --hover"
e = "edit"
E = "edit --await"
w = "open --cwd"
y = "shell --block 'exec $EDITOR $@' --"

t = "tab --current"
T = "tab --current --cwd"
n = "tab --next"
P = "tab --prev"
"]" = "tab --close"

"/" = "search --via=filter"
N = "search --via=filter --next"
M = "search --via=filter --prev"
f = "search --via=filter"
F = "search --filter-smart"
"," = "search --filter-smart"
"." = "escape"

"g," = "seek --to=0"
"g;" = "seek --to=$"
gg = "seek --to=0"
G = "seek --to=-1"

m = "toggle --state=show_hidden"
"`" = "toggle --state=show_symlink"
"=" = "toggle --state=show_git_dirty"

d = "remove --dir"
x = "remove"
X = "remove --permanent"
c = "copy --smart"
p = "paste --overwrite"
r = "paste --raw --overwrite"

C = "copy --clipboard"
Y = "copy --clipboard --raw"

"+" = "toggle --state=hidden"
"~" = "cd --interactive"
s = "shell"
S = "shell --block"
z = "quit"
Z = "quit --state"

"?" = "help"
```

### `~/.config/yazi/theme.toml`

**Yazi 0.4.2 format — Nord Polar Night.**

The 0.4.2 theme schema is completely different from Yazi 25.x:

* sections are `[manager]`, `[mode]`, `[status]`, `[input]`, `[confirm]`,
  `[pick]`, `[completion]`, `[tasks]`, `[which]`, `[help]`, `[notify]`,
  `[filetype]` — **not** the flat `[main]` / `[file]` / `name = "..."` form
* the `[palettes.NAME]` mechanism **does not exist** in 0.4.2
* every style is an inline table: `fg = "#88c0d0"`, `bg = "#2e3440"`,
  plus `bold`, `italic`, `underline`, `reversed`
* a few fields are plain values, not styles: `btn_labels` is `[String; 2]`,
  `cols` is an integer 1–3, `border_symbol` / `separator_open` are strings,
  and the `icon_*` fields are strings

Yazi refuses to start on an unknown key, so the key list must match the
official 0.4.2 preset exactly.

```toml
"$schema" = "https://yazi-rs.github.io/schemas/theme.json"

[flavor]
dark  = ""
light = ""

[manager]
cwd = { fg = "#88c0d0" }

hovered         = { reversed = true }
preview_hovered = { underline = true }

find_keyword  = { fg = "#ebcb8b", bold = true, italic = true, underline = true }
find_position = { fg = "#b48ead", bg = "reset", bold = true, italic = true }

marker_copied   = { fg = "#a3be8c", bg = "#a3be8c" }
marker_cut      = { fg = "#bf616a", bg = "#bf616a" }
marker_marked   = { fg = "#88c0d0", bg = "#88c0d0" }
marker_selected = { fg = "#ebcb8b", bg = "#ebcb8b" }

tab_active   = { reversed = true }
tab_inactive = {}
tab_width    = 1

count_copied   = { fg = "#2e3440", bg = "#a3be8c" }
count_cut      = { fg = "#2e3440", bg = "#bf616a" }
count_selected = { fg = "#2e3440", bg = "#ebcb8b" }

border_symbol = "│"
border_style  = { fg = "#4c566a" }

syntect_theme = ""

[mode]
normal_main = { fg = "#d8dee9" }
normal_alt  = { fg = "#4c566a" }
select_main = { fg = "#2e3440", bg = "#88c0d0" }
select_alt  = { fg = "#2e3440", bg = "#5e81ac" }
unset_main  = { fg = "#4c566a" }
unset_alt   = { fg = "#434c5e" }

[status]
separator_open  = "▏"
separator_close = "▕"

progress_label  = { fg = "#d8dee9" }
progress_normal = { fg = "#88c0d0" }
progress_error  = { fg = "#bf616a" }

perm_sep   = { fg = "#4c566a" }
perm_type  = { fg = "#ebcb8b" }
perm_read  = { fg = "#a3be8c" }
perm_write = { fg = "#d08770" }
perm_exec  = { fg = "#81a1c1" }

[input]
border   = { fg = "#88c0d0" }
title    = { fg = "#88c0d0" }
value    = { fg = "#d8dee9" }
selected = { fg = "#2e3440", bg = "#88c0d0" }

[confirm]
border     = { fg = "#88c0d0" }
title      = { fg = "#88c0d0" }
content    = { fg = "#d8dee9" }
list       = { fg = "#d8dee9" }
btn_yes    = { fg = "#2e3440", bg = "#a3be8c" }
btn_no     = { fg = "#2e3440", bg = "#bf616a" }
btn_labels = [ "  [Y]es  ", "  (N)o  " ]

[pick]
border   = { fg = "#88c0d0" }
active   = { fg = "#2e3440", bg = "#88c0d0" }
inactive = { fg = "#d8dee9" }

[completion]
border       = { fg = "#88c0d0" }
active       = { fg = "#2e3440", bg = "#88c0d0" }
inactive     = { fg = "#d8dee9" }
icon_file    = ""
icon_folder  = ""
icon_command = ""

[tasks]
border  = { fg = "#88c0d0" }
title   = { fg = "#88c0d0" }
hovered = { fg = "#b48ead", underline = true }

[which]
cols            = 3
mask            = { fg = "#2e3440", bg = "#88c0d0" }
cand            = { fg = "#88c0d0" }
rest            = { fg = "#d8dee9" }
desc            = { fg = "#d8dee9" }
separator       = " "
separator_style = { fg = "#4c566a" }

[help]
on      = { fg = "#88c0d0" }
run     = { fg = "#b48ead" }
desc    = { fg = "#d8dee9" }
hovered = { fg = "#ebcb8b", underline = true }
footer  = { fg = "#4c566a" }

[notify]
title_info  = { fg = "#2e3440", bg = "#88c0d0" }
title_warn  = { fg = "#2e3440", bg = "#ebcb8b" }
title_error = { fg = "#2e3440", bg = "#bf616a" }
icon_info   = ""
icon_warn   = ""
icon_error  = ""

[filetype]
rules = [
	{ mime = "image/*", fg = "#ebcb8b" },
	{ mime = "{audio,video}/*", fg = "#b48ead" },
	{ mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}", fg = "#d08770" },
	{ mime = "application/{pdf,doc,rtf}", fg = "#88c0d0" },

	{ name = "*.{c,cc,cpp,cxx,h,hh,hpp,hxx}", fg = "#81a1c1" },
	{ name = "*.{urdf,xacro,sdf}", fg = "#8fbcbb" },
	{ name = "*.{launch,launch.py}", fg = "#8fbcbb" },
	{ name = "*.{msg,srv,action}", fg = "#8fbcbb" },
	{ name = "CMakeLists.txt", fg = "#88c0d0" },
	{ name = "*.cmake", fg = "#88c0d0" },
	{ name = "*.py", fg = "#ebcb8b" },
	{ name = "*.{sh,bash,zsh,fish}", fg = "#a3be8c" },
	{ name = "*.{json,yaml,yml,toml,xml}", fg = "#8fbcbb" },
	{ name = "*.md", fg = "#d8dee9" },

	{ name = "*", is = "orphan", bg = "#bf616a" },
	{ name = "*", is = "exec"  , fg = "#a3be8c" },
	{ name = "*", is = "dummy", bg = "#bf616a" },
	{ name = "*/", is = "dummy", bg = "#bf616a" },

	{ name = "*/", fg = "#88c0d0" }
]
```

### `~/.gitconfig`

```ini
[user]
	name = right-ear
	email = right-ear@users.noreply.github.com

[init]
	defaultBranch = main

[core]
	editor = nvim
	pager = less
	excludesFile = ~/.config/git/ignore
	attributesFile = ~/.config/git/attributes
	precomposeUnicode = true

[push]
	default = simple
	autoSetupRemote = true

[pull]
	rebase = false

[fetch]
	prune = true

[merge]
	conflictstyle = zdiff3

[diff]
	algorithm = histogram
	renames = copies
	colorMoved = zebra
	mnemonicPrefix = true

[rerere]
	enabled = true
	autoupdate = true

[alias]
	st = status --short --branch
	lg = log --graph --oneline --decorate --all
	lga = log --graph --oneline --decorate --all --author-date-order
	la = log --oneline --decorate -n 20 --all --stat
	unstage = restore --staged
	br = branch -vv
	co = checkout
	cb = checkout -b
	sw = switch
	aa = add --all
	ap = add --patch
	unst = reset
	amend = commit --amend --no-edit
	last = log -1 HEAD --stat
	up = pull --ff-only
	pushf = push --force-with-lease
	stash = stash push
	stashp = stash pop
	subup = submodule update --init --recursive
	blame = blame --date=relative
	difftool = diff --color=always
	big = rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | awk '$1=="blob" {print $3, $4}' | sort -rn | head -20
	rosfind = !fdfind -t f -e cpp -e hpp -e h -e py -e xml -e yaml -e launch.py . src 2>/dev/null || find . -name '*.cpp' -o -name '*.hpp' -o -name '*.py' -o -name '*.yaml' -o -name '*.xml'

[color]
	ui = auto

[credential]
	helper = cache --timeout=3600
```

### `~/.config/git/ignore`

```
# ---------- C / C++ build output ----------
*.o
*.obj
*.a
*.lib
*.so
*.so.*
*.dylib
*.dll
*.exe
*.out
*.app

# CMake
CMakeCache.txt
CMakeFiles/
CMakeScripts/
cmake_install.cmake
CTestTestfile.cmake
install_manifest.txt
compile_commands.json
*.cmake.stamp*
_deps/
CMakeUserPresets.json

# Ninja / Make
.ninja_deps
.ninja_log
build.ninja
rules.ninja
*.ninja
Makefile

# Conan / vcpkg
conan.lock
conanbuildinfo.*
vcpkg_installed/

# ---------- ROS 2 ----------
install/
log/
build/
*.roslog
rclcpp.log
*_log/

# ---------- Python ----------
__pycache__/
*.py[cod]
*.egg-info/
.venv/
venv/
env/
.pytest_cache/
.mypy_cache/
.ruff_cache/
pip-wheel-metadata/

# ---------- Node / general ----------
node_modules/
npm-debug.log*

# ---------- Editors ----------
.vscode/*
!.vscode/settings.json
.idea/
*.swp
*.swo
*~
.DS_Store

# ---------- Build / artifacts ----------
*.tar.gz
*.zip
*.bin
*.img
*.iso
core
core.*

# ---------- GDB ----------
gdb_history
*.gdb_history

# ---------- Credentials ----------
.env
.env.local
*.pem
*.key
credentials.json
secrets.yaml
```

### `~/.config/git/attributes`

```
* text=auto eol=lf

*.c      text diff=cpp
*.cpp    text diff=cpp
*.cc     text diff=cpp
*.cxx    text diff=cpp
*.h      text diff=cpp
*.hpp    text diff=cpp
*.hh     text diff=cpp
*.hxx    text diff=cpp
*.inl    text diff=cpp
*.ipp    text diff=cpp
*.cu     text diff=cpp
*.cuh    text diff=cpp

CMakeLists.txt     text
*.cmake           text
*.cmake.in        text eol=lf

*.py       text diff=python
*.pyi      text diff=python
pyproject.toml   text

*.yaml      text
*.yml       text
*.xml       text
*.urdf      text
*.xacro     text
*.sdf       text
*.rviz      text
*.launch.py text diff=python

*.sh       text eol=lf
*.zsh      text eol=lf
*.bash     text eol=lf
*.json     text
*.toml     text
*.md       text

*.so      binary
*.a       binary
*.o       binary
*.png     binary
*.jpg     binary
*.pdf     binary
*.dae     binary
*.stl     binary
*.urdf.gz binary
*.launch   binary
```

### `~/.clang-format`

```yaml
---
Language: Cpp
BasedOnStyle: LLVM
Standard: c++17
IndentWidth: 4
TabWidth: 4
UseTab: Never
ColumnLimit: 100
AccessModifierOffset: -2
AlignAfterOpenBracket: Align
AllowShortFunctionsOnASingleLine: Inline
AllowShortIfStatementsOnASingleLine: false
AllowShortLoopsOnASingleLine: false
AlwaysBreakTemplateDeclarations: Yes
BreakBeforeBraces: Attach
PointerAlignment: Right
SortIncludes: true
IncludeBlocks: Preserve
DerivePointerAlignment: false
SpaceAfterTemplateKeyword: false
...
```

### `~/.colcon_defaults`

```yaml
build:
  symlink-install: true
  parallel-workers: 2
  event-handlers:
    - console_direct+
```

### `~/.zshrc`

```zsh
# ============================================================
#  zsh configuration — robot arm / C++ / ROS 2 development
# ============================================================

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    fast-syntax-highlighting
    zsh-completions
    sudo
    extract
    colored-man-pages
    command-not-found
    copypath
    copyfile
    web-search
)

source $ZSH/oh-my-zsh.sh

if [ -f "$ZSH/custom/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" ]; then
    source "$ZSH/custom/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
fi

# ============================================================
#  Environment
# ============================================================
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less"
export LESS="-R -F -X"

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

source /opt/ros/humble/setup.zsh 2>/dev/null || true
if [ -d "$HOME/ros2_ws/install" ]; then
    source "$HOME/ros2_ws/install/setup.zsh" 2>/dev/null || true
fi

export ROS_LOCALHOST_ONLY=1
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"
export COLCON_DEFAULTS_FILE="$HOME/.colcon_defaults"

export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"
export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-0}"
export QT_X11_NO_MITSHM=1

export PYTHONPATH="$PYTHONPATH:$HOME/ros2_ws/install/rosidl_generator_py:$HOME/ros2_ws/install"

export MAKEFLAGS="-j$(nproc)"
export CMAKE_BUILD_PARALLEL_LEVEL=$(nproc)

if command -v ccache >/dev/null 2>&1; then
    export PATH="/usr/lib/ccache:$PATH"
fi

if command -v lesspipe >/dev/null 2>&1; then
    export LESS='-R -F -X -i'
fi

# ============================================================
#  Aliases
# ============================================================
alias ls="ls --color=auto -h"
alias ll="ls -lah --color=auto"
alias la="ls -A --color=auto"
alias l="ls -CF --color=auto"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias -- -="cd -"
alias c="clear"
alias h="history"

# ---- Git ----
alias gst="git status"
alias gsta="git status --short --branch"
alias glg="git log --oneline --graph --decorate -n 20"
alias gd="git diff"
alias gds="git diff --staged"
alias ga="git add"
alias gco="git checkout"
alias gcb="git checkout -b"
alias gp="git push"
alias gpl="git pull"
alias gr="git rebase"
alias gm="git merge"
alias gcl="git clone"
alias gf="git fetch --all --prune"

# ---- ROS 2 ----
alias rosinfo="printenv | grep -i ros"
alias rosnodes="ros2 node list"
alias rostopics="ros2 topic list"
alias rosservices="ros2 service list"
alias rosparams="ros2 param list"
alias rosbag="ros2 bag"
alias rosdep="rosdep"
alias colb="colcon build --symlink-install"
alias colbt="colcon build --symlink-install --packages-select"
alias coltest="colcon test --event-handlers console_direct+"
alias source_ws="source ~/ros2_ws/install/setup.zsh"
alias ws="cd ~/ros2_ws"
alias wssrc="cd ~/ros2_ws/src"

# ---- Build & debug ----
alias ccmake="cmake -S . -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_EXPORT_COMPILE_COMMANDS=ON"
alias cmakeb="cmake --build build -j$(nproc)"
alias cgdb="gdb --args"
alias gdbq="gdb -q"

# ---- Files ----
if command -v bat >/dev/null 2>&1; then
    alias bat="bat --paging=never"
elif command -v batcat >/dev/null 2>&1; then
    alias bat="batcat --paging=never"
fi
alias catf="bat --style=plain --paging=never"
alias ffind="fdfind"
alias fgrep="rg --hidden --glob '!.git'"
alias tree="tree -C --dirsfirst"

# ============================================================
#  Functions
# ============================================================
mkcd() { mkdir -p "$1" && cd "$1"; }

buildpkg() {
    if [ -z "$1" ]; then
        echo "usage: buildpkg <package_name>"
        return 1
    fi
    colcon build --symlink-install --packages-select "$1" "$@" && \
        echo "--- sourcing ---" && \
        source ~/ros2_ws/install/setup.zsh && \
        echo "done: $1"
}

use_ros() {
    source /opt/ros/humble/setup.zsh
    [ -d ~/ros2_ws/install ] && source ~/ros2_ws/install/setup.zsh
    echo "ROS 2 Humble sourced."
}

findnode() { ros2 node list | grep -i "$1"; }

follow() {
    if [ -z "$1" ]; then
        echo "usage: follow <topic_name>"
        return 1
    fi
    ros2 topic echo "$1"
}

record() {
    if [ -z "$1" ]; then
        echo "usage: record <bag_name> [topics...]"
        return 1
    fi
    local name=$1; shift
    ros2 bag record -o "$name" "$@"
}

which_ros() {
    echo "ROS_DISTRO=$ROS_DISTRO"
    echo "ROS_DOMAIN_ID=$ROS_DOMAIN_ID"
    echo "Workspace: ${ROS_WS:-~/ros2_ws}"
}

y() {
    local tmp="$(mktemp -t yazi-cwd.XXXXXX)" cwd
    yazi "$@" >/dev/null 2>&1
    cwd="$(command cat -- "$tmp")"
    [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && cd -- "$cwd"
    rm -f -- "$tmp"
}

# ============================================================
#  Completion
# ============================================================
autoload -Uz compinit && compinit -i
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS HIST_VERIFY SHARE_HISTORY

setopt AUTO_CD INTERACTIVE_COMMENTS AUTO_PUSHD PUSHD_IGNORE_DUPS
setopt EXTENDED_GLOB NO_NOMATCH
setopt COMPLETE_IN_WORD ALWAYS_TO_END PROMPT_SUBST

bindkey -e
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^{/^' backward-kill-word

# ---- User binaries (nvim, yazi) ----
export PATH="$HOME/bin:$PATH"
```

### `~/.p10k.zsh`

Powerlevel10k configuration. The file ships with p10k as
`config/p10k-classic.zsh`; this version adds three custom segments for
C++/ROS 2 work.

The custom segments live **inside** the config file's `() { ... }` wrapper —
that is what makes them global. Names must be `prompt_<name>`.

```zsh
  # ============================================================
  #  Custom segments for C++ / ROS 2 development
  # ============================================================

  # ROS 2 distro — shown whenever a ROS environment is active.
  function prompt_ros_distro() {
    if [[ -n ${ROS_DISTRO-} ]]; then
      p10k segment -f 76 -i '🌿' -t "$ROS_DISTRO"
    fi
  }

  # ROS 2 workspace — detected by looking for a src/ directory that
  # contains ROS packages (a package.xml). $ROS_WS is only set during a
  # colcon build, so path detection is used instead.
  function prompt_ros_workspace() {
    local dir=$PWD
    while [[ $dir != "/" ]]; do
      if [[ -d $dir/src ]]; then
        # Only treat it as a ROS workspace if it holds real ROS packages.
        local pkg=( $dir/src/*/package.xml(N) )
        if (( $#pkg )); then
          p10k segment -f 178 -i 'ws' -t 'ros2'
          return
        fi
      fi
      dir=${dir:h}
    done
  }

  # CMake project — shown when the current directory holds a CMakeLists.txt.
  function prompt_cmake_project() {
    if [[ -f CMakeLists.txt ]]; then
      p10k segment -f 44 -i 'cmake' -t 'cmake'
    fi
  }

  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    os_icon               # os identifier
    dir                   # current directory
    vcs                   # git status
    ros_distro            # ROS 2 distro (custom)
    ros_workspace         # ROS workspace (custom)
    cmake_project         # CMake project (custom)
    newline               # \n
    prompt_char           # prompt symbol
  )

  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
    status                # exit code of the last command
    command_execution_time  # duration of the last command
    background_jobs       # presence of background jobs
    virtualenv            # python virtual environment
    nodejs                # node.js version
    context               # current context
  )
```

### `~/.config/tabby/config.yaml`

Nord scheme for Tabby 1.0.238.

```yaml
enableWelcomeTab: false
enableAnalytics: false
hideTray: false

terminal:
  colorSchemeMode: 'dark'
  font: 'Noto Sans Mono CJK SC'
  fontSize: 12
  lineHeight: 1.0
  letterSpacing: 0
  cursorBlink: false
  scrollback: 10000
  copyOnSelect: false
  audibleBell: none
  drawBoldTextInBrightColors: true
  background: 'colorScheme'
  # NOTE: colorScheme is a full object, NOT a scheme name string.
  colorScheme:
    name: 'Nord'
    foreground: '#d8dee9'
    background: '#2e3440'
    selectionBackground: '#434c5e'
    cursor: '#d8dee9'
    cursorAccent: '#2e3440'
    colors:
      - '#3b4252'   # 0  black
      - '#bf616a'   # 1  red
      - '#a3be8c'   # 2  green
      - '#ebcb8b'   # 3  yellow
      - '#81a1c1'   # 4  blue
      - '#b48ead'   # 5  magenta
      - '#88c0d0'   # 6  cyan
      - '#e5e9f0'   # 7  white
      - '#4c566a'   # 8  bright black
      - '#bf616a'   # 9  bright red
      - '#a3be8c'   # 10 bright green
      - '#ebcb8b'   # 11 bright yellow
      - '#81a1c1'   # 12 bright blue
      - '#b48ead'   # 13 bright magenta
      - '#8fbcbb'   # 14 bright cyan
      - '#eceff4'   # 15 bright white

defaultProfile: 'local'

profiles:
  - type: local
    name: local
    options:
      shell: /bin/zsh
      cwd: ~
      colorScheme: Nord

hotkeys:
  split-pane-right:
    - 'Ctrl-Shift-D'
  split-pane-down:
    - 'Ctrl-Shift-E'
  toggle-auxiliary-bar:
    - 'Ctrl-Shift-B'
  search:
    - 'Ctrl-Shift-F'
  copy:
    - 'Ctrl-Shift-C'
  paste:
    - 'Ctrl-Shift-V'
  clear:
    - 'Ctrl-Shift-K'
```

### `robot_arm_core` ROS package

**`package.xml`**

```xml
<?xml version="1.0"?>
<?xml-model href="http://download.ros.org/schema/package_format3.xsd" schematypens="http://www.w3.org/2001/XMLSchema"?>
<package format="3">
  <name>robot_arm_core</name>
  <version>0.0.1</version>
  <description>Core kinematics and utilities for the robot arm</description>
  <maintainer email="right-ear@users.noreply.github.com">right-ear</maintainer>
  <license>MIT</license>

  <buildtool_depend>ament_cmake</buildtool_depend>

  <depend>rclcpp</depend>

  <export>
    <build_type>ament_cmake</build_type>
  </export>
</package>
```

**`CMakeLists.txt`**

```cmake
cmake_minimum_required(VERSION 3.16)
project(robot_arm_core)

if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 17)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
endif()
if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)

add_library(robot_arm_core
  src/kinematics.cpp
)
target_include_directories(robot_arm_core PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>
)
target_compile_features(robot_arm_core PUBLIC cxx_std_17)
ament_target_dependencies(robot_arm_core rclcpp)

add_executable(arm_node src/arm_node.cpp)
target_link_libraries(arm_node robot_arm_core)
ament_target_dependencies(arm_node rclcpp)

install(DIRECTORY include/ DESTINATION include)
install(TARGETS robot_arm_core
  EXPORT export_robot_arm_core
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION bin
)

# ROS 2 convention: executables live in lib/<package_name>/ so that
# `ros2 run <package> <exe>` can find them.
install(TARGETS arm_node
  DESTINATION lib/${PROJECT_NAME}
)

ament_export_include_directories(include)
ament_export_targets(export_robot_arm_core HAS_LIBRARY_TARGET)
ament_export_dependencies(rclcpp)

ament_package()
```

**`include/robot_arm_core/kinematics.hpp`**

```cpp
#ifndef ROBOT_ARM_CORE__KINEMATICS_HPP_
#define ROBOT_ARM_CORE__KINEMATICS_HPP_

#include <array>
#include <cmath>
#include <optional>

namespace robot_arm_core
{

inline constexpr std::size_t kDof = 3;
using JointArray = std::array<double, kDof>;

struct Point2D
{
  double x = 0.0;
  double y = 0.0;
};

class PlanarArmKinematics
{
public:
  explicit PlanarArmKinematics(const std::array<double, kDof> & link_lengths);

  [[nodiscard]] Point2D forward(const JointArray & joint_angles) const;

  /// Damped Newton-Raphson on the position Jacobian.
  [[nodiscard]] bool inverse(
    const Point2D & target,
    JointArray & joint_angles,
    const JointArray & seed = JointArray{0.0, 0.6, 0.6},
    int max_iterations = 200) const;

  /// Closed-form 2-link solve with joint 3 held fixed.
  [[nodiscard]] bool inverseWithFixedQ3(
    const Point2D & target,
    double q3_fixed,
    JointArray & joint_angles,
    bool elbow_up = true) const;

  [[nodiscard]] double max_reach() const;
  [[nodiscard]] double min_reach() const;
  [[nodiscard]] bool is_reachable(const Point2D & target) const;
  [[nodiscard]] std::array<std::array<double, 3>, 2> jacobian(
    const JointArray & joint_angles) const;
  [[nodiscard]] static double normalize_angle(double angle);
  [[nodiscard]] JointArray apply_joint_limits(const JointArray & joint_angles) const;
  void set_joint_limits(const JointArray & lower, const JointArray & upper);

private:
  std::array<double, kDof> link_lengths_;
  JointArray joint_lower_{{-M_PI, -M_PI, -M_PI}};
  JointArray joint_upper_{{M_PI, M_PI, M_PI}};
};

}  // namespace robot_arm_core

#endif  // ROBOT_ARM_CORE__KINEMATICS_HPP_
```

**`src/kinematics.cpp`**

```cpp
#include "robot_arm_core/kinematics.hpp"

#include <algorithm>
#include <cmath>

namespace robot_arm_core
{

PlanarArmKinematics::PlanarArmKinematics(const std::array<double, kDof> & link_lengths)
: link_lengths_(link_lengths)
{
}

Point2D PlanarArmKinematics::forward(const JointArray & q) const
{
  const double a1 = q[0];
  const double a2 = a1 + q[1];
  const double a3 = a2 + q[2];

  return Point2D{
    link_lengths_[0] * std::cos(a1) + link_lengths_[1] * std::cos(a2) +
      link_lengths_[2] * std::cos(a3),
    link_lengths_[0] * std::sin(a1) + link_lengths_[1] * std::sin(a2) +
      link_lengths_[2] * std::sin(a3)};
}

std::array<std::array<double, 3>, 2> PlanarArmKinematics::jacobian(
  const JointArray & q) const
{
  const double a1 = q[0];
  const double a2 = a1 + q[1];
  const double a3 = a2 + q[2];

  std::array<std::array<double, 3>, 2> J{};
  J[0][0] = -link_lengths_[0] * std::sin(a1) -
    link_lengths_[1] * std::sin(a2) - link_lengths_[2] * std::sin(a3);
  J[1][0] = link_lengths_[0] * std::cos(a1) +
    link_lengths_[1] * std::cos(a2) + link_lengths_[2] * std::cos(a3);
  J[0][1] = -link_lengths_[1] * std::sin(a2) - link_lengths_[2] * std::sin(a3);
  J[1][1] = link_lengths_[1] * std::cos(a2) + link_lengths_[2] * std::cos(a3);
  J[0][2] = -link_lengths_[2] * std::sin(a3);
  J[1][2] = link_lengths_[2] * std::cos(a3);
  return J;
}

bool PlanarArmKinematics::inverse(
  const Point2D & target,
  JointArray & joint_angles,
  const JointArray & seed,
  int max_iterations) const
{
  if (!is_reachable(target)) {
    return false;
  }

  JointArray q = apply_joint_limits(seed);

  constexpr double kTolerance = 1e-10;
  constexpr double kDamping = 1e-6;
  constexpr double kMaxStep = 0.5;

  for (int iter = 0; iter < max_iterations; ++iter) {
    const Point2D current = forward(q);
    const double ex = target.x - current.x;
    const double ey = target.y - current.y;
    const double error_norm = std::hypot(ex, ey);

    if (error_norm < kTolerance) {
      joint_angles = q;
      return true;
    }

    const auto J = jacobian(q);

    const double a = J[0][0] * J[0][0] + J[0][1] * J[0][1] + J[0][2] * J[0][2] + kDamping;
    const double b = J[0][0] * J[1][0] + J[0][1] * J[1][1] + J[0][2] * J[1][2];
    const double c = J[1][0] * J[1][0] + J[1][1] * J[1][1] + J[1][2] * J[1][2] + kDamping;

    const double det = a * c - b * b;
    if (std::abs(det) < 1e-14) {
      return false;
    }

    const double inv_00 = c / det;
    const double inv_01 = -b / det;
    const double inv_11 = a / det;

    const double y0 = inv_00 * ex + inv_01 * ey;
    const double y1 = inv_01 * ex + inv_11 * ey;

    double dq0 = J[0][0] * y0 + J[1][0] * y1;
    double dq1 = J[0][1] * y0 + J[1][1] * y1;
    double dq2 = J[0][2] * y0 + J[1][2] * y1;

    const double step_norm = std::abs(dq0) + std::abs(dq1) + std::abs(dq2);
    if (step_norm > kMaxStep) {
      const double scale = kMaxStep / step_norm;
      dq0 *= scale;
      dq1 *= scale;
      dq2 *= scale;
    }

    double scale = 1.0;
    bool improved = false;
    for (int ls = 0; ls < 30; ++ls) {
      const JointArray candidate{
        q[0] + scale * dq0,
        q[1] + scale * dq1,
        q[2] + scale * dq2};
      const Point2D p = forward(candidate);
      if (std::hypot(target.x - p.x, target.y - p.y) < error_norm) {
        q = apply_joint_limits(candidate);
        improved = true;
        break;
      }
      scale *= 0.5;
    }

    if (!improved) {
      const Point2D p = forward(q);
      if (std::hypot(target.x - p.x, target.y - p.y) < 1e-6) {
        joint_angles = q;
        return true;
      }
      return false;
    }
  }

  const Point2D p = forward(q);
  if (std::hypot(target.x - p.x, target.y - p.y) < 1e-7) {
    joint_angles = q;
    return true;
  }
  return false;
}

bool PlanarArmKinematics::inverseWithFixedQ3(
  const Point2D & target,
  double q3_fixed,
  JointArray & joint_angles,
  bool elbow_up) const
{
  double phi = 0.0;
  JointArray q{};

  for (int iter = 0; iter < 50; ++iter) {
    const double a2_dir = phi;
    const double wx = target.x - link_lengths_[2] * std::cos(a2_dir + q3_fixed);
    const double wy = target.y - link_lengths_[2] * std::sin(a2_dir + q3_fixed);

    const double r = std::hypot(wx, wy);
    if (r < 1e-12 || r > link_lengths_[0] + link_lengths_[1] ||
      r < std::abs(link_lengths_[0] - link_lengths_[1]))
    {
      return false;
    }

    const double c2 = (r * r - link_lengths_[0] * link_lengths_[0] -
                 link_lengths_[1] * link_lengths_[1]) /
              (2.0 * link_lengths_[0] * link_lengths_[1]);
    if (c2 < -1.0 || c2 > 1.0) {
      return false;
    }
    const double s2 = elbow_up ? std::sqrt(1.0 - c2 * c2) : -std::sqrt(1.0 - c2 * c2);
    const double q2 = std::atan2(s2, c2);
    const double q1 = std::atan2(wy, wx) -
      std::atan2(link_lengths_[1] * s2, link_lengths_[0] + link_lengths_[1] * c2);

    q = {q1, q2, q3_fixed};

    const double new_phi = q1 + q2;
    if (std::abs(new_phi - phi) < 1e-14) {
      phi = new_phi;
      break;
    }
    phi = new_phi;
  }

  const Point2D p = forward(q);
  if (std::hypot(target.x - p.x, target.y - p.y) > 1e-8) {
    return false;
  }

  joint_angles = apply_joint_limits(q);
  return true;
}

double PlanarArmKinematics::max_reach() const
{
  return link_lengths_[0] + link_lengths_[1] + link_lengths_[2];
}

double PlanarArmKinematics::min_reach() const
{
  const double total = max_reach();
  const double longest = *std::max_element(link_lengths_.begin(), link_lengths_.end());
  return std::max(0.0, longest - (total - longest));
}

bool PlanarArmKinematics::is_reachable(const Point2D & target) const
{
  const double r = std::hypot(target.x, target.y);
  return r <= max_reach() + 1e-9 && r >= min_reach() - 1e-9;
}

double PlanarArmKinematics::normalize_angle(double angle)
{
  constexpr double kTwoPi = 2.0 * M_PI;
  angle = std::fmod(angle + M_PI, kTwoPi);
  if (angle < 0.0) {
    angle += kTwoPi;
  }
  return angle - M_PI;
}

JointArray PlanarArmKinematics::apply_joint_limits(const JointArray & joint_angles) const
{
  JointArray out{};
  for (std::size_t i = 0; i < kDof; ++i) {
    out[i] = std::clamp(joint_angles[i], joint_lower_[i], joint_upper_[i]);
  }
  return out;
}

void PlanarArmKinematics::set_joint_limits(const JointArray & lower, const JointArray & upper)
{
  joint_lower_ = lower;
  joint_upper_ = upper;
}

}  // namespace robot_arm_core
```

**`src/arm_node.cpp`**

```cpp
#include "robot_arm_core/kinematics.hpp"

#include <array>
#include <cmath>
#include <memory>

#include "rclcpp/rclcpp.hpp"

using robot_arm_core::JointArray;
using robot_arm_core::PlanarArmKinematics;
using robot_arm_core::Point2D;

int main(int argc, char ** argv)
{
  rclcpp::init(argc, argv);
  auto node = std::make_shared<rclcpp::Node>("arm_node");

  const PlanarArmKinematics arm({0.30, 0.25, 0.15});

  node->declare_parameter<double>("target_x", 0.40);
  node->declare_parameter<double>("target_y", 0.25);

  const double tx = node->get_parameter("target_x").as_double();
  const double ty = node->get_parameter("target_y").as_double();
  const Point2D target{tx, ty};

  RCLCPP_INFO(
    node->get_logger(), "Arm: l1=0.30 l2=0.25 l3=0.15, reach = [%.3f, %.3f]",
    arm.min_reach(), arm.max_reach());

  if (!arm.is_reachable(target)) {
    RCLCPP_WARN(
      node->get_logger(),
      "Target (%.3f, %.3f) is OUT OF REACH (distance %.3f)", tx, ty,
      std::hypot(tx, ty));
    rclcpp::shutdown();
    return 1;
  }

  JointArray q{};
  if (!arm.inverse(target, q)) {
    RCLCPP_ERROR(node->get_logger(), "IK failed for target (%.3f, %.3f)", tx, ty);
    rclcpp::shutdown();
    return 1;
  }

  const Point2D check = arm.forward(q);
  RCLCPP_INFO(
    node->get_logger(),
    "IK solution: q = [%.4f, %.4f, %.4f] rad", q[0], q[1], q[2]);
  RCLCPP_INFO(
    node->get_logger(),
    "FK check   : (%.6f, %.6f)  (target %.6f, %.6f)  err = %.2e",
    check.x, check.y, tx, ty, std::hypot(check.x - tx, check.y - ty));

  rclcpp::shutdown();
  return 0;
}
```

---

## Agent instructions

If you are an AI agent asked to set up this environment:

1. **Read this document fully before acting.** Do not improvise package names.
2. **Run the [Preflight](#2-preflight--verify-the-machine) first.** If the OS is
   not Ubuntu 22.04 or glibc is not 2.35, stop and tell the user which
   sections need adjusting (Yazi version, Yazi/Neovim binaries).
3. **Work phase by phase, and verify after each one** using the commands
   given. Do not batch everything into one run — failures cascade.
4. **When a GitHub clone fails with 401**, switch to the codeload tarball
   method immediately rather than retrying the git protocol.
5. **Never install a Yazi newer than v0.4.2 on Ubuntu 22.04.**
6. **Never write a ROS setup `source` line into a script using
   `set -u`.**
7. **Ask the user for the sudo password** once, at the start, and reuse it
   for the whole session (e.g. `echo "<password>" | sudo -S -p "" <cmd>`).
8. **Leave the SSH key for the user to register on GitHub** — you cannot do
   that part.
9. Run the [Final verification](#13-final-verification) block and report the
   result honestly, including any ✗.

---

*Created on a working Ubuntu 22.04.5 / ROS 2 Humble machine. Every command
and pitfall in this document was encountered and solved during that setup.*
