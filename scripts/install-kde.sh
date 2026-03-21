#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

section "Installing KDE Plasma and SDDM"

require_cmd apk

KDE_PACKAGES=(
    plasma-desktop
    plasma-workspace
    plasma-nm
    plasma-pa
    plasma-systemmonitor
    kscreen
    kwin
    knotifications
    kio
    kio-extras
    solid
    sddm
    sddm-kcm
    konsole
    dolphin
    kate
    gwenview
    ark
    networkmanager
    networkmanager-wifi
    wpa_supplicant
    polkit
    polkit-kde-agent-1
    udisks2
    powerdevil
    bluedevil
    breeze
    breeze-icons
    oxygen-icons
    plasma-integration
    qt6-qtbase
    qt6-qtbase-x11
    qt6-qtdeclarative
    qt6-qtwayland
    pipewire
    pipewire-alsa
    pipewire-pulse
    wireplumber
)

apk add \
    --root "${ROOTFS_DIR}" \
    --no-cache \
    --repository "${ALTAIR_REPO_URL}/main" \
    --repository "${ALTAIR_REPO_URL}/community" \
    "${KDE_PACKAGES[@]}"

mkdir -p "${ROOTFS_DIR}/etc/sddm.conf.d"

cat > "${ROOTFS_DIR}/etc/sddm.conf.d/altair.conf" << EOF
[Autologin]
Relogin=false

[General]
HaltCommand=/sbin/poweroff
RebootCommand=/sbin/reboot

[Theme]
Current=breeze

[Users]
MaximumUid=60000
MinimumUid=1000
EOF

mkdir -p "${ROOTFS_DIR}/etc/xdg"

cat > "${ROOTFS_DIR}/etc/xdg/startkde" << EOF
#!/bin/sh
export DESKTOP_SESSION=plasma
exec startplasma-x11
EOF
chmod +x "${ROOTFS_DIR}/etc/xdg/startkde"

chroot "${ROOTFS_DIR}" rc-update add sddm default     2>/dev/null || true
chroot "${ROOTFS_DIR}" rc-update add networkmanager default 2>/dev/null || true
chroot "${ROOTFS_DIR}" rc-update add dbus default     2>/dev/null || true
chroot "${ROOTFS_DIR}" rc-update add udev sysinit     2>/dev/null || true

section "KDE Plasma and SDDM install complete"
