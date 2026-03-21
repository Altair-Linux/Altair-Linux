#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

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

echo "Recipe normalisation complete"
