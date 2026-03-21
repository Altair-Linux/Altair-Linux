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
        if (/^version:\s*"?([^"\n]+)"?\s*$/) {
            my $v = $1;
            my $orig = $v;
            # Strip non-numeric suffixes: p1, b2, rc3, alpha1 etc.
            $v =~ s/[a-zA-Z]+\d*$//;
            # Strip trailing dots or dashes left behind
            $v =~ s/[-.]$//;
            # Normalise YYYYMMDD to YYYY.M.D
            if ($v =~ /^(\d{4})(\d{2})(\d{2})$/) {
                $v = "$1." . int($2) . "." . int($3);
            }
            # Normalise x.y to x.y.0
            elsif ($v =~ /^\d+\.\d+$/) {
                $v = "$v.0";
            }
            $_ = "version: \"$v\"\n" if $v ne $orig;
        }
    ' "${recipe}"
done

section "Patch complete"
