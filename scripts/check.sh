#!/bin/sh
# Rebuilds apps from their source and checks that each bundle is what that builds (`maki
# reproduce`): what the store does before it stamps an app. The whole store, or the apps named.
#
#     scripts/check.sh [ID...]
#
# MAKI is the SDK's maki tool (default: maki on the PATH), built from the SDK the apps use. Each
# app's source (apps/ID/app.toml) is fetched into .cache/, a checkout per repository, at the
# commit it names. A clone you already have can stand in for one, to save fetching it:
#
#     git clone --no-checkout ../xous-core .cache/github.com-KaraZajac-maki-firmware
#     git -C .cache/github.com-KaraZajac-maki-firmware remote set-url origin https://github.com/KaraZajac/maki-firmware
set -eu
HERE=$(cd "$(dirname "$0")/.." && pwd)
MAKI=${MAKI:-maki}
CACHE=$HERE/.cache

# a value from app.toml: `key = "value"`
value() { sed -n "s/^$1 *= *\"\(.*\)\" *\$/\1/p" "$2" | head -n 1; }

ids="$*"
[ -n "$ids" ] || ids=$(ls "$HERE/apps")
failed=""
for id in $ids; do
    about=$HERE/apps/$id/app.toml
    [ -f "$about" ] || { echo "$id: no apps/$id/app.toml"; failed="$failed $id"; continue; }
    repo=$(value repo "$about")
    commit=$(value commit "$about")
    path=$(value path "$about")
    checkout=$CACHE/$(echo "$repo" | sed 's|^https://||; s|[^A-Za-z0-9._-]|-|g')
    if [ ! -d "$checkout/.git" ]; then
        # blobs as they're needed: only the commit's files, not the whole history's
        git clone --quiet --filter=blob:none --no-checkout "$repo" "$checkout"
    fi
    git -C "$checkout" cat-file -e "$commit^{commit}" 2>/dev/null || git -C "$checkout" fetch --quiet origin "$commit"
    git -C "$checkout" -c advice.detachedHead=false checkout --quiet --force "$commit"
    # the newest bundle: the one app.toml's commit builds (git keeps the ones before)
    bundle=$HERE/apps/$id/$(ls "$HERE/apps/$id" | grep '^[0-9]*\.maki$' | sort -n | tail -n 1)
    echo "== $id: $(basename "$bundle") from $repo at ${commit%"${commit#????????????}"} ${path:+($path)}"
    "$MAKI" reproduce "$bundle" "$checkout/$path" || failed="$failed $id"
done
if [ -n "$failed" ]; then
    echo "not what their source builds:$failed"
    exit 1
fi
echo "every bundle is what its source builds"
