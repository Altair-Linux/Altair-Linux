#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

require_cmd make
require_cmd chroot

KERNEL_MAJOR="6"
KERNEL_FULL="6.9.12"
KERNEL_SRC_URL="https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_MAJOR}.x/linux-${KERNEL_FULL}.tar.xz"
KERNEL_SHA256="b9c4a9951ed39e36d0a5b4b32edfe8d0d0a87cc62b3d1fb74f0de9d19ac07a27"
KERNEL_BUILD_DIR="${REPO_ROOT}/.kernel-build"
KERNEL_SRC_DIR="${KERNEL_BUILD_DIR}/linux-${KERNEL_FULL}"

ensure_dir "${KERNEL_BUILD_DIR}"

section "Downloading kernel source ${KERNEL_FULL}"

TARBALL="${KERNEL_BUILD_DIR}/linux-${KERNEL_FULL}.tar.xz"
if [[ ! -f "${TARBALL}" ]]; then
    curl -fL "${KERNEL_SRC_URL}" -o "${TARBALL}"
fi

echo "${KERNEL_SHA256}  ${TARBALL}" | sha256sum -c -

section "Extracting kernel source"

if [[ ! -d "${KERNEL_SRC_DIR}" ]]; then
    tar -xf "${TARBALL}" -C "${KERNEL_BUILD_DIR}"
fi

section "Configuring kernel"

cd "${KERNEL_SRC_DIR}"

make defconfig
make kvm_guest.config 2>/dev/null || true

cat >> .config << EOF
CONFIG_SQUASHFS=y
CONFIG_SQUASHFS_XZ=y
CONFIG_OVERLAY_FS=y
CONFIG_TMPFS=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_EFI=y
CONFIG_EFI_STUB=y
CONFIG_FB=y
CONFIG_DRM=y
CONFIG_DRM_VIRTIO_GPU=y
CONFIG_VIRTIO=y
CONFIG_VIRTIO_PCI=y
CONFIG_VIRTIO_NET=y
CONFIG_VIRTIO_BLK=y
EOF

make olddefconfig

section "Building kernel (this takes a while)"

make -j"${MAKE_JOBS}" bzImage modules

section "Installing kernel and modules into rootfs"

make INSTALL_MOD_PATH="${ROOTFS_DIR}" modules_install

mkdir -p "${ROOTFS_DIR}/boot"
cp arch/x86/boot/bzImage "${ROOTFS_DIR}/boot/vmlinuz-lts"

KVER="$(make -s kernelrelease)"
echo "Kernel version: ${KVER}"

section "Building initramfs"

require_cmd dracut

dracut \
    --force \
    --kver "${KVER}" \
    --add "base rootfs-block" \
    --filesystems "squashfs overlay ext4 vfat" \
    --host-only-cmdline \
    --no-hostonly \
    --rootdir "${ROOTFS_DIR}" \
    "${ROOTFS_DIR}/boot/initramfs" \
    "${KVER}"

[[ -f "${ROOTFS_DIR}/boot/initramfs" ]] \
    || die "initramfs not found"

[[ -f "${ROOTFS_DIR}/boot/vmlinuz-lts" ]] \
    || die "kernel image not found"

section "Kernel and initramfs ready — ${KVER}"
