#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

section "Patching Astrafile.yaml dependency sequences"

find "${PACKAGES_DIR}" -name "Astrafile.yaml" | while IFS= read -r recipe; do
    perl -i -pe '
        if (/^dependencies:\s*\[([^\]]*)\]/) {
            my $inner = $1;
            my @deps  = split(/\s*,\s*/, $inner);
            my @cleaned;
            for my $d (@deps) {
                $d =~ s/^\s+|\s+$//g;
                $d =~ s/^["'"'"']|["'"'"']$//g;
                push @cleaned, $d if $d ne "";
            }
            if (@cleaned == 0) {
                $_ = "dependencies: []\n";
            } else {
                my $block = "dependencies:\n";
                for my $d (@cleaned) {
                    $block .= "  - name: $d\n";
                }
                $_ = $block;
            }
        }
    ' "${recipe}"
done

section "Patch complete"
