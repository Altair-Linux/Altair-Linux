#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

require_cmd python3

section "Patching Astrafile.yaml files in ${PACKAGES_DIR}"

python3 << 'PYEOF'
import os, sys

packages_dir = os.environ["PACKAGES_DIR"]
patched = 0

for root, dirs, files in os.walk(packages_dir):
    for fname in files:
        if fname != "Astrafile.yaml":
            continue
        path = os.path.join(root, fname)
        with open(path, "r") as f:
            lines = f.readlines()

        new_lines = []
        in_deps = False
        changed = False

        for line in lines:
            stripped = line.rstrip("\n")

            if stripped.startswith("dependencies:"):
                in_deps = True
                new_lines.append(line)
                continue

            if in_deps:
                if stripped.startswith("  -"):
                    # check if already structured
                    after_dash = stripped[3:].strip()
                    if after_dash.startswith("name:") or after_dash == "[]" or after_dash == "":
                        new_lines.append(line)
                    else:
                        # plain string — rewrite
                        indent = len(stripped) - len(stripped.lstrip())
                        value = after_dash.strip('"').strip("'").strip()
                        new_line = " " * indent + "- name: " + value + "\n"
                        print(f"  PATCH {path}: '{stripped}' -> '{new_line.rstrip()}'")
                        new_lines.append(new_line)
                        changed = True
                    continue
                elif not stripped.startswith(" ") and stripped != "":
                    in_deps = False

            new_lines.append(line)

        if changed:
            with open(path, "w") as f:
                f.writelines(new_lines)
            patched += 1

print(f"Patched {patched} recipe file(s).")
PYEOF
