# ============================================================
#  zsh configuration — robot arm / C++ / ROS 2 development
# ============================================================

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k"

# ---- Powerlevel10k ----
# Powerlevel10k lives in custom/themes/ and must be sourced BEFORE
# oh-my-zsh.sh, because it sets up its own prompt (overriding ZSH_THEME).
P10K_DIR="$ZSH/custom/themes/powerlevel10k"
if [ -d "$P10K_DIR" ]; then
    source "$P10K_DIR/powerlevel10k.zsh-theme"
fi

# Load the Powerlevel10k configuration (~/.p10k.zsh).
# This line is required: without it p10k launches its interactive setup
# wizard instead of applying the configuration.
if [ -f "$HOME/.p10k.zsh" ]; then
    source "$HOME/.p10k.zsh"
fi

# ---- Plugins ----
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

if command -v brew >/dev/null 2>&1; then
    plugins+=(brew)
fi
if command -v sdkman >/dev/null 2>&1; then
    plugins+=(sdk)
fi

source $ZSH/oh-my-zsh.sh

# ---- Fast syntax highlighting (must be sourced last of the zsh plugins) ----
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

# ---- Locale ----
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# ---- ROS 2 ----
source /opt/ros/humble/setup.zsh 2>/dev/null || true
if [ -d "$HOME/ros2_ws/install" ]; then
    source "$HOME/ros2_ws/install/setup.zsh" 2>/dev/null || true
fi

# ---- ROS 2 domain / localhost-friendly networking ----
export ROS_LOCALHOST_ONLY=1
export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"

# ---- colcon: use symlink install for fast iteration ----
export COLCON_DEFAULTS_FILE="$HOME/.colcon_defaults"

# ---- Qt / RViz on VMs ----
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"
export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-0}"
export QT_X11_NO_MITSHM=1

# ---- Python ----
export PYTHONPATH="$PYTHONPATH:$HOME/ros2_ws/install/rosidl_generator_py:$HOME/ros2_ws/install"

# ---- Build performance on a 2-core box ----
export MAKEFLAGS="-j$(nproc)"
export CMAKE_BUILD_PARALLEL_LEVEL=$(nproc)

# ---- Ccache for faster rebuilds ----
if command -v ccache >/dev/null 2>&1; then
    export PATH="/usr/lib/ccache:$PATH"
fi

# ---- Colorized less with syntax highlighting ----
if command -v lesspipe >/dev/null 2>&1; then
    export LESS='-R -F -X -i'
fi

# ============================================================
#  Aliases — Navigation & file inspection
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
alias source_ws="[ -f ~/ros2_ws/install/setup.zsh ] && source ~/ros2_ws/install/setup.zsh"
alias ws="[ -d ~/ros2_ws ] && cd ~/ros2_ws || echo 'no workspace (see SETUP.md to recreate)'"
alias wssrc="[ -d ~/ros2_ws/src ] && cd ~/ros2_ws/src || echo 'no workspace'"

# ---- Build & debug ----
alias ccmake="cmake -S . -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_EXPORT_COMPILE_COMMANDS=ON"
alias cmakeb="cmake --build build -j$(nproc)"
alias cgdb="gdb --args"
alias gdbq="gdb -q"
alias dlv="gdb -q -ex 'set pagination off' -ex 'set print pretty on'"

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

# Build one ROS package and source it
buildpkg() {
    if [ -z "$1" ]; then
        echo "usage: buildpkg <package_name>"
        return 1
    fi
    colcon build --symlink-install --packages-select "$1" "$@" && \
        echo "--- sourcing ---" && \
        [ -f ~/ros2_ws/install/setup.zsh ] && source ~/ros2_ws/install/setup.zsh && \
        echo "done: $1"
}

# Find and source the ROS setup file
use_ros() {
    source /opt/ros/humble/setup.zsh
    [ -f ~/ros2_ws/install/setup.zsh ] && source ~/ros2_ws/install/setup.zsh
    echo "ROS 2 Humble sourced."
}

# Find a ROS node by name
findnode() { ros2 node list | grep -i "$1"; }

# Follow a ROS topic live
follow() {
    if [ -z "$1" ]; then
        echo "usage: follow <topic_name>"
        return 1
    fi
    ros2 topic echo "$1"
}

# Record a ROS bag
record() {
    if [ -z "$1" ]; then
        echo "usage: record <bag_name> [topics...]"
        return 1
    fi
    local name=$1; shift
    ros2 bag record -o "$name" "$@"
}

# Check which ROS distro is active
which_ros() {
    echo "ROS_DISTRO=$ROS_DISTRO"
    echo "ROS_DOMAIN_ID=$ROS_DOMAIN_ID"
    echo "Workspace: ${ROS_WS:-~/ros2_ws}"
}

# Open a directory in yazi, and cd to the selected file on exit
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

# ---- History ----
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS HIST_VERIFY SHARE_HISTORY

# ---- Navigation options ----
setopt AUTO_CD INTERACTIVE_COMMENTS AUTO_PUSHD PUSHD_IGNORE_DUPS
setopt EXTENDED_GLOB NO_NOMATCH
setopt COMPLETE_IN_WORD ALWAYS_TO_END PROMPT_SUBST

# ---- Key bindings ----
bindkey -e
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^{/^' backward-kill-word


# ---- User binaries (nvim, yazi) ----
export PATH="$HOME/bin:$PATH"
