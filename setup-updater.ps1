# One-time setup for Galaxy's in-app updates.
# Makes the signing key that proves updates really come from you, and puts the
# public half into apps\app\tauri-galaxy.conf.json.
#
#   powershell -ExecutionPolicy Bypass -File .\setup-updater.ps1
#
# BACK UP %USERPROFILE%\.galaxy\updater.key AND REMEMBER THE PASSWORD.
# If you lose either one, people who installed Galaxy can never auto-update again.

param(
	[string]$Owner = 'Funroe-alt',
	[string]$RepoName = 'galaxy-app'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$keyDir = Join-Path $env:USERPROFILE '.galaxy'
$key = Join-Path $keyDir 'updater.key'
$utf8 = New-Object System.Text.UTF8Encoding $false

if (Test-Path $key) {
	Write-Host "A key already exists at $key - using it." -ForegroundColor Yellow
} else {
	New-Item -ItemType Directory -Force -Path $keyDir | Out-Null
	$pw = Read-Host 'Pick a password for your update key (you will need it for every release)'
	if (-not $pw) { Write-Host 'Password cannot be empty.' -ForegroundColor Red; exit 1 }
	Push-Location (Join-Path $repo 'apps\app')
	pnpm tauri signer generate --ci -p $pw -w $key
	Pop-Location
	if (-not (Test-Path "$key.pub")) { Write-Host 'Key was not created.' -ForegroundColor Red; exit 1 }
}

$pub = ([System.IO.File]::ReadAllText("$key.pub")).Trim()
$confPath = Join-Path $repo 'apps\app\tauri-galaxy.conf.json'
$conf = [System.IO.File]::ReadAllText($confPath)
$conf = [regex]::Replace($conf, '"pubkey": "[^"]*"', ('"pubkey": "' + $pub + '"'))
$conf = [regex]::Replace($conf, 'https://github\.com/[^/]+/[^/]+/releases/latest/download/latest\.json', "https://github.com/$Owner/$RepoName/releases/latest/download/latest.json")
[System.IO.File]::WriteAllText($confPath, $conf, $utf8)

Write-Host "`nUpdater ready." -ForegroundColor Green
Write-Host "Updates will be checked at: https://github.com/$Owner/$RepoName/releases/latest/download/latest.json"
Write-Host "Back up this folder somewhere safe: $keyDir" -ForegroundColor Yellow
