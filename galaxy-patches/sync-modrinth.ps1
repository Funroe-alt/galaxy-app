# Pulls Modrinth's latest app improvements into Galaxy.
# Your users then get them the next time you publish a Galaxy release.
#
#   powershell -ExecutionPolicy Bypass -File .\sync-modrinth.ps1

$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $repo

if (git status --porcelain) {
	Write-Host 'Save your own changes first:' -ForegroundColor Yellow
	Write-Host '  git add -A'
	Write-Host '  git commit -m "My Galaxy changes"'
	Pop-Location
	exit 1
}

if ((git remote) -notcontains 'upstream') {
	git remote add upstream https://github.com/modrinth/code.git
}
Write-Host 'Downloading Modrinth changes...' -ForegroundColor Cyan
git fetch upstream
git merge upstream/main --no-edit

if ($LASTEXITCODE -ne 0) {
	Write-Host "`nSome files were changed by both you and Modrinth (merge conflicts):" -ForegroundColor Yellow
	git diff --name-only --diff-filter=U
	Write-Host "`nOpen the project in IntelliJ: Git > Resolve Conflicts. Keep the Galaxy version of"
	Write-Host 'names/colors/logo, and Modrinth''s version of everything else. Then:'
	Write-Host '  git add -A; git commit --no-edit'
} else {
	Write-Host "`nModrinth's changes are in." -ForegroundColor Green
}
Write-Host "`nThen:"
Write-Host '  1. Run galaxy-patches\install-galaxy.ps1 again (re-applies any Galaxy edits Modrinth overwrote)'
Write-Host '  2. pnpm install'
Write-Host '  3. Test with pnpm app:dev'
Write-Host '  4. Bump the version and run release-galaxy.ps1'
Pop-Location
