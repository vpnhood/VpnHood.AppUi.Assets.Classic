# Packs and pushes VpnHood.AppUi.Assets.Classic - the store of the classic look - to nuget.org.
#
# This one package is published from here rather than by the nuget workflow, because the workflow
# checks out this repo alone and the store is not in this repo: ui.zip is .gitignored and built by
# _sync-assets.ps1 from the SPA's `npm run build` next door. A CI pack would therefore produce a
# package with the targets but no bytes, which installs cleanly and starts a head with no images and
# no words - so the project keeps <IsPackable>false</IsPackable> to stay out of
# pub/lib/Publish-NugetPackages.ps1's sweep, and this script overrides it for the one pack it runs.
# When the store becomes a submodule of this repo, both halves of that arrangement can go away.
#
# Run it after a bump, or whenever the look changes:
#
#   cd <Vh>/VpnHood.AppUi.Spa/src/VpnHood.AppUi.Presentation.Classic.Spa; npm run build
#   cd <Vh>/VpnHood/src/AppUi/Assets/Classic; ./_sync-assets.ps1; ./_publish.ps1
#
# The version is the product version in pub/PubVersion.json, the same one the libraries carry, so a
# consumer pins one number for everything. Consumers of the package: the SPA repo's sample heads
# (VpnHood.AppUi.Spa), and any fork building a head outside this repo. The heads IN this repo take
# the store from the project itself and never from the package.

param(
	# Pack only, do not push. Prints where the .nupkg landed so its contents can be inspected.
	[switch]$noPush
);

. "$PSScriptRoot/../../../../pub/lib/Common.ps1"

$projectFile = Join-Path $PSScriptRoot "VpnHood.AppUi.Assets.Classic.csproj";
$zipFile = Join-Path $PSScriptRoot "ui.zip";
$outDir = Join-Path $pubDir "bin/nuget-assets";

# The store must exist AND be newer than what it was built from. A published package with a stale
# store is the failure that has no symptom at build time: the app asks for an image added last week
# and gets a 404 at runtime, on the consumer's machine and not on ours.
if (!(Test-Path $zipFile)) {
	throw "There is no ui.zip. Build the SPA and run _sync-assets.ps1 first.";
}
$spaDistDir = Join-Path $solutionDir "../VpnHood.AppUi.Spa/src/VpnHood.AppUi.Presentation.Classic.Spa/dist";
if (Test-Path $spaDistDir) {
	$zipTime = (Get-Item $zipFile).LastWriteTimeUtc;
	$newer = @(Get-ChildItem $spaDistDir -Recurse -File | Where-Object { $_.LastWriteTimeUtc -gt $zipTime });
	if ($newer.Count -gt 0) {
		throw "ui.zip is older than the SPA's build ($($newer.Count) newer file(s), e.g. $($newer[0].Name)). Run _sync-assets.ps1 first.";
	}
}

Write-Host "Packing VpnHood.AppUi.Assets.Classic $versionParam (store: $([math]::Round((Get-Item $zipFile).Length / 1MB, 1)) MB)" -ForegroundColor Cyan;
Remove-Item $outDir -Recurse -Force -ErrorAction Ignore;
dotnet pack $projectFile -c Release -o $outDir -p:Version=$versionParam -p:IsPackable=true;
if ($LASTEXITCODE -gt 0) { throw "dotnet pack failed with exit code $LASTEXITCODE."; }

# No Authenticode signing step: there is no assembly in this package to sign.
$package = Get-ChildItem $outDir -File -Filter "*.nupkg" | Select-Object -First 1;
if (!$package) { throw "pack produced no .nupkg in $outDir."; }

if ($noPush) {
	Write-Host "Packed (not pushed): $($package.FullName)" -ForegroundColor Yellow;
	return;
}

if ([string]::IsNullOrWhiteSpace($nugetApiKey)) {
	throw "NuGet API key is missing. Put it in .user/nuget_api_key.txt.";
}
if ($prerelease) {
	Write-Host "PubVersion.json says this version is a PRERELEASE." -ForegroundColor Yellow;
}

dotnet nuget push $package.FullName --source "https://api.nuget.org/v3/index.json" --api-key $nugetApiKey --skip-duplicate;
if ($LASTEXITCODE -gt 0) { throw "push failed: $($package.Name)"; }
Write-Host "Pushed $($package.Name)." -ForegroundColor Green;
