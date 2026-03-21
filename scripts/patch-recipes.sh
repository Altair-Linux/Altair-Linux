#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

section "Patching Astrafile.yaml files"

find "${PACKAGES_DIR}" -name "Astrafile.yaml" | while IFS= read -r recipe; do
    perl -i -pe '
        # Rewrite dependencies: [a, b] -> block list of {name: x}
        if (/^dependencies:\s*\[([^\]]*)\]/) {
            my $inner = $1;
            my @deps = split(/\s*,\s*/, $inner);
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
        # Normalise x.y version to x.y.0
        if (/^version:\s*"?(\d+\.\d+)"?\s*$/) {
            my $v = $1;
            $_ =~ s/"?\Q$v\E"?/"$v.0"/;
        }
        # Normalise YYYYMMDD date version to YYYY.MM.DD
        if (/^version:\s*"?(\d{4})(\d{2})(\d{2})"?\s*$/) {
            my ($y, $m, $d) = ($1, $2, $3);
            $_ = "version: \"$y.$m.$d\"\n";
        }
    ' "${recipe}"
done

section "Patch complete"
