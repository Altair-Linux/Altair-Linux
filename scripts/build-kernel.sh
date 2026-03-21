#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

section "Installing kernel"

require_cmd apk
require_cmd chroot

apk add \
    --root "${ROOTFS_DIR}" \
    --no-cache \
    --repository "${ALTAIR_REPO_URL}/main" \
    --repository "${ALTAIR_REPO_URL}/community" \
    "${KERNEL_PACKAGE}" \
    "${KERNEL_PACKAGE}-dev" \
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

chroot "${ROOTFS_DIR}" mkinitfs -o /boot/initramfs "${KVER}"

if [[ ! -f "${ROOTFS_DIR}/boot/initramfs" ]]; then
    die "initramfs not found after mkinitfs"
fi

if [[ ! -f "${ROOTFS_DIR}/boot/vmlinuz-lts" ]]; then
    die "kernel image not found at /boot/vmlinuz-lts"
fi

section "Kernel and initramfs ready"
