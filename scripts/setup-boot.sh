#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

section "Configuring boot environment"

require_cmd chroot

mkdir -p "${ROOTFS_DIR}/boot/grub"
mkdir -p "${ROOTFS_DIR}/etc/default"

cat > "${ROOTFS_DIR}/etc/default/grub" << EOF
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="${DISTRO_NAME}"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_CMDLINE_LINUX=""
GRUB_TERMINAL_INPUT=console
EOF

cat > "${ROOTFS_DIR}/etc/fstab" << EOF
tmpfs   /tmp     tmpfs  defaults,nosuid,nodev  0 0
proc    /proc    proc   defaults               0 0
sysfs   /sys     sysfs  defaults               0 0
devpts  /dev/pts devpts defaults               0 0
EOF

mkdir -p "${ROOTFS_DIR}/proc"
mkdir -p "${ROOTFS_DIR}/sys"
mkdir -p "${ROOTFS_DIR}/dev"

mount --bind /proc "${ROOTFS_DIR}/proc"
mount --bind /sys  "${ROOTFS_DIR}/sys"
mount --bind /dev  "${ROOTFS_DIR}/dev"

cleanup() {
    umount -lf "${ROOTFS_DIR}/proc" 2>/dev/null || true
    umount -lf "${ROOTFS_DIR}/sys"  2>/dev/null || true
    umount -lf "${ROOTFS_DIR}/dev"  2>/dev/null || true
}
trap cleanup EXIT

chroot "${ROOTFS_DIR}" rc-update add bootmisc boot  2>/dev/null || true
chroot "${ROOTFS_DIR}" rc-update add hostname boot  2>/dev/null || true
chroot "${ROOTFS_DIR}" rc-update add modules boot   2>/dev/null || true
chroot "${ROOTFS_DIR}" rc-update add sysctl boot    2>/dev/null || true
chroot "${ROOTFS_DIR}" rc-update add udev sysinit   2>/dev/null || true
chroot "${ROOTFS_DIR}" rc-update add dbus default   2>/dev/null || true
chroot "${ROOTFS_DIR}" rc-update add sddm default   2>/dev/null || true

section "Boot environment configured"
