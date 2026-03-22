#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

section "Installing kernel and initramfs tools"

require_cmd chroot

mkdir -p "${ROOTFS_DIR}/etc/apk/keys"
cp /etc/apk/keys/* "${ROOTFS_DIR}/etc/apk/keys/"

cat > "${ROOTFS_DIR}/etc/apk/repositories" << EOF
https://dl-cdn.alpinelinux.org/alpine/edge/main
https://dl-cdn.alpinelinux.org/alpine/edge/community
EOF

apk add \
    --root "${ROOTFS_DIR}" \
    --no-cache \
    --no-network=false \
    linux-lts \
    linux-firmware-none \
    mkinitfs

section "Generating initramfs"

mount --bind /proc "${ROOTFS_DIR}/proc"
mount --bind /sys  "${ROOTFS_DIR}/sys"
mount --bind /dev  "${ROOTFS_DIR}/dev"

cleanup() {
    umount -lf "${ROOTFS_DIR}/proc" 2>/dev/null || true
    umount -lf "${ROOTFS_DIR}/sys"  2>/dev/null || true
    umount -lf "${ROOTFS_DIR}/dev"  2>/dev/null || true
}
trap cleanup EXIT

KVER="$(ls "${ROOTFS_DIR}/lib/modules/" | sort -V | tail -n1)"
echo "Kernel version: ${KVER}"

chroot "${ROOTFS_DIR}" mkinitfs -o /boot/initramfs "${KVER}"

[[ -f "${ROOTFS_DIR}/boot/initramfs" ]] \
    || die "initramfs not found after mkinitfs"

[[ -f "${ROOTFS_DIR}/boot/vmlinuz-lts" ]] \
    || die "kernel image not found at /boot/vmlinuz-lts"

section "Kernel and initramfs ready"
