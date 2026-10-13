# Packs assets/ into ui.zip - the one file the package ships and every app places.
#
# Run it after changing anything under assets/, and commit both: the folder is what a person edits,
# the zip is what an app reads, and a build places the zip without looking at the folder. They are
# committed together because git keeps no timestamps, so nothing can tell a stale zip from a fresh
# one after a clone; keeping them in step is the committer's job, not a guess at build time.
#
# Already-compressed formats are stored rather than deflated, so reading one back is a copy; the
# text deflates. Entries are ordered by path, ordinal, and all carry one time rather than their
# file's - a copy or a checkout rewrites that, the content does not - so the same files make the
# same zip on the same OS (.NET marks each entry with the system that made it): a run that changes
# nothing leaves ui.zip, and the version an app reads from its hash, as they were.

$ErrorActionPreference = "Stop";

$assetsDir = Join-Path $PSScriptRoot "assets";
$zipPath = Join-Path $PSScriptRoot "buildTransitive/ui.zip";
if (!(Test-Path $assetsDir)) { throw "There is no assets folder beside this script. $assetsDir"; }

Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem;
if (Test-Path $zipPath) { Remove-Item $zipPath -Force; }

$stored = @(".ttf", ".webp", ".png", ".jpg", ".woff", ".woff2");
$entryTime = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero); # the zip format's first day
$names = [string[]]@(Get-ChildItem $assetsDir -Recurse -File | ForEach-Object { $_.FullName.Substring($assetsDir.Length + 1).Replace("\", "/") });
[Array]::Sort($names, [StringComparer]::Ordinal);
$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create);
try {
    foreach ($name in $names) {
        $level = if ($stored -contains [System.IO.Path]::GetExtension($name).ToLowerInvariant()) { [System.IO.Compression.CompressionLevel]::NoCompression } else { [System.IO.Compression.CompressionLevel]::Optimal };
        $entry = $zip.CreateEntry($name, $level);
        $entry.LastWriteTime = $entryTime;
        $target = $entry.Open();
        try {
            $source = [System.IO.File]::OpenRead((Join-Path $assetsDir $name));
            try { $source.CopyTo($target); } finally { $source.Dispose(); }
        }
        finally { $target.Dispose(); }
    }
}
finally { $zip.Dispose(); }

Write-Host "Zipped $($names.Count) files into buildTransitive/ui.zip ($([math]::Round((Get-Item $zipPath).Length / 1MB, 1)) MB).";
