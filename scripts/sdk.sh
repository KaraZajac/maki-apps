#!/bin/sh
# Builds the maki tool the store uses (scripts/sdk.txt: a repository and a commit) into
# .cache/sdk/bin/maki, if it isn't there already for that commit, and prints its path. With
# --xous, also installs the Xous toolchain for the Rust in use, which native apps build with.
#
#     MAKI=$(scripts/sdk.sh) scripts/check.sh
set -eu
HERE=$(cd "$(dirname "$0")/.." && pwd)
set -- $(grep -v '^#' "$HERE/scripts/sdk.txt") "$@"
repo=$1
commit=$2
shift 2
checkout=$HERE/.cache/$(echo "$repo" | sed 's|^https://||; s|[^A-Za-z0-9._-]|-|g')
tool=$HERE/.cache/sdk
# the SDK's source at the commit, in the checkout scripts/check.sh shares: the tool can come
# from a cache (CI keeps .cache/sdk) while the checkout doesn't
checkout() {
    [ -d "$checkout/.git" ] || git clone --quiet --filter=blob:none --no-checkout "$repo" "$checkout"
    git -C "$checkout" cat-file -e "$commit^{commit}" 2>/dev/null || git -C "$checkout" fetch --quiet origin "$commit"
    git -C "$checkout" -c advice.detachedHead=false checkout --quiet --force "$commit"
}
if [ "$(cat "$tool/commit" 2>/dev/null)" != "$commit" ]; then
    checkout
    cargo install --quiet --locked --path "$checkout/sdk/maki" --root "$tool" >&2
    echo "$commit" > "$tool/commit"
fi
if [ "${1:-}" = "--xous" ]; then
    checkout
    (cd "$checkout" && cargo xtask install-toolkit >&2)
fi
echo "$tool/bin/maki"
