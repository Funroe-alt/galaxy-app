# Builds a signed Galaxy installer and the latest.json file the in-app updater reads.
#
# 1. Bump "version" in apps\app-frontend\package.json (e.g. 1.0.0 -> 1.0.1)
# 2. powershell -ExecutionPolicy Bypass -File .\release-galaxy.ps1 -Notes "What changed"
#
# If the GitHub CLI (gh) is installed and logged in, it also publishes the release.
# Otherwise it tells you which 2 files to upload.

param(
	[string]$Owner = 'Funroe-alt',
	[string]$RepoName = 'galaxy-app',
	[string]$Notes = 'Bug fixes and improvements'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$key = Join-Path $env:USERPROFILE '.galaxy\updater.key'
$utf8 = New-Object System.Text.UTF8Encoding $false

if (-not (Test-Path $key)) {
	Write-Host 'No update key yet. Run setup-updater.ps1 first.' -ForegroundColor Red
	exit 1
}
$conf = [System.IO.File]::ReadAllText((Join-Path $repo 'apps\app\tauri-galaxy.conf.json'))
if ($conf.Contains('RUN_setup-updater.ps1_FIRST')) {
	Write-Host 'Run setup-updater.ps1 first.' -ForegroundColor Red
	exit 1
}

$version = (Get-Content (Join-Path $repo 'apps\app-frontend\package.json') -Raw | ConvertFrom-Json).version
Write-Host "Building Galaxy Launcher $version" -ForegroundColor Cyan

$env:TAURI_SIGNING_PRIVATE_KEY = ([System.IO.File]::ReadAllText($key)).Trim()
$env:TAURI_SIGNING_PRIVATE_KEY_PASSWORD = Read-Host 'Update key password'
$env:CARGO_BUILD_JOBS = '1'

Push-Location (Join-Path $repo 'apps\app')
pnpm tauri build --config tauri-galaxy.conf.json --bundles nsis
$ok = $LASTEXITCODE -eq 0
Pop-Location
if (-not $ok) { Write-Host 'Build failed - scroll up for the first error.' -ForegroundColor Red; exit 1 }

$nsis = Join-Path $repo 'target\release\bundle\nsis'
$exe = Get-ChildItem $nsis -Filter "*_${version}_x64-setup.exe" | Select-Object -First 1
if (-not $exe) { Write-Host "Couldn't find the installer in $nsis" -ForegroundColor Red; exit 1 }
$sigPath = "$($exe.FullName).sig"
if (-not (Test-Path $sigPath)) { Write-Host "Installer wasn't signed (no .sig file). Check the password." -ForegroundColor Red; exit 1 }

$outDir = Join-Path $repo "release\v$version"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$assetName = "Galaxy-Launcher_${version}_x64-setup.exe"
$assetPath = Join-Path $outDir $assetName
Copy-Item $exe.FullName $assetPath -Force

$latest = [ordered]@{
	version   = $version
	notes     = $Notes
	pub_date  = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
	platforms = [ordered]@{
		'windows-x86_64' = [ordered]@{
			signature = ([System.IO.File]::ReadAllText($sigPath)).Trim()
			url       = "https://github.com/$Owner/$RepoName/releases/download/v$version/$assetName"
		}
	}
}
$latestPath = Join-Path $outDir 'latest.json'
[System.IO.File]::WriteAllText($latestPath, ($latest | ConvertTo-Json -Depth 5), $utf8)

Write-Host "`nRelease files are in $outDir" -ForegroundColor Green
if (Get-Command gh -ErrorAction SilentlyContinue) {
	gh release create "v$version" $assetPath $latestPath --repo "$Owner/$RepoName" --title "Galaxy Launcher $version" --notes $Notes
	if ($LASTEXITCODE -eq 0) { Write-Host 'Published! Everyone on an older version will get the update.' -ForegroundColor Green }
} else {
	Write-Host "`nTo publish: go to https://github.com/$Owner/$RepoName/releases/new"
	Write-Host "  Tag: v$version"
	Write-Host "  Upload BOTH files: $assetName and latest.json"
	Write-Host '  Click Publish release.'
}
