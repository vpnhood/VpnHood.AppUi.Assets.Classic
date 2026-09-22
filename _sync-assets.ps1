# Brings the classic look's files in from the web UI, where they were authored and built, and packs
# them into the one file the package places.
#
# This repository IS the store now, so this script is the bridge back to where these files came
# from: run it to pull a change across while VpnHood.AppUi.Spa still lives. A change made directly
# in assets/ needs only _zip-assets.ps1 beside this file.
#
#   assets/            <- <WebUI>/dist/assets (images, flags, fonts, content) - the BUILT folder: the
#                         icon font in it is cut to the icons both UIs name, by the web UI's own build
#                         (build/icon-font-plugin.ts), so `npm run build` there comes first
#   assets/locales/    <- <WebUI>/src/locales/*.json - the words, one file per language
#   assets/branding/   <- <WebUI>/dist/branding - the look the OS chrome draws with: a manifest and
#                         the tray icons per theme (default, connect), read by AppBranding in AppLib
#   assets/locales/index.json, assets/fonts/index.json   the languages, the faces: a list rather
#                         than a listing, because a provider answers by name and never enumerates
#   ui.zip        <- assets/, by _zip-assets.ps1: the store as the package's targets place it
#                         (assets/ui.zip) and ZipAssetProvider extracts it, its hash its version
#   ../../Common/Strings.g.cs   one member per key of en.json - the C# side of the words, which
#                         belongs to the app repo's services module, not to this store. Written only
#                         when this store sits in that checkout as a submodule; skipped otherwise.
#
# Everything is mirrored (a file gone there is gone here). Both assets/ and ui.zip are committed
# here, so review what this changes before committing it.
#
# Every file is read and written with an explicit UTF-8 encoding: Windows PowerShell would
# otherwise read these files as ANSI and double-encode every non-ASCII word in them. Paths use
# forward slashes, because this also runs under pwsh on Linux.

param(
    # The SPA project the look is authored and built in: beside this repo on a developer's machine,
    # wherever the workflow checked it out on a CI box.
    [string] $WebUiDir = ""
)

$ErrorActionPreference = "Stop";

if ($WebUiDir -eq "") {
    # <Vh>/VpnHood/src/AppUi/Assets/Classic -> <Vh>
    $vhFolder = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../../../../.."));
    $WebUiDir = Join-Path $vhFolder "VpnHood.AppUi.Spa/src/VpnHood.AppUi.Presentation.Classic.Spa";
}
$builtAssetsDir = Join-Path $WebUiDir "dist/assets";
$localesDir = Join-Path $WebUiDir "src/locales";
$assetsDir = Join-Path $PSScriptRoot "assets";
$assetLocalesDir = Join-Path $assetsDir "locales";
$zipPath = Join-Path $PSScriptRoot "ui.zip";
$stringsFile = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../../Common/Strings.g.cs"));
$hasAppRepo = Test-Path (Split-Path $stringsFile -Parent);
$utf8 = New-Object System.Text.UTF8Encoding($false);

if (!(Test-Path $builtAssetsDir)) { throw "The web UI has not been built (npm run build in $WebUiDir). $builtAssetsDir"; }
if (!(Test-Path $localesDir)) { throw "The web UI's locales are not there. $localesDir"; }

# ---- the files: a mirror of the built folder ----
$folders = @("images", "flags", "fonts", "content");
if (Test-Path $assetsDir) { Remove-Item $assetsDir -Recurse -Force; }
New-Item -ItemType Directory $assetsDir | Out-Null;
foreach ($folder in $folders) {
    $source = Join-Path $builtAssetsDir $folder;
    if (!(Test-Path $source)) { throw "The built assets folder has no '$folder' folder. $source"; }
    Copy-Item $source (Join-Path $assetsDir $folder) -Recurse;
}

# ---- the look: one theme per product, beside the built assets rather than under them ----
$brandingDir = Join-Path $WebUiDir "dist/branding";
if (!(Test-Path $brandingDir)) { throw "The web UI's build has no branding folder. $brandingDir"; }
Copy-Item $brandingDir (Join-Path $assetsDir "branding") -Recurse;

# Not the film: the internal ad is a fallback that exactly one head can show (Connect.Android.Google),
# and that head carries it from the product's own repo (Vpnhood.App.Connect/promotions) as its own
# asset. Left here it would ride in nine heads that never play it, 1.8 MB each.
$adVideo = Join-Path $assetsDir "images/internal-ad.mp4";
if (Test-Path $adVideo) { Remove-Item $adVideo -Force; }

