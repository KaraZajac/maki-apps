# maki apps

The maki store: apps for [maki](https://github.com/KaraZajac/maki), reviewed, rebuilt from their
source and stamped, then published here for maki desktop to list and install. maki checks every
stamp itself before it installs anything (ARCHITECTURE.md in the maki repo, "The store").

## What's here

- **`apps/ID/`**, one app each: `app.toml`, which says where its source is (a Git repository
  and the commit it's built from) and its category, and its developer's signed bundles,
  `VERSION.maki`, as the developer made them.
- **`store/`**, the store as maki desktop fetches it: the roots, the revocation list, the
  signed index and the stamped bundles. `scripts/publish.sh` makes it; nothing in it is edited
  by hand.
- **`revocations.txt`**: what the store revokes, and why.
- **`scripts/check.sh`** rebuilds each app from its source and checks that its bundle is what
  that builds (`maki reproduce`: the manifest, icon and code, byte for byte, given the same
  Rust).
- **`scripts/publish.sh`** stamps each app's newest bundle with the catalogue key, signs the
  revocation list again when it changes, and signs a new index.

## Adding an app

1. Build and sign it with the SDK (`maki build`), from a commit you've pushed, and check that
   the bundle reproduces from it (`maki reproduce APP.maki DIR`).
2. Open a pull request adding `apps/YOUR.APP.ID/1.maki` and `apps/YOUR.APP.ID/app.toml`:

   ```toml
   category = "Tools"

   [source]
   repo = "https://github.com/you/your-app"
   commit = "the whole commit ID, 40 hex digits"
   path = "the app's directory in the repository, if it isn't the top"
   ```

3. The store rebuilds it from that commit (`scripts/check.sh YOUR.APP.ID`), reads the source
   and checks that what it asks to do matches what it does, then stamps it and publishes it
   (`scripts/publish.sh`).

An update is a new bundle beside the old ones (`2.maki`) with a higher version, signed with the
same developer key, and `app.toml` pointing at the commit it's built from. maki takes an update
to a store app only from the store.

## How maki desktop uses it

maki desktop fetches `store/` from this repository, checks the root chain, the index and the
revocation list against the root it carries, and lists the store's apps under Apps; maki
checks everything again itself. While the repository is private, maki desktop needs a token to
read it (`MAKI_STORE_TOKEN=$(gh auth token) npm run dev`); `MAKI_STORE` points it at another
copy of the store, a folder (this repository's `store/`) or an https address.

## Keys

Until Kara makes the store's real keys, offline, the store is signed with the development keys
that maki's firmware and maki desktop trust for now (DEVELOPMENT.md in the maki repo, "The maki
store"). They never come into this repository. Its records last ten years, as the development
store's do; the real store's index will last a month, its revocation list a few weeks, and CI
will sign them again before they run out.

## Checking and publishing

```sh
# the SDK's maki tool, from the SDK the apps use (the maki repo's xous-core/sdk)
export MAKI=../xous-core/sdk/target/release/maki
scripts/check.sh                              # every app rebuilt from its source
scripts/publish.sh ~/store-keys/catalogue2.key 3650
```

Not yet: CI that runs `scripts/check.sh` on each pull request, which needs the SDK's
repository public (or a token for it).
