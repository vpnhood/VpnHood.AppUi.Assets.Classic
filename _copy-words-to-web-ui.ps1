# Gives the web UI its copy of the words: the locale files and the content documents, which are
# written and translated in this store (README, "The words") and nowhere else.
#
#   <WebUI>/src/locales/*.json  <- assets/locales/*.json, all but index.json - the store's list of
#                                  its languages, which the web UI's build makes for itself
#   <WebUI>/src/content/        <- assets/content/, every language's documents
#
# Both are mirrored (a file gone here is gone there); the web UI's other files in src/locales
# (i18n.ts) are left alone. The files are copied as bytes, so the copy is the store's exactly.
# Commit it in VpnHood.AppUi.Spa as well - and never edit it there, since the next copy undoes it.

param(
    # The SPA project that carries the copy: beside this repo on a developer's machine.
    [string] $WebUiDir = ""
)

$ErrorActionPreference = "Stop";

if ($WebUiDir -eq "") {
    # <Vh>/VpnHood/src/AppUi/VpnHood.AppUi.Assets.Classic -> <Vh>
    $vhFolder = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../../../.."));
    $WebUiDir = Join-Path $vhFolder "VpnHood.AppUi.Spa/src/VpnHood.AppUi.Presentation.Classic.Spa";
}
$localesDir = Join-Path $PSScriptRoot "assets/locales";
$contentDir = Join-Path $PSScriptRoot "assets/content";
$webLocalesDir = Join-Path $WebUiDir "src/locales";
$webContentDir = Join-Path $WebUiDir "src/content";

if (!(Test-Path (Join-Path $localesDir "en.json"))) { throw "This store has no words. $localesDir"; }
if (!(Test-Path $webLocalesDir)) { throw "The web UI's locales are not there. $webLocalesDir"; }

# ---- the words: one file per language ----
$localeFiles = @(Get-ChildItem $localesDir -Filter "*.json" | Where-Object { $_.Name -ne "index.json" });
Get-ChildItem $webLocalesDir -Filter "*.json" | Remove-Item -Force;
foreach ($file in $localeFiles) { Copy-Item $file.FullName $webLocalesDir; }
Write-Host "Copied $($localeFiles.Count) locale files to $webLocalesDir.";

# ---- the documents: a folder per language ----
if (Test-Path $webContentDir) { Remove-Item $webContentDir -Recurse -Force; }
Copy-Item $contentDir $webContentDir -Recurse;
Write-Host "Copied $(@(Get-ChildItem $webContentDir -Recurse -File).Count) documents to $webContentDir.";
