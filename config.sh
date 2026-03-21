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

PKG_MANAGER="${PKG_MANAGER:-apk}"
ALTAIR_REPO_URL="${ALTAIR_REPO_URL:-https://dl-cdn.alpinelinux.org/alpine/edge}"

KERNEL_VERSION="${KERNEL_VERSION:-6.6}"
KERNEL_PACKAGE="linux-lts"

ISO_LABEL="ALTAIR_${DISTRO_VERSION}"
ISO_FILENAME="${OUT_DIR}/altair-linux-${DISTRO_VERSION}-${DISTRO_ARCH}.iso"

GH_REPO="${GH_REPO:-altair-linux/Altair-Linux}"
GH_RELEASE_TAG="${GH_RELEASE_TAG:-v${DISTRO_VERSION}}"

MAKE_JOBS="${MAKE_JOBS:-$(nproc 2>/dev/null || echo 4)}"

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
