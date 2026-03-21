#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

section "Configuring Alpine repositories"

mkdir -p "${ROOTFS_DIR}/etc/apk"

cat > "${ROOTFS_DIR}/etc/apk/repositories" << EOF
https://dl-cdn.alpinelinux.org/alpine/v3.19/main
https://dl-cdn.alpinelinux.org/alpine/v3.19/community
EOF

section "Trusting Alpine keys"

apk add --no-cache alpine-keys
apk update

mkdir -p "${ROOTFS_DIR}/etc/apk/keys"
cp /etc/apk/keys/* "${ROOTFS_DIR}/etc/apk/keys/"

section "Installing base system"

BASE_PACKAGES=(
    alpine-base
    musl
    musl-utils
    busybox
    busybox-suid
    openrc
    linux-headers
    binutils
    gcc
    make
    pkgconf
    coreutils
    util-linux
    util-linux-misc
    bash
    tar
    gzip
    xz
    bzip2
    grep
    sed
    gawk
    findutils
    curl
    ca-certificates
    openssl
    iproute2
    dhclient
    iptables
    nano
    shadow
    sudo
    dbus
    eudev
)

apk add \
    --root "${ROOTFS_DIR}" \
    --initdb \
    --no-cache \
    --arch "${DISTRO_ARCH}" \
    --keys-dir "${ROOTFS_DIR}/etc/apk/keys" \
    --repositories-file "${ROOTFS_DIR}/etc/apk/repositories" \
    "${BASE_PACKAGES[@]}"

echo "root:x:0:0:root:/root:/bin/bash" >> "${ROOTFS_DIR}/etc/passwd"
echo "root:!:19000:0:99999:7:::" >> "${ROOTFS_DIR}/etc/shadow"

mkdir -p "${ROOTFS_DIR}/etc/sudoers.d"
echo "%wheel ALL=(ALL) ALL" > "${ROOTFS_DIR}/etc/sudoers.d/wheel"
chmod 0440 "${ROOTFS_DIR}/etc/sudoers.d/wheel"

mkdir -p "${ROOTFS_DIR}/etc/network"
cat > "${ROOTFS_DIR}/etc/network/interfaces" << EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

section "Base system install complete"
