#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

section "Building root filesystem"

ensure_dir "${ROOTFS_DIR}"

for d in bin sbin lib lib64 usr/bin usr/sbin usr/lib \
          etc var/log var/run tmp home root \
          proc sys dev run boot; do
    ensure_dir "${ROOTFS_DIR}/${d}"
done

chmod 1777 "${ROOTFS_DIR}/tmp"
chmod 0750 "${ROOTFS_DIR}/root"

for link in bin sbin lib lib64; do
    if [[ ! -e "${ROOTFS_DIR}/usr/${link}" ]]; then
        ln -s "../${link}" "${ROOTFS_DIR}/usr/${link}"
    fi
done

cat > "${ROOTFS_DIR}/etc/os-release" << EOF
NAME="${DISTRO_NAME}"
VERSION="${DISTRO_VERSION}"
ID=altair
VERSION_CODENAME=${DISTRO_CODENAME}
PRETTY_NAME="${DISTRO_NAME} ${DISTRO_VERSION} (${DISTRO_CODENAME})"
HOME_URL="https://github.com/${GH_REPO}"
EOF

cat > "${ROOTFS_DIR}/etc/hostname" << EOF
altair
EOF

cat > "${ROOTFS_DIR}/etc/hosts" << EOF
127.0.0.1   localhost
127.0.1.1   altair
::1         localhost ip6-localhost ip6-loopback
EOF

section "Rootfs staging complete: ${ROOTFS_DIR}"
