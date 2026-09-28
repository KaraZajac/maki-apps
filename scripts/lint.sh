#!/bin/sh
# The store's rules for a submission, before anything is built: what apps/ID/ may hold, what its
# app.toml says, and what its bundles say about themselves. The whole store, or the apps named.
#
#     scripts/lint.sh [ID...]
#
# MAKI is the SDK's maki tool (default: maki on the PATH). With BASE set (a commit, as CI sets it
# for a pull request), bundles already in the store at BASE must not change.
set -eu
HERE=$(cd "$(dirname "$0")/.." && pwd)
MAKI=${MAKI:-maki}
# the store's categories, as maki desktop lists them: a new one is the store's to add
CATEGORIES="Finance Games Productivity Security Social Tools"

value() { sed -n "s/^$1 *= *\"\(.*\)\" *\$/\1/p" "$2" | head -n 1; }

ids="$*"
[ -n "$ids" ] || ids=$(ls "$HERE/apps")
failed=0
fail() { echo "  ✗ $*"; bad=1; failed=1; }
for id in $ids; do
    dir=$HERE/apps/$id
    bad=0
    echo "== $id"
    [ -d "$dir" ] || { fail "no apps/$id"; continue; }
    # what the folder may hold: app.toml, and the developer's bundles by version
    for f in $(ls -A "$dir"); do
        case "$f" in
            app.toml) ;;
            *.maki) echo "$f" | grep -Eq '^[1-9][0-9]*\.maki$' || fail "$f: bundles are VERSION.maki" ;;
            *) fail "$f: apps/$id holds app.toml and VERSION.maki files, nothing else" ;;
        esac
    done
    about=$dir/app.toml
    if [ ! -f "$about" ]; then
        fail "no app.toml"
    else
        category=$(value category "$about")
        case " $CATEGORIES " in
            *" $category "*) ;;
            *) fail "category \"$category\": one of $CATEGORIES" ;;
        esac
        repo=$(value repo "$about")
        echo "$repo" | grep -Eq '^https://[A-Za-z0-9.-]+/[A-Za-z0-9._/-]+$' || fail "repo \"$repo\": an https address of a Git repository"
        commit=$(value commit "$about")
        echo "$commit" | grep -Eq '^[0-9a-f]{40}$' || fail "commit \"$commit\": the whole commit ID, 40 hex digits"
        path=$(value path "$about")
        case "/$path/" in
            *"/../"* | "//"*) fail "path \"$path\": a directory inside the repository" ;;
        esac
    fi
    # the bundles: each is the app it's filed as, at the version its name says, all signed with
    # one developer key; the newest is the developer's own (the store stamps it when it publishes)
    developer=""
    newest=$(ls "$dir" | grep -E '^[0-9]+\.maki$' | sort -n | tail -n 1 || true)
    [ -n "$newest" ] || fail "no bundle: VERSION.maki, as the developer signed it"
    for f in $(ls "$dir" | grep -E '^[0-9]+\.maki$' | sort -n); do
        n=${f%.maki}
        info=$("$MAKI" inspect "$dir/$f" 2>&1) || { fail "$f: $(echo "$info" | head -n 1)"; continue; }
        head=$(echo "$info" | head -n 1)
        got_id=$(echo "$head" | sed -n 's/.*(version [0-9]*) (\([a-z0-9.-]*\))$/\1/p')
        got_version=$(echo "$head" | sed -n 's/.*(version \([0-9]*\)) ([a-z0-9.-]*)$/\1/p')
        [ "$got_id" = "$id" ] || fail "$f is $got_id, not $id"
        [ "$got_version" = "$n" ] || fail "$f is version $got_version: name it $got_version.maki"
        key=$(echo "$info" | sed -n 's/^ *developer key *//p')
        if [ -z "$developer" ]; then
            developer=$key
        elif [ "$key" != "$developer" ]; then
            fail "$f is signed by $key, the versions before by $developer: maki takes an update only from the same key"
        fi
        if [ "$f" = "$newest" ] && echo "$info" | grep -q '^ *where from *the maki store'; then
            fail "$f is stamped already: submit the bundle as you signed it"
        fi
    done
    # what's in the store already stays as it is
    if [ -n "${BASE:-}" ]; then
        git -C "$HERE" diff --name-status "$BASE" -- "apps/$id" | while read -r status file; do
            case "$status $file" in
                "A "*) ;;
                "M "*/app.toml) ;;
                *) echo "  ✗ $file: ${status}: a bundle in the store doesn't change; add a new version" && exit 1 ;;
            esac
        done || { bad=1; failed=1; }
    fi
    [ "$bad" = 1 ] || echo "  ✓ by the rules"
done
[ "$failed" = 0 ] || { echo "not by the rules"; exit 1; }
