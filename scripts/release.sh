#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

section "Uploading release to GitHub"

require_cmd gh

if [[ ! -f "${ISO_FILENAME}" ]]; then
    die "ISO not found: ${ISO_FILENAME}. Run the iso phase first."
fi

ISO_SHA256="$(sha256sum "${ISO_FILENAME}" | awk '{print $1}')"
CHECKSUM_FILE="${OUT_DIR}/altair-linux-${DISTRO_VERSION}-${DISTRO_ARCH}.sha256"
echo "${ISO_SHA256}  $(basename "${ISO_FILENAME}")" > "${CHECKSUM_FILE}"

RELEASE_NOTES="Altair Linux ${DISTRO_VERSION} (${DISTRO_CODENAME})

SHA256: ${ISO_SHA256}"

if gh release view "${GH_RELEASE_TAG}" --repo "${GH_REPO}" >/dev/null 2>&1; then
    section "Release ${GH_RELEASE_TAG} already exists — uploading assets"
    gh release upload "${GH_RELEASE_TAG}" \
        "${ISO_FILENAME}" \
        "${CHECKSUM_FILE}" \
        --repo "${GH_REPO}" \
        --clobber
else
    section "Creating release ${GH_RELEASE_TAG}"
    gh release create "${GH_RELEASE_TAG}" \
        "${ISO_FILENAME}" \
        "${CHECKSUM_FILE}" \
        --repo "${GH_REPO}" \
        --title "${DISTRO_NAME} ${DISTRO_VERSION}" \
        --notes "${RELEASE_NOTES}"
fi

section "Release complete: ${GH_RELEASE_TAG}"
