#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/config.sh"

declare -a PHASES=(
    "rootfs   ${SCRIPTS_DIR}/build-rootfs.sh"
    "base     ${SCRIPTS_DIR}/install-base.sh"
    "kernel   ${SCRIPTS_DIR}/build-kernel.sh"
    "display  ${SCRIPTS_DIR}/install-display-stack.sh"
    "kde      ${SCRIPTS_DIR}/install-kde.sh"
    "branding ${SCRIPTS_DIR}/apply-branding.sh"
    "iso      ${SCRIPTS_DIR}/make-iso.sh"
    "release  ${SCRIPTS_DIR}/release.sh"
)

usage() {
    echo "Usage: $0 [phase|all]"
    echo ""
    echo "Available phases:"
    for entry in "${PHASES[@]}"; do
        local name
        name="$(echo "$entry" | awk '{print $1}')"
        echo "  ${name}"
    done
}

run_phase() {
    local phase_name="$1"
    local script_path="$2"

    if [[ ! -f "${script_path}" ]]; then
        die "Phase script not found: ${script_path}"
    fi

    section "Phase: ${phase_name}"
    bash "${script_path}"
    section "Phase complete: ${phase_name}"
}

find_phase_script() {
    local target="$1"
    for entry in "${PHASES[@]}"; do
        local name script
        name="$(echo "$entry" | awk '{print $1}')"
        script="$(echo "$entry" | awk '{print $2}')"
        if [[ "${name}" == "${target}" ]]; then
            echo "${script}"
            return 0
        fi
    done
    return 1
}

preflight() {
    section "Pre-flight checks"

    require_cmd bash
    require_cmd git
    require_cmd mktemp

    ensure_dir "${ROOTFS_DIR}"
    ensure_dir "${ISO_STAGING_DIR}"
    ensure_dir "${OUT_DIR}"
    ensure_dir "${BRANDING_DIR}"

    echo "DISTRO  : ${DISTRO_NAME} ${DISTRO_VERSION} (${DISTRO_CODENAME})"
    echo "ARCH    : ${DISTRO_ARCH}"
    echo "ROOTFS  : ${ROOTFS_DIR}"
    echo "OUT     : ${OUT_DIR}"
}

main() {
    local target="${1:-all}"

    if [[ "${target}" == "--help" || "${target}" == "-h" ]]; then
        usage
        exit 0
    fi

    preflight

    if [[ "${target}" == "all" ]]; then
        for entry in "${PHASES[@]}"; do
            local name script
            name="$(echo "$entry" | awk '{print $1}')"
            script="$(echo "$entry" | awk '{print $2}')"
            run_phase "${name}" "${script}"
        done
        section "Build complete — ISO: ${ISO_FILENAME}"
    else
        local script
        script="$(find_phase_script "${target}")" \
            || die "Unknown phase: '${target}'. Run '$0 --help' for valid phases."
        run_phase "${target}" "${script}"
    fi
}

main "$@"
