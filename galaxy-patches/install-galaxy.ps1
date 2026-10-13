# Galaxy update installer
# Copies the new Galaxy files into your galaxy-app folder and makes the small
# edits to Modrinth's files for you. Safe to run more than once: anything that is
# already done gets skipped.
#
# Run it from this folder:
#   powershell -ExecutionPolicy Bypass -File .\install-galaxy.ps1
# or, if your galaxy-app is somewhere else:
#   powershell -ExecutionPolicy Bypass -File .\install-galaxy.ps1 -Repo "D:\path\to\galaxy-app"

param(
	[string]$Repo = "$env:USERPROFILE\Documents\galaxy-app"
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8 = New-Object System.Text.UTF8Encoding $false
$script:done = 0
$script:skipped = 0
$script:manual = @()

if (-not (Test-Path (Join-Path $Repo (('apps\app\tauri.conf.json').Replace('\', [System.IO.Path]::DirectorySeparatorChar))))) {
	Write-Host "Can't find galaxy-app at: $Repo" -ForegroundColor Red
	Write-Host 'Run again with -Repo "C:\path\to\galaxy-app"'
	exit 1
}

function Fix-Path($rel) {
	return $rel.Replace('\', [System.IO.Path]::DirectorySeparatorChar)
}

function Read-Text($rel) {
	$path = Join-Path $Repo (Fix-Path $rel)
	$text = [System.IO.File]::ReadAllText($path)
	$crlf = $text.Contains("`r`n")
	return @{ Path = $path; Text = $text.Replace("`r`n", "`n"); Crlf = $crlf }
}

function Write-Text($file) {
	$out = $file.Text
	if ($file.Crlf) { $out = $out.Replace("`n", "`r`n") }
	[System.IO.File]::WriteAllText($file.Path, $out, $utf8)
}

# Literal find/replace. $already = text that only exists once the change is made.
function Patch($rel, $find, $replace, $already, $what) {
	$f = Read-Text $rel
	$findN = $find.Replace("`r`n", "`n")
	$alreadyN = if ($already) { $already.Replace("`r`n", "`n") } else { $null }
	if (($alreadyN -and $f.Text.Contains($alreadyN)) -or (-not $alreadyN -and -not $f.Text.Contains($findN))) {
		Write-Host "  skip  $what (already done)" -ForegroundColor DarkGray
		$script:skipped++
		return
	}
	$find = $findN
	$idx = $f.Text.IndexOf($find)
	if ($idx -lt 0) {
		Write-Host "  ????  $what - couldn't find the spot, do this one by hand" -ForegroundColor Yellow
		$script:manual += "$rel : $what"
		return
	}
	$f.Text = $f.Text.Substring(0, $idx) + $replace.Replace("`r`n", "`n") + $f.Text.Substring($idx + $find.Length)
	Write-Text $f
	Write-Host "  done  $what" -ForegroundColor Green
	$script:done++
}

# Regex find/replace (first match).
function PatchRegex($rel, $pattern, $replace, $already, $what) {
	$f = Read-Text $rel
	if ($already -and $f.Text.Contains($already.Replace("`r`n", "`n"))) {
		Write-Host "  skip  $what (already done)" -ForegroundColor DarkGray
		$script:skipped++
		return
	}
	$rx = New-Object System.Text.RegularExpressions.Regex($pattern, 'Singleline')
	if (-not $rx.IsMatch($f.Text)) {
		Write-Host "  ????  $what - couldn't find the spot, do this one by hand" -ForegroundColor Yellow
		$script:manual += "$rel : $what"
		return
	}
	$f.Text = $rx.Replace($f.Text, $replace.Replace("`r`n", "`n"), 1)
	Write-Text $f
	Write-Host "  done  $what" -ForegroundColor Green
	$script:done++
}

# Removes text if present (no warning when it's not there).
function RemoveRegex($rel, $pattern, $what) {
	$f = Read-Text $rel
	$rx = New-Object System.Text.RegularExpressions.Regex($pattern, 'Singleline')
	if ($rx.IsMatch($f.Text)) {
		$f.Text = $rx.Replace($f.Text, '')
		Write-Text $f
		Write-Host "  done  $what" -ForegroundColor Green
		$script:done++
	}
}

# ---------------------------------------------------------------------------
Write-Host "`n[1/6] Copying new Galaxy files" -ForegroundColor Cyan
$filesRoot = Join-Path $here 'files'
Get-ChildItem $filesRoot -Recurse -File | ForEach-Object {
	$rel = $_.FullName.Substring($filesRoot.Length + 1)
	$dest = Join-Path $Repo $rel
	New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
	Copy-Item $_.FullName $dest -Force
	Write-Host "  copy  $rel" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
Write-Host "`n[2/6] Name, version and colors" -ForegroundColor Cyan
$conf = 'apps\app\tauri.conf.json'
Patch $conf '"productName": "Modrinth App"' '"productName": "Galaxy Launcher"' '"productName": "Galaxy Launcher"' 'app name'
Patch $conf '"mainBinaryName": "Modrinth App"' '"mainBinaryName": "Galaxy Launcher"' '"mainBinaryName": "Galaxy Launcher"' 'exe name'
Patch $conf '"identifier": "ModrinthApp"' '"identifier": "GalaxyLauncher"' '"identifier": "GalaxyLauncher"' 'own data folder'
Patch $conf '"title": "Modrinth App"' '"title": "Galaxy Launcher"' '"title": "Galaxy Launcher"' 'window title'

Patch 'apps\app-frontend\package.json' '"version": "1.0.0-local"' '"version": "1.0.0"' '"version": "1.0.0"' 'version number (fixes the .exe build)'

$vars = 'packages\assets\styles\variables.scss'
Patch $vars '--surface-1: #16181c;' '--surface-1: #0e0b1a;' '--surface-1: #0e0b1a;' 'dark background 1'
Patch $vars '--surface-2: #1d1f23;' '--surface-2: #151127;' '--surface-2: #151127;' 'dark background 2'
Patch $vars '--surface-3: #27292e;' '--surface-3: #1e1838;' '--surface-3: #1e1838;' 'dark background 3'
PatchRegex $vars '(:root\[data-theme=''dark''\] \{.*?)--color-brand: var\(--color-green\);\s*--color-brand-highlight: rgba\(27, 217, 106, 0\.25\);\s*--color-brand-shadow: rgba\(27, 217, 106, 0\.7\);' "`$1--color-brand: #8b5cf6;`n`t--color-brand-highlight: rgba(139, 92, 246, 0.25);`n`t--color-brand-shadow: rgba(139, 92, 246, 0.7);" 'rgba(139, 92, 246, 0.25)' 'purple accent'
Patch $vars 'var(--color-brand) 0%, #1ffa9a 100%)' 'var(--color-brand) 0%, #d946ef 100%)' '#d946ef 100%)' 'loading bar'

# ---------------------------------------------------------------------------
Write-Host "`n[3/6] Galaxy style settings (background, blur, accent, font, pride)" -ForegroundColor Cyan
RemoveRegex 'apps\app-frontend\src\composables\use-theme.ts' '\n?// Pride month \(June\): turns on the rainbow accents\s*\nif \(new Date\(\)\.getMonth\(\)[^)]*\)\s*\{[^}]*\}\s*' 'removed old pride code from use-theme.ts'

$main = 'apps\app-frontend\src\main.js'
Patch $main "import 'overlayscrollbars/overlayscrollbars.css'" "import 'overlayscrollbars/overlayscrollbars.css'`nimport '@/assets/galaxy.scss'" "import '@/assets/galaxy.scss'" 'load galaxy.scss'
Patch $main "import '@/assets/galaxy.scss'" "import '@/assets/galaxy.scss'`nimport '@/composables/use-galaxy-style.ts'" "import '@/composables/use-galaxy-style.ts'" 'load Galaxy style at startup'

$app = 'apps\app-frontend\src\components\ui\settings\display\AppearanceSettings.vue'
RemoveRegex $app "\nimport \{ useGalaxyStyle \} from '@/composables/use-galaxy-style\.ts'" 'removed old pride import'
RemoveRegex $app "\nconst \{ prideTheme, prideAutoJune \} = useGalaxyStyle\(\)\n?" 'removed old pride variables'
RemoveRegex $app "\n\s*Toggle,(?=[^}]*\} from '@modrinth/ui')" 'removed unused Toggle import'
Patch $app "import { appSettingsModalContextKey } from '@/providers/app-settings-modal'" "import { appSettingsModalContextKey } from '@/providers/app-settings-modal'`n`nimport GalaxyStyleSettings from './GalaxyStyleSettings.vue'" 'import GalaxyStyleSettings' 'import Galaxy settings'
PatchRegex $app '<template>.*</template>' "<template>`n`t<AppearanceSettingsLayout />`n`t<GalaxyStyleSettings />`n</template>" '<GalaxyStyleSettings />' 'show Galaxy settings section'

# ---------------------------------------------------------------------------
Write-Host "`n[4/6] Remove Modrinth ads, news, Modrinth+ and Hosting; add Galaxy logo" -ForegroundColor Cyan
$appVue = 'apps\app-frontend\src\App.vue'
PatchRegex $appVue 'const showAd = computed\(\s*\(\) => sidebarVisible\.value && !hasPlus\.value && credentials\.value !== undefined,?\s*\)' 'const showAd = computed(() => false)' 'const showAd = computed(() => false)' 'turn off ads'
PatchRegex $appVue 'const adConsentAvailable = computed\(\(\) => credentials\.value !== undefined && !hasPlus\.value\)' 'const adConsentAvailable = computed(() => false)' 'const adConsentAvailable = computed(() => false)' 'turn off ad consent popup'
Patch $appVue 'v-if="news && news.length > 0"' 'v-if="false"' $null 'hide News'
Patch $appVue 'shown: !hasPlus.value,' 'shown: false,' $null 'hide Upgrade to Modrinth+'
Patch $appVue 'v-tooltip.right="formatMessage(messages.modrinthHosting)"' "v-if=`"false`"`n`t`t`t`tv-tooltip.right=`"formatMessage(messages.modrinthHosting)`"" ('v-if="false"' + "`n`t`t`t`t" + 'v-tooltip.right="formatMessage(messages.modrinthHosting)"') 'hide Modrinth Hosting button'
Patch $appVue '<TextLogo class="h-7 w-auto shrink-0 text-contrast pointer-events-none" />' '<span class="galaxy-wordmark h-7 flex items-center shrink-0 pointer-events-none select-none text-xl font-extrabold">✦ Galaxy</span>' 'galaxy-wordmark' 'Galaxy logo in the top bar'

# ---------------------------------------------------------------------------
Write-Host "`n[5/6] CurseForge + FTB search page, faster downloads" -ForegroundColor Cyan
Patch $appVue "`tCompassIcon," "`tCompassIcon,`n`tPackageSearchIcon," 'PackageSearchIcon,' 'icon for the new page'
PatchRegex $appVue '(<CompassIcon />\s*</NavButton>)' "`$1`n`t`t`t<NavButton v-tooltip.right=`"'CurseForge & FTB'`" to=`"/galaxy-browse`">`n`t`t`t`t<PackageSearchIcon />`n`t`t`t</NavButton>" 'to="/galaxy-browse"' 'sidebar button for CurseForge & FTB'
PatchRegex 'apps\app-frontend\src\routes.js' "(component: \(\) => import\('@/pages/Browse\.vue'\),\s*\},)" "`$1`n`t`t{`n`t`t`tpath: '/galaxy-browse',`n`t`t`tname: 'Galaxy browse',`n`t`t`tcomponent: () => import('@/pages/GalaxyBrowse.vue'),`n`t`t}," "/galaxy-browse" 'page route'
PatchRegex 'apps\app-frontend\src\components\ui\settings\instances\ResourceManagementSettings.vue' '(id="max-downloads".*?:max=")10(")' '${1}64${2}' ('v-model="settings.max_concurrent_downloads"' + "`n`t`t`t`t" + ':min="1"' + "`n`t`t`t`t" + ':max="64"') 'allow up to 64 downloads at once'

Write-Host "`n[5b] Servers tab + server status in the sidebar" -ForegroundColor Cyan
PatchRegex $appVue '(<PackageSearchIcon />\s*</NavButton>)' "`$1`n`t`t`t<NavButton v-tooltip.right=`"'Servers'`" to=`"/galaxy-servers`">`n`t`t`t`t<ServerStackIcon />`n`t`t`t</NavButton>" 'to="/galaxy-servers"' 'Servers tab in the sidebar'
PatchRegex 'apps\app-frontend\src\routes.js' "(component: \(\) => import\('@/pages/GalaxyBrowse\.vue'\),\s*\},)" "`$1`n`t`t{`n`t`t`tpath: '/galaxy-servers',`n`t`t`tname: 'Galaxy servers',`n`t`t`tcomponent: () => import('@/pages/GalaxyServers.vue'),`n`t`t}," "/galaxy-servers" 'Servers page route'
Patch $appVue "import PromotionWrapper from '@/components/ui/PromotionWrapper.vue'" "import PromotionWrapper from '@/components/ui/PromotionWrapper.vue'`nimport GalaxyServerStatus from '@/components/ui/GalaxyServerStatus.vue'" 'import GalaxyServerStatus' 'load server status widget'
PatchRegex $appVue '(<div v-if="(?:false|news && news\.length > 0)" class="p-4 flex flex-col items-center">)' "<GalaxyServerStatus class=`"p-4 border-0 border-b-[1px] border-[--brand-gradient-border] border-solid`" />`n`t`t`t`t`t`$1" '<GalaxyServerStatus class=' 'server status where the ads were'

$caps = 'apps\app\capabilities\plugins.json'
Patch $caps '"friends:default",' "`"friends:default`",`n`t`t`"galaxy:default`"," '"galaxy:default"' 'permission for Galaxy downloads'
PatchRegex $caps '(\{\s*"url": "https://api\.mclo\.gs/\*"\s*\},)' "`$1`n`t`t`t`t{`n`t`t`t`t`t`"url`": `"https://api.curseforge.com/*`"`n`t`t`t`t},`n`t`t`t`t{`n`t`t`t`t`t`"url`": `"https://api.modpacks.ch/*`"`n`t`t`t`t}," 'api.curseforge.com' 'allow CurseForge + FTB searches'
Patch 'apps\app\src\api\mod.rs' 'pub mod friends;' "pub mod friends;`npub mod galaxy;" 'pub mod galaxy;' 'register Galaxy Rust module'
Patch 'apps\app\src\main.rs' '.plugin(api::friends::init())' ".plugin(api::friends::init())`n        .plugin(api::galaxy::init())" 'api::galaxy::init()' 'load Galaxy Rust module'
PatchRegex 'apps\app\build.rs' '(\.plugin\(\s*"friends",)' ".plugin(`n                `"galaxy`",`n                InlinedPlugin::new()`n                    .commands(&[`"galaxy_download_to_temp`"])`n                    .default_permission(`n                        DefaultPermissionRule::AllowAllCommands,`n                    ),`n            )`n            `$1" '"galaxy_download_to_temp"' 'declare Galaxy command'

# ---------------------------------------------------------------------------
Write-Host "`n[6/6] Helper scripts" -ForegroundColor Cyan
foreach ($s in 'setup-updater.ps1', 'release-galaxy.ps1', 'sync-modrinth.ps1') {
	Copy-Item (Join-Path $here $s) (Join-Path $Repo $s) -Force
	Write-Host "  copy  $s" -ForegroundColor Green
}
# Keep a copy of this installer in the repo so it can be re-run after syncing Modrinth.
$keep = Join-Path $Repo 'galaxy-patches'
if ((Resolve-Path $here).Path -ne (Join-Path (Resolve-Path $Repo).Path 'galaxy-patches')) {
	New-Item -ItemType Directory -Force -Path $keep | Out-Null
	Copy-Item (Join-Path $here 'install-galaxy.ps1') $keep -Force
	Copy-Item $filesRoot $keep -Recurse -Force
	foreach ($s in 'setup-updater.ps1', 'release-galaxy.ps1', 'sync-modrinth.ps1') {
		Copy-Item (Join-Path $here $s) $keep -Force
	}
	Write-Host "  copy  installer kept in galaxy-patches\" -ForegroundColor Green
}
$gi = Join-Path $Repo '.gitignore'
if ((Test-Path $gi) -and -not ((Get-Content $gi) -contains 'release/')) {
	Add-Content $gi "`nrelease/"
	Write-Host '  done  ignore the release\ folder in git' -ForegroundColor Green
}

Write-Host "`nFinished: $script:done changed, $script:skipped already done." -ForegroundColor Cyan
if ($script:manual.Count -gt 0) {
	Write-Host "These couldn't be done automatically (send them to Claude):" -ForegroundColor Yellow
	$script:manual | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}
Write-Host "`nNext: restart the app with"
Write-Host '  $env:CARGO_PROFILE_DEV_DEBUG="0"; $env:CARGO_BUILD_JOBS="1"; pnpm app:dev' -ForegroundColor White
