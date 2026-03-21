#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

require_cmd curl
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

section "Fetching pre-built packages from Altair-Linux/packages CI"

ensure_dir "${PACKAGES_OUT_DIR}"

PACKAGES_API="https://api.github.com/repos/Altair-Linux/packages/actions/artifacts"
ARTIFACTS_JSON="${PACKAGES_OUT_DIR}/artifacts.json"

curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    "${PACKAGES_API}?per_page=10&name=astra-packages" \
    -o "${ARTIFACTS_JSON}"

ARTIFACT_URL="$(grep -o '"archive_download_url":"[^"]*"' "${ARTIFACTS_JSON}" | head -1 | cut -d'"' -f4)"

if [[ -z "${ARTIFACT_URL}" ]]; then
    die "Could not find astra-packages artifact in Altair-Linux/packages. Ensure the packages CI has run successfully."
fi

echo "Downloading packages artifact: ${ARTIFACT_URL}"

curl -fsSL \
    -H "Authorization: Bearer ${GITHUB_TOKEN:-}" \
    -H "Accept: application/vnd.github+json" \
    -L "${ARTIFACT_URL}" \
    -o "${PACKAGES_OUT_DIR}/packages.zip"

cd "${PACKAGES_OUT_DIR}"
unzip -o packages.zip
cd "${REPO_ROOT}"

echo "Downloaded packages:"
ls -1 "${PACKAGES_OUT_DIR}"/*.astpkg 2>/dev/null || die "No .astpkg files found after download"

section "Initialising Astra"

ensure_dir "${ASTRA_DATA_DIR}"
ensure_dir "${ASTRA_ROOT_DIR}"

"${ASTRA}" init \
    --data-dir "${ASTRA_DATA_DIR}" \
    --root     "${ASTRA_ROOT_DIR}"

"${ASTRA}" key generate \
    --data-dir "${ASTRA_DATA_DIR}" \
    --root     "${ASTRA_ROOT_DIR}"

section "Installing bootstrap packages into rootfs"

installed=0
for pkg in "${BOOTSTRAP_PACKAGES[@]}"; do
    [[ "${pkg}" == "astra" ]] && continue
    astpkg="$(ls "${PACKAGES_OUT_DIR}/${pkg}"-*.astpkg 2>/dev/null | head -1)"
    if [[ -z "${astpkg}" ]]; then
        echo "WARNING: no .astpkg found for ${pkg}, skipping"
        continue
    fi
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
