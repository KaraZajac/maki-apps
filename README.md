# maki apps

The maki store: apps for [maki](https://github.com/KaraZajac/maki), reviewed, rebuilt from their
source and stamped, then published here for maki desktop to list and install. maki checks every
stamp itself before it installs anything (ARCHITECTURE.md in the maki repo, "The store").

## What's here

- **`apps/ID/`**, one app each: `app.toml`, which says where its source is (a Git repository
  and the commit it's built from) and its category, and its developer's signed bundle,
  `VERSION.maki`, as the developer made it.
- **`store/`**, the store as maki desktop fetches it: the roots, the revocation list, the
  signed index and the stamped bundles. `scripts/publish.sh` makes it; nothing in it is edited
  by hand.
- **`revocations.txt`**: what the store revokes, and why.
- **`scripts/lint.sh`** checks the rules for a submission before anything is built: `apps/ID/`
  holds `app.toml` and `VERSION.maki` files only; `app.toml` names one of the store's categories,
  an https repository, a whole commit ID and a directory inside it; each bundle is the app it's
  filed as, at the version its name says, all signed with one developer key, the newest as the
  developer signed it (not stamped); and bundles already in the store don't change.
- **`scripts/check.sh`** rebuilds each app from its source and checks that its bundle is what
  that builds (`maki reproduce`: the manifest, icon and code, byte for byte, given the same
  Rust).
- **`scripts/sdk.txt`** pins the SDK the store checks with (the maki tool from a commit of
  maki-firmware), and **`scripts/sdk.sh`** builds it: `MAKI=$(scripts/sdk.sh) scripts/check.sh`.
- **CI** (`.github/workflows/check.yml`) runs both on every pull request and push, for the apps
  a change touches, and on all of them when the pinned tool changes, weekly and by hand. It has
  no keys: stamping and publishing stay offline.
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

3. CI checks it by the rules and rebuilds it from that commit, on the pull request itself (Rust
   1.96.0, unless your source pins another with a `rust-toolchain.toml`). Then the store reads
   the source and checks that what it asks to do matches what it does, and stamps it and
   publishes it (`scripts/publish.sh`).

An update replaces the bundle with one of a higher version (`2.maki` for `1.maki`), signed
with the same developer key, and points `app.toml` at the commit it's built from; the ones
before stay in the history. maki takes an update to a store app only from the store.

## How maki desktop uses it

maki desktop fetches `store/` from this repository, checks the root chain, the index and the
revocation list against the root it carries, and lists the store's apps under Apps; maki
checks everything again itself. `MAKI_STORE` points it at another copy of the store, a folder
(this repository's `store/`) or an https address; a copy in a private GitHub repository needs a
token to read it (`MAKI_STORE_TOKEN=$(gh auth token) npm run dev`).

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

## Licenses

The store's scripts, its index and this README are licensed under the MIT License (`LICENSE`).
Each app is its developer's, under the license its source says; the apps here so far are maki's
SDK examples, MIT like the SDK (maki-firmware's `sdk/`). The code of others they're built with
is in `store/THIRD-PARTY-NOTICES.md`, with each one's license and its authors' notices:
`scripts/publish.sh` copies it from the SDK the store pins.