# a JSON array of names, by hand: ConvertTo-Json turns a one-element array into a bare string
function ConvertTo-JsonArray([string[]] $names) {
    return "[" + (($names | ForEach-Object { "`"$_`"" }) -join ",") + "]";
}

# ---- the words: a mirror of the locale files, and the list of them ----
New-Item -ItemType Directory $assetLocalesDir | Out-Null;
$localeFiles = @(Get-ChildItem $localesDir -Filter "*.json" | Sort-Object Name);
foreach ($file in $localeFiles) { Copy-Item $file.FullName $assetLocalesDir; }
[System.IO.File]::WriteAllText((Join-Path $assetLocalesDir "index.json"), (ConvertTo-JsonArray @($localeFiles | ForEach-Object { $_.BaseName })), $utf8);
Write-Host "Copied $($localeFiles.Count) locale files to assets/locales/.";

# ---- the fonts: the list of faces, since the collection is built by name ----
$fontsDir = Join-Path $assetsDir "fonts";
$fontFiles = @(Get-ChildItem $fontsDir -Filter "*.ttf" | Sort-Object Name);
[System.IO.File]::WriteAllText((Join-Path $fontsDir "index.json"), (ConvertTo-JsonArray @($fontFiles | ForEach-Object { $_.Name })), $utf8);
Write-Host "Listed $($fontFiles.Count) fonts in assets/fonts/index.json.";

# ---- the store as one file: what the package's targets place and ZipAssetProvider extracts ----
& (Join-Path $PSScriptRoot "_zip-assets.ps1");

# ---- Strings.g.cs: one member per key of en.json ----
$english = [System.IO.File]::ReadAllText((Join-Path $assetLocalesDir "en.json"), $utf8) | ConvertFrom-Json;

function Get-MemberName([string] $key) {
    $name = ($key -split "_" | ForEach-Object {
        if ($_.Length -eq 0) { "" }
        else { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1).ToLowerInvariant() }
    }) -join "";
    # a key may start with a digit (24_7_SUPPORT); a member may not
    if ($name -match "^\d") { $name = "_" + $name; }
    return $name;
}

function Get-DocText([string] $text) {
    $line = ($text -replace "\s+", " ").Trim();
    if ($line.Length -gt 120) { $line = $line.Substring(0, 117) + "..."; }
    return $line.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;");
}

$builder = New-Object System.Text.StringBuilder;
[void]$builder.AppendLine("// <auto-generated>");
[void]$builder.AppendLine("//     Written by _sync-assets.ps1 from assets/locales/en.json. Do not edit by hand:");
[void]$builder.AppendLine("//     the words live in the web UI's locale files, and this file follows them.");
[void]$builder.AppendLine("// </auto-generated>");
[void]$builder.AppendLine("");
[void]$builder.AppendLine("namespace VpnHood.AppUi.Common;");
[void]$builder.AppendLine("");
[void]$builder.AppendLine("public sealed partial class Strings");
[void]$builder.AppendLine("{");

$names = @{};
$count = 0;
foreach ($property in $english.PSObject.Properties) {
    $key = $property.Name;
    $text = [string]$property.Value;
    $name = Get-MemberName $key;
    if ($names.ContainsKey($name)) { throw "Two keys make the same member name '$name': '$key' and '$($names[$name])'."; }
    $names[$name] = $key;

    # vue-i18n's named placeholders, in the order the text uses them
    $placeholders = @();
    foreach ($match in [regex]::Matches($text, "{([A-Za-z][A-Za-z0-9]*)}")) {
        if ($placeholders -notcontains $match.Groups[1].Value) { $placeholders += $match.Groups[1].Value; }
    }

    if ($count -gt 0) { [void]$builder.AppendLine(""); }
    [void]$builder.AppendLine("    /// <summary>$(Get-DocText $text)</summary>");
    if ($placeholders.Count -eq 0) {
        [void]$builder.AppendLine("    public string $name => Get(`"$key`");");
    }
    else {
        $parameters = ($placeholders | ForEach-Object { "object $_" }) -join ", ";
        $arguments = ($placeholders | ForEach-Object { "(`"$_`", $_)" }) -join ", ";
        [void]$builder.AppendLine("    public string $name($parameters) => Get(`"$key`", $arguments);");
    }
    $count++;
}

[void]$builder.AppendLine("}");
[System.IO.File]::WriteAllText($stringsFile, $builder.ToString(), (New-Object System.Text.UTF8Encoding($true)));
Write-Host "Wrote $count members to Strings.g.cs.";
