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

find "${PACKAGES_DIR}" -name "Astrafile.yaml" | while IFS= read -r recipe; do
    in_deps=0
    out=""
    while IFS= read -r line; do
        if echo "${line}" | grep -qE '^dependencies:'; then
            in_deps=1
            out="${out}${line}
"
            continue
        fi
        if [ "${in_deps}" = "1" ]; then
            if echo "${line}" | grep -qE '^  - '; then
                if echo "${line}" | grep -qE 'name:'; then
                    out="${out}${line}
"
                else
                    value="$(echo "${line}" | sed -E "s/^  - ['\"]?([^'\"]+)['\"]?$/\1/" | tr -d ' ')"
                    out="${out}  - name: ${value}
"
                fi
                continue
            elif ! echo "${line}" | grep -qE '^[ ]'; then
                in_deps=0
            fi
        fi
        out="${out}${line}
"
    done < "${recipe}"
    printf '%s' "${out}" > "${recipe}"
done

echo "Dependency normalisation complete"

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
