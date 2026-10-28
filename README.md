# VpnHood.AppUi.Assets.Classic

The classic look of the VpnHood app: the images, country flags, fonts and content documents its UI
draws, and the words of every language. A store of bytes with no code in it, shipped as **one zip**
that the package's MSBuild targets place beside the consuming app.

This repository is that store. It is a **git submodule** of
[vpnhood/VpnHood](https://github.com/vpnhood/VpnHood) at `src/AppUi/VpnHood.AppUi.Assets.Classic`, so a checkout of
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
| `assets/` | the files a person edits: `images/`, `flags/`, `fonts/`, `content/`, `locales/`, `themes/` | nothing at run time — it is the source of `ui.zip` |
| `buildTransitive/ui.zip` | the same files as one archive, which is what ships; beside the targets, so that one path finds it in the package and in this repo alike | `ZipAssetProvider` in `VpnHood.Net.Toolkit`, which extracts it once per version (its hash) under the app's storage |
| `assets/locales/<culture>.json`, `locales/index.json` | the words, one file per language, and the list of languages | `Strings` in `VpnHood.AppUi.Common` |
| `vh_translator/`, `.config/dotnet-tools.json` | the translator's setup for the words: its config, each language's prompt (the names and terms it keeps) and the watches (the English each translation was made from); the tool's version | `vhtranslator`, run by hand — see "The words" |
| `assets/fonts/*.ttf`, `fonts/index.json` | the faces, and the list of them | `AppFontCollection` in the Avalonia UI |
| `assets/themes/<theme>/manifest.json` | each theme's (`blue`, `violet`) colours for what the UI cannot draw: the native chrome around it — the window's and the bars' — and the app's launch screen | `ThemeColors` in `VpnHood.AppUi.Common`, for the theme the app names (`AppOptions.UiTheme`); the app's build, for its launch screen |
| `buildTransitive/*.targets` | places the zip at `assets/ui.zip` where the consuming app's platform reads files, at any reference depth, a direct one included; the heads of the app repo import it | the app's build |

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
./_zip-assets.ps1        # rebuilds buildTransitive/ui.zip from assets/
git commit -am "..."     # both
```

Changing `assets/locales/en.json` also changes the C# side of the words: `Strings.g.cs` in
`VpnHood.AppUi.Common` has one member per key of that file, and it lives in the app repo because it
is code. `_sync-assets.ps1` writes it, into the parent checkout when this repo is used as a
submodule.

## The words

The words of every language — `assets/locales/<culture>.json` and the documents in
`assets/content/<culture>/` — are written and translated here and nowhere else; English is the
source. Translate every new or changed English string by hand, into all 12 languages, before the
commit: by `vh_translator/prompt.txt` and the language's own prompt in `vh_translator/prompts/`,
and in the form the translator writes — `en.json`'s key order, two-space JSON, CRLF, no final
newline; a document LF, with its front matter (`title`, `translate_prompt`, `lang`,
`auto_translated: true`). A fix that follows a rule — a name, a term, the register — goes in that
language's prompt too. Then point the watches at the English the translations follow, so the
translator has nothing left to do:

```powershell
dotnet tool restore
dotnet tool run vhtranslator -- --ignore-changes         # the locale files
dotnet tool run vhtranslator -- docs --ignore-changes    # the documents
dotnet tool run vhtranslator -- --show-changes           # 0 changed keys (docs --show-changes: 0 documents)
```

`vhtranslator` itself is only the fallback, for a key left out on purpose — and such a key must be
missing from the target file, since a missing key is always translated but a stale one is not once
the watches are current.

The web UI carries a copy of the words: `./_copy-words-to-web-ui.ps1` writes them into its
`src/locales` and `src/content`. Commit the copy there as well, and never edit it there.

## Where these files come from

The images, flags, fonts and themes were authored and built in
[vpnhood/VpnHood.AppUi.Spa](https://github.com/vpnhood/VpnHood.AppUi.Spa), the web UI this look was
first drawn for, and are mirrored here by `_sync-assets.ps1` — which is still the way to pull a
change to them across while that repo lives:

```powershell
cd <Vh>/VpnHood.AppUi.Spa/src/VpnHood.AppUi.Presentation.Classic.Spa; npm run build
cd <Vh>/VpnHood/src/AppUi/VpnHood.AppUi.Assets.Classic; ./_sync-assets.ps1
```

The words go the other way: they are written here, and the web UI takes its copy from here.

The icon font is the one thing that is not a plain copy: the web UI's build cuts Material Design
Icons down to the icons the UIs actually name, and `assets/fonts/MaterialDesignIcons.ttf` is that
cut. Adding an icon means adding it there and mirroring again.

## Publishing the package

The app repo's NuGet workflow (`publish_nugets.yml` in vpnhood/VpnHood) publishes it with the
libraries and at their version, from the commit the app repo's submodule pointer names. So a change
here ships with the next library release once `./_zip-assets.ps1` has rebuilt `buildTransitive/ui.zip`,
it is committed and pushed, and the app repo's pointer has moved. The project's `VhRequireAssetsZip`
target fails a pack outright if `ui.zip` is missing, because such a package would install cleanly and
start a head with no images and no words.

The heads in the app repo do not go through the package at all: they import `buildTransitive/*.targets`
directly from this folder, so they always show the store as it is on disk. The consumers of the
**package** are heads built outside that repo.

## Licence

LGPL-2.1, the same as the app it dresses. See [LICENSE](https://github.com/vpnhood/VpnHood.AppUi.Assets.Classic/blob/main/LICENSE).
