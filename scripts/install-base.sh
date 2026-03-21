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

section "Patching Astrafile.yaml dependency format"

find "${PACKAGES_DIR}" -name "Astrafile.yaml" | while read -r recipe; do
    python3 - "${recipe}" << 'PYEOF'
import sys, re

path = sys.argv[1]
with open(path, "r") as f:
    content = f.read()

def fix_deps(block):
    lines = block.split("\n")
    out = []
    for line in lines:
        m = re.match(r'^(\s*)-\s+"?([^"{\n]+)"?\s*$', line)
        if m and not m.group(2).strip().startswith("name:"):
            out.append(f'{m.group(1)}- name: {m.group(2).strip()}')
        else:
            out.append(line)
    return "\n".join(out)

in_deps = False
result_lines = []
dep_block = []

for line in content.split("\n"):
    if re.match(r'^dependencies\s*:', line):
        in_deps = True
        result_lines.append(line)
        continue
    if in_deps:
        if re.match(r'^\s+-', line):
            m = re.match(r'^(\s*)-\s+"?([^"{\n]+)"?\s*$', line)
            if m and not m.group(2).strip().startswith("name:"):
                result_lines.append(f'{m.group(1)}- name: {m.group(2).strip()}')
            else:
                result_lines.append(line)
            continue
        else:
            in_deps = False
    result_lines.append(line)

with open(path, "w") as f:
    f.write("\n".join(result_lines))
PYEOF
done

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
