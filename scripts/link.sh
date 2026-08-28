#!/usr/bin/env bash
#
# Idempotently symlink SRC -> DST, backing up anything real already there.
#
#   scripts/link.sh SRC DST
#
# Lives as a script rather than a just recipe because just modules cannot call
# each other's private recipes: a nested `just _link` from inside a module
# resolves against the top-level Justfile instead.
#
# Output markers:  =  already correct   ~  backed up   +  created
#
set -euo pipefail

if [ $# -ne 2 ]; then
    echo "usage: $(basename "$0") SRC DST" >&2
    exit 2
fi

src="$1"
dst="$2"

if [ ! -e "$src" ]; then
    echo "  ✗ missing source: $src" >&2
    exit 1
fi

# Always link to an absolute path. A relative src would be resolved against the
# *destination's* directory, silently producing a dangling link.
src="$(readlink -f "$src")"

if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
    echo "  = $dst"
    exit 0
fi

mkdir -p "$(dirname "$dst")"

if [ -e "$dst" ] || [ -L "$dst" ]; then
    backup="$dst.bak.$(date +%Y%m%d%H%M%S)"
    mv "$dst" "$backup"
    echo "  ~ backed up $dst -> $(basename "$backup")"
fi

ln -sfn "$src" "$dst"
echo "  + $dst"
