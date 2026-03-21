#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

section "Cloning Altair packages repo"

if [[ ! -d "${PACKAGES_DIR}/.git" ]]; then
    git clone --depth=1 "${PACKAGES_REPO_URL}" "${PACKAGES_DIR}"
else
    git -C "${PACKAGES_DIR}" pull --ff-only
fi

bash "${SCRIPTS_DIR}/patch-recipes.sh"

section "Building Astra from source"

require_cmd cargo

ASTRA_SRC="${REPO_ROOT}/.astra-src"
if [[ ! -d "${ASTRA_SRC}/.git" ]]; then
    git clone --depth=1 "${ASTRA_REPO_URL}" "${ASTRA_SRC}"
else
    git -C "${ASTRA_SRC}" pull --ff-only
fi

cargo build --release --manifest-path "${ASTRA_SRC}/Cargo.toml"
ASTRA="${ASTRA_SRC}/target/release/astra"

section "Initialising Astra"

ensure_dir "${ASTRA_DATA_DIR}"
ensure_dir "${ASTRA_ROOT_DIR}"
ensure_dir "${PACKAGES_OUT_DIR}"

"${ASTRA}" init \
    --data-dir "${ASTRA_DATA_DIR}" \
    --root     "${ASTRA_ROOT_DIR}"

"${ASTRA}" key generate \
    --data-dir "${ASTRA_DATA_DIR}" \
    --root     "${ASTRA_ROOT_DIR}"

section "Building bootstrap packages"

failed_pkgs=()

for pkg in "${BOOTSTRAP_PACKAGES[@]}"; do
    if [[ "${pkg}" == "astra" ]]; then
        continue
    fi
    if [[ ! -d "${PACKAGES_DIR}/${pkg}" ]]; then
        echo "WARNING: recipe not found for ${pkg}, skipping"
        continue
    fi
    echo "--> Building ${pkg}"
    if ! "${ASTRA}" build "${PACKAGES_DIR}/${pkg}" \
        --output   "${PACKAGES_OUT_DIR}" \
        --data-dir "${ASTRA_DATA_DIR}" \
        --root     "${ASTRA_ROOT_DIR}" 2>&1; then
        echo "WARNING: astra build failed for ${pkg}"
        failed_pkgs+=("${pkg}")
    fi
done

if [[ ${#failed_pkgs[@]} -gt 0 ]]; then
    echo "The following packages failed to build: ${failed_pkgs[*]}"
fi

echo "Packages produced in ${PACKAGES_OUT_DIR}:"
ls -1 "${PACKAGES_OUT_DIR}"/ || echo "(none)"

section "Installing bootstrap packages into rootfs"

installed=0
for astpkg in "${PACKAGES_OUT_DIR}"/*.astpkg; do
    [[ -f "${astpkg}" ]] || continue
    echo "--> Installing $(basename "${astpkg}")"
    if ! "${ASTRA}" install "${astpkg}" \
        --data-dir "${ASTRA_DATA_DIR}" \
        --root     "${ROOTFS_DIR}" 2>&1; then
        echo "WARNING: install failed for $(basename "${astpkg}")"
    else
        installed=$((installed + 1))
    fi
done

echo "Installed ${installed} package(s) into rootfs"

if [[ "${installed}" -eq 0 ]]; then
    die "No packages were installed into rootfs — build cannot continue"
fi

section "Installing Astra binary directly into rootfs"

install -Dm755 "${ASTRA}" "${ROOTFS_DIR}/usr/bin/astra"

section "Writing base system config"

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
