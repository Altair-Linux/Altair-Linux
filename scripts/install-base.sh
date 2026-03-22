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

REPO_DIR="${REPO_ROOT}/.astra-repo"
ensure_dir "${ASTRA_DATA_DIR}"
ensure_dir "${ASTRA_ROOT_DIR}"
ensure_dir "${PACKAGES_OUT_DIR}"
ensure_dir "${REPO_DIR}/packages"
ensure_dir "${REPO_DIR}/signatures"

"${ASTRA}" init \
    --data-dir "${ASTRA_DATA_DIR}" \
    --root     "${ASTRA_ROOT_DIR}"

"${ASTRA}" key generate \
    --data-dir "${ASTRA_DATA_DIR}" \
    --root     "${ASTRA_ROOT_DIR}"

section "Trusting the build signing key"

"${ASTRA}" key export \
    --data-dir "${ASTRA_DATA_DIR}" \
    --root     "${ASTRA_ROOT_DIR}" \
    > "${ASTRA_DATA_DIR}/build.pub"

"${ASTRA}" key import altair-build "${ASTRA_DATA_DIR}/build.pub" \
    --data-dir "${ASTRA_DATA_DIR}" \
    --root     "${ASTRA_ROOT_DIR}"

section "Building bootstrap packages"

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
done

section "Staging packages into repo layout"

cp "${PACKAGES_OUT_DIR}"/*.astpkg "${REPO_DIR}/packages/"

section "Generating index.json"

python3 - "${REPO_DIR}" << 'PYEOF'
import json, os, sys, hashlib, datetime, tarfile, io

repo_dir   = sys.argv[1]
pkgs_dir   = os.path.join(repo_dir, "packages")
index_path = os.path.join(repo_dir, "index.json")

entries = []
for fname in sorted(os.listdir(pkgs_dir)):
    if not fname.endswith(".astpkg"):
        continue
    fpath = os.path.join(pkgs_dir, fname)
    size  = os.path.getsize(fpath)
    with open(fpath, "rb") as f:
        raw = f.read()
    checksum = hashlib.sha256(raw).hexdigest()
    meta = {}
    try:
        import zstandard as zstd
        dctx = zstd.ZstdDecompressor()
        data = dctx.decompress(raw, max_output_size=50*1024*1024)
        with tarfile.open(fileobj=io.BytesIO(data)) as tf:
            m = tf.extractfile("metadata.json")
            if m:
                meta = json.load(m)
    except Exception:
        parts = fname.replace(".astpkg","").rsplit("-", 2)
        meta = {"name": parts[0], "version": parts[1] if len(parts)>1 else "0.0.0",
                "architecture": parts[2] if len(parts)>2 else "x86_64",
                "description": "", "dependencies": [], "conflicts": [],
                "provides": [], "license": "", "maintainer": ""}
    entries.append({
        "name":         meta.get("name", fname),
        "version":      meta.get("version", "0.0.0"),
        "architecture": meta.get("architecture", "x86_64"),
        "description":  meta.get("description", ""),
        "dependencies": meta.get("dependencies", []),
        "conflicts":    meta.get("conflicts", []),
        "provides":     meta.get("provides", []),
        "checksum":     checksum,
        "filename":     fname,
        "size":         size,
        "license":      meta.get("license", ""),
        "maintainer":   meta.get("maintainer", ""),
    })

index = {
    "name":         "altair",
    "description":  "Altair Linux local bootstrap repository",
    "last_updated": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "packages":     entries,
}
with open(index_path, "w") as f:
    json.dump(index, f, indent=2)
print(f"index.json written with {len(entries)} packages")
PYEOF

section "Starting local repo server"

python3 -m http.server 18080 --directory "${REPO_DIR}" &
REPO_PID=$!
trap "kill ${REPO_PID} 2>/dev/null || true" EXIT
sleep 2

section "Registering repo and installing packages"

"${ASTRA}" repo add altair http://127.0.0.1:18080/ \
    --data-dir "${ASTRA_DATA_DIR}" \
    --root     "${ASTRA_ROOT_DIR}"

"${ASTRA}" update \
    --data-dir "${ASTRA_DATA_DIR}" \
    --root     "${ASTRA_ROOT_DIR}"

INSTALL_PACKAGES=()
for pkg in "${BOOTSTRAP_PACKAGES[@]}"; do
    [[ "${pkg}" == "astra" ]] && continue
    INSTALL_PACKAGES+=("${pkg}")
done

"${ASTRA}" install "${INSTALL_PACKAGES[@]}" \
    --data-dir "${ASTRA_DATA_DIR}" \
    --root     "${ROOTFS_DIR}"

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
