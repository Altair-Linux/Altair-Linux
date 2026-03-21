#!/usr/bin/env bash
set -euo pipefail

DISTRO_NAME="Altair Linux"
DISTRO_CODENAME="orion"
DISTRO_VERSION="${DISTRO_VERSION:-0.1.0}"
DISTRO_ARCH="x86_64"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SCRIPTS_DIR="${REPO_ROOT}/scripts"
ROOTFS_DIR="${REPO_ROOT}/rootfs"
ISO_STAGING_DIR="${REPO_ROOT}/iso"
OUT_DIR="${REPO_ROOT}/out"
BRANDING_DIR="${REPO_ROOT}/branding"

BRANDING_REPO_URL="https://github.com/altair-linux/altair-branding"
BRANDING_REPO_BRANCH="main"

ASTRA_REPO_URL="https://github.com/Altair-Linux/Astra"
PACKAGES_REPO_URL="https://github.com/Altair-Linux/packages"

ASTRA_DATA_DIR="${REPO_ROOT}/.astra-ci"
ASTRA_ROOT_DIR="${REPO_ROOT}/.astra-root"
PACKAGES_DIR="${REPO_ROOT}/.packages-src"
PACKAGES_OUT_DIR="${REPO_ROOT}/.packages-out"

KERNEL_VERSION="${KERNEL_VERSION:-6.9.12}"
KERNEL_PACKAGE="linux-headers"

ISO_LABEL="ALTAIR_${DISTRO_VERSION}"
ISO_FILENAME="${OUT_DIR}/altair-linux-${DISTRO_VERSION}-${DISTRO_ARCH}.iso"

GH_REPO="${GH_REPO:-altair-linux/Altair-Linux}"
GH_RELEASE_TAG="${GH_RELEASE_TAG:-v${DISTRO_VERSION}}"

MAKE_JOBS="${MAKE_JOBS:-$(nproc 2>/dev/null || echo 4)}"

BOOTSTRAP_PACKAGES=(
    linux-headers
    musl
    binutils
    gcc
    make
    pkg-config
    patch
    diffutils
    sed
    grep
    coreutils
    findutils
    gawk
    tar
    gzip
    xz
    bzip2
    ncurses
    readline
    bash
    util-linux
    zlib
    openssl
    ca-certificates
    wget
    iproute2
    openssh
    e2fsprogs
    shadow
    astra
    nano
    curl
    htop
    jq
)

die() {
    echo "ERROR: $*" >&2
    exit 1
}

section() {
    echo ""
    echo "==> $*"
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

ensure_dir() {
    mkdir -p "$1"
}
