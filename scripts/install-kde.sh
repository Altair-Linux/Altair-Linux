#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

section "Installing KDE Plasma and SDDM"

ASTRA="${REPO_ROOT}/.astra-src/target/release/astra"
[[ -x "${ASTRA}" ]] || die "Astra binary not found at ${ASTRA} — run install-base phase first"

REPO_DIR="${REPO_ROOT}/.astra-repo"

KDE_PACKAGES=(
    plasma-desktop
    plasma-workspace
    plasma-nm
    plasma-pa
    plasma-systemmonitor
    kscreen
    kwin
    knotifications
    kio
    kio-extras
    solid
    sddm
    sddm-kcm
    konsole
    dolphin
    kate
    gwenview
    ark
    networkmanager
    networkmanager-wifi
    wpa_supplicant
    polkit
    polkit-kde-agent-1
    udisks2
    powerdevil
    bluedevil
    breeze
    breeze-icons
    oxygen-icons
    plasma-integration
    qt6-qtbase
    qt6-qtbase-x11
    qt6-qtdeclarative
    qt6-qtwayland
    pipewire
    pipewire-alsa
    pipewire-pulse
    wireplumber
)

section "Building KDE packages"

for pkg in "${KDE_PACKAGES[@]}"; do
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

section "Staging KDE packages into repo"

cp "${PACKAGES_OUT_DIR}"/*.astpkg "${REPO_DIR}/packages/"

section "Regenerating index.json"

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

section "Installing KDE packages into rootfs"

"${ASTRA}" update \
    --data-dir "${ASTRA_DATA_DIR}" \
    --root     "${ASTRA_ROOT_DIR}"

INSTALL_PKGS=()
for pkg in "${KDE_PACKAGES[@]}"; do
    [[ -d "${PACKAGES_DIR}/${pkg}" ]] && INSTALL_PKGS+=("${pkg}")
done

"${ASTRA}" install "${INSTALL_PKGS[@]}" \
    --data-dir "${ASTRA_DATA_DIR}" \
    --root     "${ROOTFS_DIR}"

section "Writing SDDM and session config"

mkdir -p "${ROOTFS_DIR}/etc/sddm.conf.d"

cat > "${ROOTFS_DIR}/etc/sddm.conf.d/altair.conf" << EOF
[Autologin]
Relogin=false

[General]
HaltCommand=/sbin/poweroff
RebootCommand=/sbin/reboot

[Theme]
Current=breeze

[Users]
MaximumUid=60000
MinimumUid=1000
EOF

mkdir -p "${ROOTFS_DIR}/etc/xdg"

cat > "${ROOTFS_DIR}/etc/xdg/startkde" << EOF
#!/bin/sh
export DESKTOP_SESSION=plasma
exec startplasma-x11
EOF
chmod +x "${ROOTFS_DIR}/etc/xdg/startkde"

chroot "${ROOTFS_DIR}" rc-update add sddm default          2>/dev/null || true
chroot "${ROOTFS_DIR}" rc-update add networkmanager default 2>/dev/null || true
chroot "${ROOTFS_DIR}" rc-update add dbus default          2>/dev/null || true
chroot "${ROOTFS_DIR}" rc-update add udev sysinit          2>/dev/null || true

section "KDE Plasma and SDDM install complete"
