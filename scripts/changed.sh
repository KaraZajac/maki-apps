#!/bin/sh
# The apps a change touches: the IDs of apps/ID/ folders with a file added or changed between two
# commits, one a line (removed apps aren't listed: there's nothing to rebuild).
#
#     scripts/changed.sh BASE [HEAD]
set -eu
git diff --name-only --diff-filter=d "$1" "${2:-HEAD}" -- apps/ | sed -n 's|^apps/\([^/]*\)/.*|\1|p' | sort -u
