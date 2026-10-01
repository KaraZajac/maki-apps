#!/bin/sh
# Publishes the store in store/: each app's newest bundle stamped with the catalogue key (with
# its app.toml beside it), the revocation list signed again if revocations.txt changed, and a new
# index. The store stamps only what it has rebuilt from source: run scripts/check.sh first.
#
#     scripts/publish.sh CATALOGUE.key [DAYS]
#
# DAYS is how long the index and the revocation list last (default 30): maki desktop won't use
# an index that has expired, and shows a stale revocation list as stale, so the real store signs
# them again well before then. The roots in store/roots are made offline, with the root keys,
# and only copied in here (DEVELOPMENT.md in the maki repo, "The store's keys").
set -eu
HERE=$(cd "$(dirname "$0")/.." && pwd)
MAKI=${MAKI:-maki}
KEY=$1
DAYS=${2:-30}
STORE=$HERE/store

# versions only go up: the hour it is (UTC, YYYYMMDDHH), or one more than the last
next() { now=$(date -u +%Y%m%d%H); if [ "$now" -gt "$1" ]; then echo "$now"; else echo $(($1 + 1)); fi; }

[ -d "$STORE/roots" ] || { echo "no store/roots: the store's roots come first"; exit 1; }
rm -rf "$STORE/apps"
for dir in "$HERE"/apps/*/; do
    id=$(basename "$dir")
    newest=$(ls "$dir" | grep '^[0-9]*\.maki$' | sort -n | tail -n 1)
    [ -n "$newest" ] || { echo "$id: no bundle"; exit 1; }
    mkdir -p "$STORE/apps/$id"
    "$MAKI" store stamp "$dir$newest" --catalogue "$KEY" -o "$STORE/apps/$id/$newest" >/dev/null
    cp "$dir/app.toml" "$STORE/apps/$id/app.toml"
    echo "$id: $newest stamped"
done

list=$STORE/revocations.bin
last=0
[ -f "$list" ] && last=$("$MAKI" store show "$list" | sed -n 's/^revocation list \([0-9]*\),.*/\1/p')
if [ ! -f "$list" ] || [ "$HERE/revocations.txt" -nt "$list" ]; then
    "$MAKI" store revoke --catalogue "$KEY" --version "$(next "$last")" --expires-days "$DAYS" \
        --list "$HERE/revocations.txt" -o "$list"
fi

index=0
[ -f "$STORE/index.json" ] && index=$(sed -n 's/^  "version": \([0-9]*\),*$/\1/p' "$STORE/index.json")
# and the newest firmware and maki desktop (releases.toml), so maki desktop can update them
set -- --catalogue "$KEY" --version "$(next "$index")" --expires-days "$DAYS"
[ -f "$HERE/releases.toml" ] && set -- "$@" --releases "$HERE/releases.toml"
"$MAKI" store index "$STORE" "$@"

# the notices of the code of others the apps are built with: the SDK's, at the commit the store
# pins (tools/maki-notices.py in maki-firmware makes them), from the checkout scripts/sdk.sh made
set -- $(grep -v '^#' "$HERE/scripts/sdk.txt")
notices=$HERE/.cache/$(echo "$1" | sed 's|^https://||; s|[^A-Za-z0-9._-]|-|g')/sdk/THIRD-PARTY-NOTICES.md
if [ -f "$notices" ]; then cp "$notices" "$STORE/THIRD-PARTY-NOTICES.md"; else echo "the pinned SDK has no THIRD-PARTY-NOTICES.md: the store's is unchanged"; fi
