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
| `assets/` | the files a person edits: `images/`, `flags/`, `fonts/`, `browser-fonts/`, `content/`, `locales/`, `countries/`, `themes/` | nothing at run time — it is the source of `ui.zip` |
| `buildTransitive/ui.zip` | the same files as one archive, which is what ships; beside the targets, so that one path finds it in the package and in this repo alike | `ZipAssetProvider` in `VpnHood.Net.Toolkit`, which extracts it once per version (its hash) under the app's storage |
| `assets/locales/<culture>.json`, `locales/index.json` | the words, one file per language, and the list of languages | `Strings` in `VpnHood.AppUi.Common` |
| `assets/countries/<language>.json` | each country's name by its code, one file per language | `CountryNames` in `VpnHood.AppUi.Common` |
| `vh_translator/`, `.config/dotnet-tools.json` | the translator's setup for the words: its config, each language's prompt (the names and terms it keeps) and the watches (the English each translation was made from); the tool's version | `vhtranslator`, run by hand — see "The words" |
| `assets/fonts/*.ttf`, `fonts/index.json` | the faces, and the list of them | `AppFontCollection` in the Avalonia UI |
| `_cut-icon-font.py` | the cut of `assets/fonts/MaterialDesignIcons.ttf` to the icons the UI names | run by hand — see "The icon font" |
| `assets/browser-fonts/*.ttf`, `browser-fonts/index.json` | the faces only a browser page loads, cut by `_cut-browser-fonts.py`: Russian and Chinese, which an app draws with its OS's fonts and no browser lends a page | `AppAssets` in the Avalonia UI, on a browser page alone |
| `_cut-browser-fonts.py` | the cut of those two faces | run by hand — see "The words" |
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
submodule, along with the lists of languages and faces and the zip; there it also fails on an image
the UI names that is not in `assets/images`.

## The words

The words of every language — `assets/locales/<culture>.json` and the documents in
`assets/content/<culture>/` — are written and translated here and nowhere else; English is the
source. Translate every new or changed English string by hand first, into every language you can,
before the commit: by `vh_translator/prompt.txt` and the language's own prompt in
`vh_translator/prompts/`, and in the form the translator writes — `en.json`'s key order, two-space
JSON, CRLF, no final newline; a document LF, with its front matter (`title`, `translate_prompt`,
`lang`, `auto_translated: true`). A fix that follows a rule — a name, a term, the register — goes in
that language's prompt too.

`vhtranslator` translates what was missed. A language not translated by hand must not keep its old
text: take the key out of that file (a document: delete that language's copy), since
`--ignore-changes` marks every changed key as translated, and a missing key is always translated but
a stale one is not. Then point the watches at the English the translations follow, and let the
translator fill in what is missing (it needs `GEMINI_API_KEY`; skip those two runs when nothing is):

```powershell
dotnet tool restore
dotnet tool run vhtranslator -- --ignore-changes         # the locale files
dotnet tool run vhtranslator -- docs --ignore-changes    # the documents
dotnet tool run vhtranslator                             # the missing keys
dotnet tool run vhtranslator -- docs                     # the missing documents
dotnet tool run vhtranslator -- --show-changes           # 0 changed keys (docs --show-changes: 0 documents)
```

A browser page draws only with the faces it is handed, so a new word may need a new cut. After any
change to the words, before `./_zip-assets.ps1`:

```powershell
pip install fonttools        # once
python _cut-browser-fonts.py # fails on a word no face can draw
```

It holds the words' and the country names' Chinese and the 3,755 common characters of GB2312 level
1, for what a user types. A rarer character a user types draws as a box, though the text under it
is what was typed. A run that changes nothing leaves the files as they were.

## The country names

`assets/countries/<language>.json` holds each country's name by its code, as `{ "DE": "Germany" }`, in
49 languages: more than the words come in, so a fork that adds a language usually finds its names
here. `CountryNames` reads the file of the language the words are in, falling back from a culture to
its language (`pt-BR` to `pt`). A country the file leaves out shows in English, and so does every
country of a language with no file.

They came from [Nager.Country.Translation](https://github.com/nager/Nager.Country) 4.7.1, under the
MIT licence kept beside them as `assets/countries/LICENSE`. They are edited here, by hand, and
`vhtranslator` leaves them alone. After a change, `./_zip-assets.ps1`; for a Chinese name,
`python _cut-browser-fonts.py` before it.

## The icon font

`assets/fonts/MaterialDesignIcons.ttf` is Material Design Icons cut down to the icons the UI names,
by their code points in `Mdi.cs` (`VpnHood.AppUi.Common`). An icon left out of the cut is a blank box,
so a new one goes in `Mdi.cs`, and then, with this repo in the app's checkout:

```powershell
pip install fonttools   # once
python _cut-icon-font.py # fails on a code point the font has not
./_zip-assets.ps1
```

`assets/browser-fonts/` is cut here too, from Noto Sans and Noto Sans SC under the SIL Open Font
License, the licence and copyright being in each face's name table ("The words").

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
