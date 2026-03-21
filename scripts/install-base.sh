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

section "Normalising Astrafile.yaml dependency entries"

while IFS= read -r -d '' recipe; do
    awk '
    /^dependencies:/ { in_deps=1; print; next }
    in_deps && /^[^ \t]/ && !/^  -/ { in_deps=0 }
    in_deps && /^  - / {
        line = $0
        # already structured — has "name:" somewhere after the dash
        if (line ~ /name:/) { print line; next }
        # plain string — extract value and rewrite
        match(line, /^(  - )"?([^"]+)"?[ \t]*$/, a)
        if (a[2] != "") {
            printf "  - name: %s\n", a[2]
        } else {
            print line
        }
        next
    }
    { print }
    ' "${recipe}" > "${recipe}.tmp" && mv "${recipe}.tmp" "${recipe}"
done < <(find "${PACKAGES_DIR}" -name "Astrafile.yaml" -print0)

echo "Patched recipes:"
grep -r "^  - name:" "${PACKAGES_DIR}" || true

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

for pkg in "${BOOTSTRAP_PACKAGES[@]}"; do
    if [[ -d "${PACKAGES_DIR}/${pkg}" ]]; then
        "${ASTRA}" build "${PACKAGES_DIR}/${pkg}" \
            --output   "${PACKAGES_OUT_DIR}" \
            --data-dir "${ASTRA_DATA_DIR}" \
            --root     "${ASTRA_ROOT_DIR}"
    else
        echo "WARNING: package recipe not found for ${pkg}, skipping"
    fi
done

section "Installing bootstrap packages into rootfs"

for astpkg in "${PACKAGES_OUT_DIR}"/*.astpkg; do
    [[ -f "${astpkg}" ]] || continue
    "${ASTRA}" install "${astpkg}" \
        --data-dir "${ASTRA_DATA_DIR}" \
        --root     "${ROOTFS_DIR}"
done

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
