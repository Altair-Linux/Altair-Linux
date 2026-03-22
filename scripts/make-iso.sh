#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

section "Assembling ISO"

require_cmd grub-mkrescue
require_cmd mksquashfs
require_cmd xorriso

ensure_dir "${ISO_STAGING_DIR}/boot/grub"
ensure_dir "${ISO_STAGING_DIR}/live"
ensure_dir "${OUT_DIR}"

section "Creating squashfs root image"

mksquashfs "${ROOTFS_DIR}" "${ISO_STAGING_DIR}/live/filesystem.squashfs" \
    -comp xz \
    -Xbcj x86 \
    -b 1048576 \
    -noappend \
    -e "${ROOTFS_DIR}/proc" \
    -e "${ROOTFS_DIR}/sys" \
    -e "${ROOTFS_DIR}/dev"

cp "${ROOTFS_DIR}/boot/vmlinuz-lts"  "${ISO_STAGING_DIR}/boot/vmlinuz"
cp "${ROOTFS_DIR}/boot/initramfs"    "${ISO_STAGING_DIR}/boot/initramfs"

cat > "${ISO_STAGING_DIR}/boot/grub/grub.cfg" << EOF
set default=0
set timeout=5

menuentry "${DISTRO_NAME} ${DISTRO_VERSION}" {
    linux  /boot/vmlinuz quiet splash root=live:/dev/disk/by-label/${ISO_LABEL} live-media-path=/live
    initrd /boot/initramfs
}

menuentry "${DISTRO_NAME} ${DISTRO_VERSION} (safe mode)" {
    linux  /boot/vmlinuz nomodeset root=live:/dev/disk/by-label/${ISO_LABEL} live-media-path=/live
    initrd /boot/initramfs
}
EOF

section "Generating ISO image"

grub-mkrescue \
    --output="${ISO_FILENAME}" \
    "${ISO_STAGING_DIR}" \
    -- -V "${ISO_LABEL}"

if [[ ! -f "${ISO_FILENAME}" ]]; then
    die "ISO not found after grub-mkrescue: ${ISO_FILENAME}"
fi

ISO_SIZE="$(du -sh "${ISO_FILENAME}" | cut -f1)"
section "ISO ready: ${ISO_FILENAME} (${ISO_SIZE})"
