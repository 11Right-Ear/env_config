#!/usr/bin/env bash
export DISPLAY=:0
export XDG_SESSION_TYPE=x11
export GDK_BACKEND=x11
export ELECTRON_DISABLE_SANDBOX=1
export ELECTRON_ENABLE_LOGGING=1
unset WAYLAND_DISPLAY
cd ~
exec /opt/Tabby/tabby --no-sandbox --disable-gpu --disable-dev-shm-usage --ozone-platform=x11
