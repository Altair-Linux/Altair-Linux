#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

section "Applying Altair branding"

require_cmd git

if [[ ! -d "${BRANDING_DIR}/.git" ]]; then
    git clone --depth=1 --branch "${BRANDING_REPO_BRANCH}" \
        "${BRANDING_REPO_URL}" "${BRANDING_DIR}"
else
    git -C "${BRANDING_DIR}" pull --ff-only
fi

WALLPAPER_DST="${ROOTFS_DIR}/usr/share/wallpapers/altair"
mkdir -p "${WALLPAPER_DST}"

cp "${BRANDING_DIR}/wallpapers/dark-mode-wallpaper.png"  "${WALLPAPER_DST}/dark.png"
cp "${BRANDING_DIR}/wallpapers/light-mode-wallpaper.png" "${WALLPAPER_DST}/light.png"
cp "${BRANDING_DIR}/wallpapers/splash.png"               "${WALLPAPER_DST}/splash.png"

LOGO_DST="${ROOTFS_DIR}/usr/share/pixmaps"
mkdir -p "${LOGO_DST}"
cp "${BRANDING_DIR}/logos/altair-logo.svg"            "${LOGO_DST}/altair-logo.svg"
cp "${BRANDING_DIR}/logos/altair-logo-icon.svg"       "${LOGO_DST}/altair-logo-icon.svg"
cp "${BRANDING_DIR}/logos/altair-logo-monochrome.svg" "${LOGO_DST}/altair-logo-monochrome.svg"

SDDM_THEME_DST="${ROOTFS_DIR}/usr/share/sddm/themes/altair"
mkdir -p "${SDDM_THEME_DST}"
cp "${BRANDING_DIR}/wallpapers/dark-mode-wallpaper.png" "${SDDM_THEME_DST}/background.png"

cat > "${SDDM_THEME_DST}/theme.conf" << EOF
[General]
background=background.png
type=image
EOF

cat > "${SDDM_THEME_DST}/metadata.desktop" << EOF
[SddmGreeterTheme]
Name=Altair
Description=Altair Linux Login Theme
Author=Altair Linux
Version=1.0
Website=https://github.com/altair-linux
EOF

PLASMA_DEFAULTS="${ROOTFS_DIR}/etc/xdg/plasma-workspace/env"
mkdir -p "${PLASMA_DEFAULTS}"

cat > "${PLASMA_DEFAULTS}/altair-wallpaper.sh" << EOF
#!/bin/sh
export ALTAIR_WALLPAPER=/usr/share/wallpapers/altair/dark.png
EOF
chmod +x "${PLASMA_DEFAULTS}/altair-wallpaper.sh"

KSPLASH_DST="${ROOTFS_DIR}/usr/share/ksplash/themes/altair"
mkdir -p "${KSPLASH_DST}"
cp "${BRANDING_DIR}/wallpapers/splash.png" "${KSPLASH_DST}/preview.png"

cat > "${KSPLASH_DST}/metadata.desktop" << EOF
[KSplash Theme: altair]
Name=Altair
Description=Altair Linux Splash Screen
Version=1.0
EOF

cat >> "${ROOTFS_DIR}/etc/sddm.conf.d/altair.conf" << EOF

[Theme]
Current=altair
EOF

section "Branding applied"
