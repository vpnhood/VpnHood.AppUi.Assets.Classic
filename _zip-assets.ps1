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
# nothing leaves ui.zip, and the stamp an app names its copy by, as they were.
#
# In front of the zip goes its stamp (ZipStamp in VpnHood.Net.Toolkit): "VHSTAMP:", 16 hex digits,
# "\n" - the first 16 hex digits of the SHA-256 of the whole file, taken while the digits were still
# zero - so a start reads those 25 bytes of the zip and no more. The zip goes right after it into the
# same file, so its offsets count the stamp and every zip tool still opens it. The browser page's
# _publish.ps1 writes the same, and the file written is checked as an app reads it.

$ErrorActionPreference = "Stop";

$assetsDir = Join-Path $PSScriptRoot "assets";
$zipPath = Join-Path $PSScriptRoot "buildTransitive/ui.zip";
if (!(Test-Path $assetsDir)) { throw "There is no assets folder beside this script. $assetsDir"; }

Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem;
if (Test-Path $zipPath) { Remove-Item $zipPath -Force; }

function Get-Stamp($stream) {
    $sha = [System.Security.Cryptography.SHA256]::Create();
    try { return -join ($sha.ComputeHash($stream)[0..7] | ForEach-Object { $_.ToString("x2") }); }
    finally { $sha.Dispose(); }
}

$stored = @(".ttf", ".webp", ".png", ".jpg", ".woff", ".woff2");
$entryTime = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero); # the zip format's first day
$names = [string[]]@(Get-ChildItem $assetsDir -Recurse -File | ForEach-Object { $_.FullName.Substring($assetsDir.Length + 1).Replace("\", "/") });
[Array]::Sort($names, [StringComparer]::Ordinal);
$magic = [System.Text.Encoding]::ASCII.GetBytes("VHSTAMP:");
$file = [System.IO.File]::Create($zipPath);
try {
    # the stamp's space, its digits zero until the file is hashed
    $file.Write($magic, 0, $magic.Length);
    $file.Write([byte[]]::new(16), 0, 16);
    $file.WriteByte(10);

    $zip = [System.IO.Compression.ZipArchive]::new($file, [System.IO.Compression.ZipArchiveMode]::Create, $true);
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

    $file.Position = 0;
    $stamp = Get-Stamp $file;
    $file.Position = $magic.Length;
    $file.Write([System.Text.Encoding]::ASCII.GetBytes($stamp), 0, 16);
}
finally { $file.Dispose(); }

# as an app reads it: the stamp in front, the file's hash with its digits zero, and the zip behind it
$bytes = [System.IO.File]::ReadAllBytes($zipPath);
$head = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 25);
[Array]::Clear($bytes, $magic.Length, 16);
if ($head -ne "VHSTAMP:$stamp`n" -or (Get-Stamp ([System.IO.MemoryStream]::new($bytes))) -ne $stamp) { throw "ui.zip does not begin with its stamp, $stamp."; }
$archive = [System.IO.Compression.ZipFile]::OpenRead($zipPath);
try { $count = $archive.Entries.Count; } finally { $archive.Dispose(); }
if ($count -ne $names.Count) { throw "ui.zip opens with $count files rather than $($names.Count)."; }

Write-Host "Zipped $($names.Count) files into buildTransitive/ui.zip ($([math]::Round((Get-Item $zipPath).Length / 1MB, 1)) MB), stamp $stamp.";
