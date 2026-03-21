#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

require_cmd cargo

section "Building Astra from source"

ASTRA_SRC="${REPO_ROOT}/.astra-src"
if [[ ! -d "${ASTRA_SRC}/.git" ]]; then
    git clone --depth=1 "${ASTRA_REPO_URL}" "${ASTRA_SRC}"
else
    git -C "${ASTRA_SRC}" pull --ff-only
fi

cargo build --release --manifest-path "${ASTRA_SRC}/Cargo.toml"
ASTRA="${ASTRA_SRC}/target/release/astra"

section "Cloning Altair packages repo"

if [[ ! -d "${PACKAGES_DIR}/.git" ]]; then
    git clone --depth=1 "${PACKAGES_REPO_URL}" "${PACKAGES_DIR}"
else
    git -C "${PACKAGES_DIR}" pull --ff-only
fi

bash "${SCRIPTS_DIR}/patch-recipes.sh"

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

section "Building bootstrap packages from source"

for pkg in "${BOOTSTRAP_PACKAGES[@]}"; do
    [[ "${pkg}" == "astra" ]] && continue
    if [[ ! -d "${PACKAGES_DIR}/${pkg}" ]]; then
        echo "WARNING: recipe not found for ${pkg}, skipping"
        continue
    fi

    echo "--> Building ${pkg}"
    "${ASTRA}" build "${PACKAGES_DIR}/${pkg}" \
        --output   "${PACKAGES_OUT_DIR}" \
        --data-dir "${ASTRA_DATA_DIR}" \
        --root     "${ASTRA_ROOT_DIR}" \
        || { echo "ERROR: astra build failed for ${pkg}"; exit 1; }

    echo "    Output dir contents after ${pkg}:"
    ls -1 "${PACKAGES_OUT_DIR}/" || true

    astpkg="$(ls "${PACKAGES_OUT_DIR}/${pkg}"-*.astpkg 2>/dev/null | head -1 || true)"
    if [[ -z "${astpkg}" ]]; then
        echo "ERROR: astra build exited 0 for ${pkg} but no .astpkg was produced."
        echo "Full output dir:"
        find "${PACKAGES_OUT_DIR}" -type f || true
        exit 1
    fi
    echo "    Produced: $(basename "${astpkg}")"
done

section "Installing bootstrap packages into rootfs"

installed=0
for pkg in "${BOOTSTRAP_PACKAGES[@]}"; do
    [[ "${pkg}" == "astra" ]] && continue
    astpkg="$(ls "${PACKAGES_OUT_DIR}/${pkg}"-*.astpkg 2>/dev/null | head -1 || true)"
    if [[ -z "${astpkg}" ]]; then
        echo "WARNING: no .astpkg found for ${pkg}, skipping"
        continue
    fi
    echo "--> Installing $(basename "${astpkg}")"
    "${ASTRA}" install "${astpkg}" \
        --data-dir "${ASTRA_DATA_DIR}" \
        --root     "${ROOTFS_DIR}"
    installed=$((installed + 1))
done

echo "Installed ${installed} package(s) into rootfs"
[[ "${installed}" -eq 0 ]] && die "No packages were installed into rootfs"

section "Installing Astra binary into rootfs"
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
