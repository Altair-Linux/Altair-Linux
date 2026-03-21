#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

section "Installing display stack"

require_cmd apk

DISPLAY_PACKAGES=(
    xorg-server
    xorg-server-common
    xinit
    xf86-input-libinput
    xf86-video-fbdev
    xf86-video-vesa
    mesa
    mesa-dri-gallium
    mesa-gl
    mesa-egl
    libdrm
    libinput
    pixman
    fontconfig
    freetype
    ttf-dejavu
    dbus-x11
    xdpyinfo
    xrandr
    setxkbmap
    xkeyboard-config
)

apk add \
    --root "${ROOTFS_DIR}" \
    --no-cache \
    --repository "${ALTAIR_REPO_URL}/main" \
    --repository "${ALTAIR_REPO_URL}/community" \
    "${DISPLAY_PACKAGES[@]}"

mkdir -p "${ROOTFS_DIR}/etc/X11/xorg.conf.d"

cat > "${ROOTFS_DIR}/etc/X11/xorg.conf.d/10-input.conf" << EOF
Section "InputClass"
    Identifier "libinput"
    MatchIsPointer "on"
    Driver "libinput"
EndSection

Section "InputClass"
    Identifier "libinput keyboard"
    MatchIsKeyboard "on"
    Driver "libinput"
EndSection
EOF

section "Display stack install complete"
