#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

section "Patching Astrafile.yaml inline dependency sequences"

find "${PACKAGES_DIR}" -name "Astrafile.yaml" | while IFS= read -r recipe; do
    perl -i -pe '
        if (/^(dependencies|optional_dependencies|conflicts|provides):\s*\[([^\]]*)\]/) {
            my $key   = $1;
            my $inner = $2;
            my @deps  = split(/\s*,\s*/, $inner);
            my @cleaned;
            for my $d (@deps) {
                $d =~ s/^\s+|\s+$//g;
                $d =~ s/^["'"'"']|["'"'"']$//g;
                push @cleaned, $d if $d ne "";
            }
            if (@cleaned == 0) {
                $_ = "$key: []\n";
            } else {
                my $block = "$key:\n";
                for my $d (@cleaned) {
                    $block .= "  - name: $d\n";
                }
                $_ = $block;
            }
        }
    ' "${recipe}"
done

section "Patch complete"
