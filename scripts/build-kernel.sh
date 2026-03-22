#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

require_cmd make

KERNEL_MAJOR="${KERNEL_VERSION%%.*}"
KERNEL_FULL="${KERNEL_VERSION}"
KERNEL_SRC_URL="https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_MAJOR}.x/linux-${KERNEL_FULL}.tar.xz"
KERNEL_BUILD_DIR="${REPO_ROOT}/.kernel-build"
KERNEL_SRC_DIR="${KERNEL_BUILD_DIR}/linux-${KERNEL_FULL}"

ensure_dir "${KERNEL_BUILD_DIR}"

section "Downloading kernel source ${KERNEL_FULL}"

TARBALL="${KERNEL_BUILD_DIR}/linux-${KERNEL_FULL}.tar.xz"
if [[ ! -f "${TARBALL}" ]]; then
    curl -fL "${KERNEL_SRC_URL}" -o "${TARBALL}"
fi

TARBALL_SIZE=$(stat -c%s "${TARBALL}" 2>/dev/null || echo 0)
[[ "${TARBALL_SIZE}" -lt 10000000 ]] && die "Tarball too small — download likely failed"

section "Extracting kernel source"

if [[ ! -d "${KERNEL_SRC_DIR}" ]]; then
    tar -xf "${TARBALL}" -C "${KERNEL_BUILD_DIR}"
fi

section "Configuring kernel"

cd "${KERNEL_SRC_DIR}"

make defconfig
make kvm_guest.config 2>/dev/null || true
make olddefconfig

./scripts/config --module CONFIG_SQUASHFS
./scripts/config --enable  CONFIG_SQUASHFS_XZ
./scripts/config --module CONFIG_OVERLAY_FS
./scripts/config --module CONFIG_EXT4_FS
./scripts/config --module CONFIG_VFAT_FS
./scripts/config --enable  CONFIG_FAT_FS
./scripts/config --enable  CONFIG_TMPFS
./scripts/config --enable  CONFIG_DEVTMPFS
./scripts/config --enable  CONFIG_DEVTMPFS_MOUNT
./scripts/config --enable  CONFIG_FB
./scripts/config --enable  CONFIG_DRM
./scripts/config --enable  CONFIG_DRM_VIRTIO_GPU
./scripts/config --enable  CONFIG_VIRTIO
./scripts/config --enable  CONFIG_VIRTIO_PCI
./scripts/config --enable  CONFIG_VIRTIO_NET
./scripts/config --enable  CONFIG_VIRTIO_BLK

make olddefconfig

section "Building kernel (this takes a while)"

make -j"${MAKE_JOBS}" bzImage modules HOSTCFLAGS="-std=gnu11" CFLAGS_KERNEL="-std=gnu11"

section "Installing kernel and modules into rootfs"

make INSTALL_MOD_PATH="${ROOTFS_DIR}" modules_install

mkdir -p "${ROOTFS_DIR}/boot"
cp arch/x86/boot/bzImage "${ROOTFS_DIR}/boot/vmlinuz-lts"

KVER="$(make -s kernelrelease)"
echo "Kernel version: ${KVER}"

section "Installing kernel modules to host for dracut"

mkdir -p /lib/modules
make modules_install

section "Building initramfs"

require_cmd dracut

dracut \
    --force \
    --kver "${KVER}" \
    --add "base rootfs-block" \
    --filesystems "squashfs overlay ext4 vfat" \
    --no-hostonly \
    "${ROOTFS_DIR}/boot/initramfs"

[[ -f "${ROOTFS_DIR}/boot/initramfs" ]] \
    || die "initramfs not found"

[[ -f "${ROOTFS_DIR}/boot/vmlinuz-lts" ]] \
    || die "kernel image not found"

section "Kernel and initramfs ready — ${KVER}"
