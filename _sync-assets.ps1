# Brings what follows from assets/ back in step with it: the lists of languages and faces, the one
# file the package places and the C# side of the words. Run it after a change that adds or removes a
# language, a face or a word; any other change in assets/ needs only _zip-assets.ps1 beside this file.
#
#   assets/locales/index.json, assets/fonts/index.json   the languages, the faces: a list rather
#                         than a listing, because a provider answers by name and never enumerates
#   buildTransitive/ui.zip  <- assets/, by _zip-assets.ps1: the store as the package's targets
#                         place it (assets/ui.zip) and ZipAssetProvider extracts it, its hash its version
#   ../VpnHood.AppUi.Common/Strings.g.cs   one member per key of en.json - the C# side of the words, which
#                         belongs to the app repo's services module, not to this store. Written only
#                         when this store sits in that checkout as a submodule; skipped otherwise.
#
# In that checkout it also checks the images: one the UI asks for by name that this store has not
# throws when its page opens, so a rename on either side stops here rather than on a device.
#
# Both assets/ and ui.zip are committed here, so review what this changes before committing it.
#
# Every file is read and written with an explicit UTF-8 encoding: Windows PowerShell would
# otherwise read these files as ANSI and double-encode every non-ASCII word in them. Paths use
# forward slashes, because this also runs under pwsh on Linux.

$ErrorActionPreference = "Stop";

$assetsDir = Join-Path $PSScriptRoot "assets";
$assetLocalesDir = Join-Path $assetsDir "locales";
$stringsFile = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../VpnHood.AppUi.Common/Strings.g.cs"));
$hasAppRepo = Test-Path (Split-Path $stringsFile -Parent);
$utf8 = New-Object System.Text.UTF8Encoding($false);

# a JSON array of names, by hand: ConvertTo-Json turns a one-element array into a bare string
function ConvertTo-JsonArray([string[]] $names) {
    return "[" + (($names | ForEach-Object { "`"$_`"" }) -join ",") + "]";
}

# ---- the words: the list of them ----
$localeFiles = @(Get-ChildItem $assetLocalesDir -Filter "*.json" | Where-Object { $_.Name -ne "index.json" } | Sort-Object Name);
[System.IO.File]::WriteAllText((Join-Path $assetLocalesDir "index.json"), (ConvertTo-JsonArray @($localeFiles | ForEach-Object { $_.BaseName })), $utf8);
Write-Host "Listed $($localeFiles.Count) languages in assets/locales/index.json.";

# ---- the fonts: the list of faces, since the collection is built by name ----
$fontsDir = Join-Path $assetsDir "fonts";
$fontFiles = @(Get-ChildItem $fontsDir -Filter "*.ttf" | Sort-Object Name);
[System.IO.File]::WriteAllText((Join-Path $fontsDir "index.json"), (ConvertTo-JsonArray @($fontFiles | ForEach-Object { $_.Name })), $utf8);
Write-Host "Listed $($fontFiles.Count) fonts in assets/fonts/index.json.";

# ---- the store as one file: what the package's targets place and ZipAssetProvider extracts ----
& (Join-Path $PSScriptRoot "_zip-assets.ps1");

# ---- Strings.g.cs: one member per key of en.json ----
if (!$hasAppRepo) {
    Write-Host "No app repo around this store: Strings.g.cs left alone.";
    return;
}

# ---- the images: every file name the UI asks this store for ----
# Both forms the UI writes are a quoted file name: ui:AppImage.Source="images/name.webp" in XAML, and
# the string a page hands to AppAssets, with or without the store's images/ prefix. An app names one
# in its options builder (LogoAssetPath), only in the prefixed form: a bare name in a head is not a
# store path. Flags are not here - they are named by country code, never by file - and neither is a
# name built at run time from the theme (future-apps-{UiTheme}.png), which this cannot see.
function Get-ImageNames([string] $folder, [string] $pattern) {
    $sourceFiles = Get-ChildItem $folder -Recurse -Include *.cs, *.axaml | Where-Object { $_.FullName -notmatch "[\\/](bin|obj)[\\/]" };
    foreach ($file in $sourceFiles) {
        foreach ($match in [regex]::Matches([System.IO.File]::ReadAllText($file.FullName, $utf8), $pattern)) { $match.Groups[1].Value; }
    }
}
$uiDir = Join-Path $PSScriptRoot "../VpnHood.AppUi.Presentation.Classic.Avalonia";
$appsDir = Join-Path $PSScriptRoot "../../Apps";
$imageNames = @(Get-ImageNames $uiDir '"(?:images/)?([\w.-]+\.(?:webp|png|svg|mp4))"') + @(Get-ImageNames $appsDir '"images/([\w.-]+\.(?:webp|png|svg|mp4))"');
$missingImages = @($imageNames | Sort-Object -Unique | Where-Object { !(Test-Path (Join-Path $assetsDir "images/$_")) });
if ($missingImages.Count -gt 0) { throw "The UI asks for images this store has not: $($missingImages -join ', ')."; }

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
[void]$builder.AppendLine("//     the words live in VpnHood.AppUi.Assets.Classic's locale files, and this file follows them.");
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

    # the named placeholders, in the order the text uses them
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
