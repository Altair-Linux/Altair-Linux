#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

section "Installing kernel"

require_cmd chroot

ASTRA="${REPO_ROOT}/.astra-src/target/release/astra"

"${ASTRA}" install \
    linux-lts \
    linux-firmware-none \
    mkinitfs \
    --data-dir "${ASTRA_DATA_DIR}" \
    --root     "${ROOTFS_DIR}" \
    2>/dev/null || true

if [[ ! -d "${ROOTFS_DIR}/lib/modules" ]] || \
   [[ -z "$(ls "${ROOTFS_DIR}/lib/modules/" 2>/dev/null)" ]]; then
    section "Kernel not in Altair repo — installing from Alpine apk into rootfs"
    apk add \
        --root "${ROOTFS_DIR}" \
        --initdb \
        --no-cache \
        --repository https://dl-cdn.alpinelinux.org/alpine/v3.19/main \
        linux-lts \
        linux-firmware-none \
        mkinitfs
fi

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
