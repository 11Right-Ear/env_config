#!/usr/bin/env bash
# ============================================================
#  Launch Tabby on a Wayland session.
#
#  Tabby is an Electron app that talks to X11 directly. On a
#  Wayland desktop it must be routed through the XWayland bridge,
#  otherwise it dies with "Error: Bad window".
#
#  Usage:  launch-tabby
# ============================================================
set -euo pipefail

# --- Work out the X display to use ---
if [ -z "${DISPLAY:-}" ]; then
    for candidate in :0 :1 :2; do
        if [ -e "/tmp/.X11-unix/X${candidate#:}" ]; then
            export DISPLAY="$candidate"
            break
        fi
    done
fi
: "${DISPLAY:?Could not determine the X display for Tabby}"

# --- Force X11 / XWayland ---
export XDG_SESSION_TYPE=x11
export GDK_BACKEND=x11
export ELECTRON_DISABLE_SANDBOX=1
unset WAYLAND_DISPLAY

cd "$HOME"

exec /opt/Tabby/tabby \
    --no-sandbox \
    --disable-gpu \
    --disable-dev-shm-usage \
    --ozone-platform=x11
