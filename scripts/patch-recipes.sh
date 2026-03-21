#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

section "Patching Astrafile.yaml inline dependency sequences"

find "${PACKAGES_DIR}" -name "Astrafile.yaml" | while IFS= read -r recipe; do
    perl -i -pe '
        if (/^dependencies:\s*\[([^\]]*)\]/) {
            my $inner = $1;
            my @deps = split(/\s*,\s*/, $inner);
            my @cleaned = grep { $_ ne "" } map { s/^\s+|\s+$//gr } @deps;
            if (@cleaned == 0) {
                $_ = "dependencies: []\n";
            } else {
                my $block = "dependencies:\n";
                for my $d (@cleaned) {
                    $d =~ s/^["'"'"']|["'"'"']$//g;
                    $block .= "  - name: $d\n";
                }
                $_ = $block;
            }
        }
    ' "${recipe}"
done

echo "Patch complete. Verifying:"
grep -r "^dependencies:" "${PACKAGES_DIR}" | head -20
