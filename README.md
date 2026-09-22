# VpnHood.AppUi.Assets.Classic

The classic look of the VpnHood app: the images, country flags, fonts and content documents its UI
draws, and the words of every language. A store of bytes with no code in it, shipped as **one zip**
that the package's MSBuild targets place beside the consuming app.

This repository is that store. It is a **git submodule** of
[vpnhood/VpnHood](https://github.com/vpnhood/VpnHood) at `src/AppUi/Assets/Classic`, so a checkout of
the app carries the look it is built with, pinned to a commit — and a fork that wants its own look
points that submodule at its own store instead.

## The rule

**No library may reference this package. Only a head, or the presentation library that chose this
look, may.**

A forker builds their app from the same libraries we do and replaces our artwork and our wording
with theirs. That only works if nothing beneath them is bound to ours. The package has no API, so
nothing can depend on it by accident; the rule is about the reference itself.

## What is in it

| Part | What it is | Who reads it |
|---|---|---|
| `assets/` | the files a person edits: `images/`, `flags/`, `fonts/`, `content/`, `locales/`, `branding/` | nothing at run time — it is the source of `ui.zip` |
| `ui.zip` | the same files as one archive, which is what ships | `ZipAssetProvider` in `VpnHood.Core.Toolkit`, which extracts it once per version (its hash) under the app's storage |
| `assets/locales/<culture>.json`, `locales/index.json` | the words, one file per language, and the list of languages | `Strings` in `VpnHood.AppUi.Common` |
| `assets/fonts/*.ttf`, `fonts/index.json` | the faces, and the list of them | `AppFontCollection` in the Avalonia UI |
| `assets/branding/<theme>/manifest.json` and the tray icons it names | the look the OS chrome draws with — window and bar colours, tray icons — one per look (`blue`, `violet`) | `AppBranding` in `VpnHood.AppLib.App`, for the theme the head names (`AppOptions.UiTheme`) |
| `buildTransitive/*.targets` | places the zip at `assets/ui.zip` where the consuming app's platform reads files, at any reference depth | the app's build |
| `build/*.targets` | forwards to the above for a direct package reference; the heads of the app repo import it | the app's build |

The indexes exist because nothing lists: a provider answers by name, and a page in a browser could
not enumerate a folder.

One file, never resources of an assembly: Android packs each assembly once per CPU architecture, so
the same bytes would ship three times; and one file is one item to place per platform and one
request from a browser.

## Changing something

Both the folder and the zip are committed, and they must move together — git keeps no timestamps, so
after a clone nothing can tell a stale zip from a fresh one:

```powershell
# edit assets/images/... , assets/locales/en.json , ...
./_zip-assets.ps1        # rebuilds ui.zip from assets/
git commit -am "..."     # both
```

Changing `assets/locales/en.json` also changes the C# side of the words: `Strings.g.cs` in
`VpnHood.AppUi.Common` has one member per key of that file, and it lives in the app repo because it
is code. `_sync-assets.ps1` writes it, into the parent checkout when this repo is used as a
submodule.

Every language but English is machine-translated from `en.json` by `vhtranslator` — never edit the
other locale files by hand.

## Where these files come from

They were authored and built in
[vpnhood/VpnHood.AppUi.Spa](https://github.com/vpnhood/VpnHood.AppUi.Spa), the web UI this look was
first drawn for, and mirrored here by `_sync-assets.ps1` — which is still the way to pull a change
across while that repo lives:

```powershell
cd <Vh>/VpnHood.AppUi.Spa/src/VpnHood.AppUi.Presentation.Classic.Spa; npm run build
cd <Vh>/VpnHood/src/AppUi/Assets/Classic; ./_sync-assets.ps1
```

The icon font is the one thing that is not a plain copy: the web UI's build cuts Material Design
Icons down to the icons the UIs actually name, and `assets/fonts/MaterialDesignIcons.ttf` is that
cut. Adding an icon means adding it there and mirroring again.

## Publishing the package

Pushed **by hand**, from `_publish.ps1`:

```powershell
./_zip-assets.ps1; ./_publish.ps1
```

The version is the product version in the app repo's `pub/PubVersion.json`, so it can trail the
libraries by a release or two. `IsPackable` is `false` in the project so the app repo's nuget sweep
skips it, and `_publish.ps1` overrides that for the one pack it runs; the project's
`VhRequireAssetsZip` target fails a pack outright if `ui.zip` is missing, because such a package
would install cleanly and start a head with no images and no words.

The heads in the app repo do not go through the package at all: they import `build/*.targets`
directly from this folder, so they always show the store as it is on disk. The consumers of the
**package** are heads built outside that repo.

## Licence

LGPL-2.1, the same as the app it dresses. See [LICENSE](LICENSE).
