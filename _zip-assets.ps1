# Packs assets/ into ui.zip - the one file the package ships and every app places.
#
# Run it after changing anything under assets/, and commit both: the folder is what a person edits,
# the zip is what an app reads, and a build places the zip without looking at the folder. They are
# committed together because git keeps no timestamps, so nothing can tell a stale zip from a fresh
# one after a clone; keeping them in step is the committer's job, not a guess at build time.
#
# Already-compressed formats are stored rather than deflated, so reading one back is a copy; the
# text deflates. Entries are ordered by path so the same files make the same zip.

$ErrorActionPreference = "Stop";

$assetsDir = Join-Path $PSScriptRoot "assets";
$zipPath = Join-Path $PSScriptRoot "ui.zip";
if (!(Test-Path $assetsDir)) { throw "There is no assets folder beside this script. $assetsDir"; }

Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem;
if (Test-Path $zipPath) { Remove-Item $zipPath -Force; }

$stored = @(".ttf", ".webp", ".png", ".jpg", ".woff", ".woff2");
$files = @(Get-ChildItem $assetsDir -Recurse -File | Sort-Object { $_.FullName.Substring($assetsDir.Length).Replace("\", "/") });
$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create);
try {
    foreach ($file in $files) {
        $entryName = $file.FullName.Substring($assetsDir.Length + 1).Replace("\", "/");
        $level = if ($stored -contains $file.Extension.ToLowerInvariant()) { [System.IO.Compression.CompressionLevel]::NoCompression } else { [System.IO.Compression.CompressionLevel]::Optimal };
        [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $entryName, $level);
    }
}
finally { $zip.Dispose(); }

Write-Host "Zipped $($files.Count) files into ui.zip ($([math]::Round((Get-Item $zipPath).Length / 1MB, 1)) MB).";
