#Requires -Version 5.1
<#
.SYNOPSIS
  Makes DSH ready for SolidCraft's Assistant and shows the integration in
  DSH's Plugins page.

.DESCRIPTION
  Installs the dsh-solidcraft-bundle into the desktop profile as a visible
  switch (its own patch is empty, so the Desktop assistant is unchanged) and
  writes a launcher that applies the bundle's solidcraft.patch.yml to the acp
  profile while the switch is enabled.

  Plugins page:
    enabled  -> SolidCraft's agent gets the SolidCraft persona and account route
    disabled -> the launcher runs plain dsh --profile acp
    remove   -> the package is removed and the launcher falls back the same way

.PARAMETER DshCmd
  Path to dsh.cmd. Defaults to the Desktop installation, then dsh on PATH.

.PARAMETER DshHome
  DSH home. Defaults to $env:DSH_HOME, then %USERPROFILE%\.dsh.

.PARAMETER InstallDir
  Where the launcher, the bundle copy and backups live.
  Defaults to %LOCALAPPDATA%\DSH-SolidCraft.

.PARAMETER NoClipboard
  Do not copy the SolidCraft command to the clipboard.

.EXAMPLE
  .\install.cmd
#>
[CmdletBinding()]
param(
    [string]$DshCmd,
    [string]$DshHome,
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'DSH-SolidCraft'),
    [switch]$NoClipboard
)

$ErrorActionPreference = 'Stop'

function Resolve-DshCmd {
    param([string]$Explicit)
    if ($Explicit) {
        if (-not (Test-Path -LiteralPath $Explicit -PathType Leaf)) {
            throw "dsh.cmd not found: $Explicit"
        }
        return (Resolve-Path -LiteralPath $Explicit).Path
    }
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness\resources\runtime\cli\bin\dsh.cmd'),
        (Join-Path $env:ProgramFiles 'DeepSeek Harness\resources\runtime\cli\bin\dsh.cmd')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    $command = Get-Command dsh -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command -and $command.Source -and (Test-Path -LiteralPath $command.Source -PathType Leaf)) {
        return $command.Source
    }
    throw "dsh.cmd not found. Install DSH Desktop, put dsh on PATH, or pass -DshCmd <path to dsh.cmd>."
}

function Invoke-Dsh {
    param([string[]]$Arguments, [string]$What)
    $output = & $script:Dsh @Arguments 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        $text = ($output | Out-String).Trim()
        throw "$What failed (exit $code).`n$text"
    }
    return ($output | Out-String)
}

function Get-Manifest {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
    }
    return $null
}

function Remove-BundleSelection {
    param([string]$ManifestPath, [string]$Name)
    if (-not (Test-Path -LiteralPath $ManifestPath)) { return }
    $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    if (-not $manifest.dsh -or -not $manifest.dsh.profile) { return }
    $bundles = @($manifest.dsh.profile.bundles)
    if ($bundles -contains $Name) {
        $manifest.dsh.profile.bundles = @($bundles | Where-Object { $_ -ne $Name })
        $json = $manifest | ConvertTo-Json -Depth 100
        [IO.File]::WriteAllText($ManifestPath, $json, (New-Object System.Text.UTF8Encoding($false)))
    }
}

function Sync-BundleLink {
    param([string]$ProfileDir, [string]$Target)
    $link = Join-Path $ProfileDir 'node_modules\dsh-solidcraft-bundle'
    $item = Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
    if (-not $item) { return }
    if ($item.LinkType -ne 'Junction' -and $item.LinkType -ne 'SymbolicLink') { return }
    $current = @($item.Target) | Select-Object -First 1
    $currentFull = if ($current) { [IO.Path]::GetFullPath($current).TrimEnd('\') } else { '' }
    $wanted = [IO.Path]::GetFullPath($Target).TrimEnd('\')
    if ($currentFull -eq $wanted) { return }
    cmd /c rmdir "$link" | Out-Null
    New-Item -ItemType Junction -Path $link -Target $Target | Out-Null
    Write-Host "Relinked $link"
}

$dsh = Resolve-DshCmd -Explicit $DshCmd
if (-not $DshHome) {
    $DshHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $env:USERPROFILE '.dsh' }
}
$DshHome = [IO.Path]::GetFullPath($DshHome)
$InstallDir = [IO.Path]::GetFullPath($InstallDir)

$desktopDir = Join-Path $DshHome 'profiles\desktop'
$desktopManifest = Join-Path $desktopDir 'package.json'
$acpDir = Join-Path $DshHome 'profiles\acp'
$acpManifest = Join-Path $acpDir 'package.json'

if (-not (Test-Path -LiteralPath $desktopManifest -PathType Leaf)) {
    throw "The desktop profile was not found at $desktopDir. Start the DSH Desktop app once, then run this installer again."
}

$bundleSource = Join-Path $PSScriptRoot 'bundle'
foreach ($name in @('package.json', 'cordis.patch.yml', 'solidcraft.patch.yml')) {
    if (-not (Test-Path -LiteralPath (Join-Path $bundleSource $name) -PathType Leaf)) {
        throw "bundle\$name not found next to install.ps1."
    }
}

Write-Host "DSH:       $dsh"
Write-Host "DSH home:  $DshHome"
Write-Host "Install:   $InstallDir"
Write-Host ""

# 1. Copy the bundle to a stable location.
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$bundleTarget = Join-Path $InstallDir 'bundle'
if (Test-Path -LiteralPath $bundleTarget) {
    $resolved = (Resolve-Path -LiteralPath $bundleTarget).Path
    if (-not $resolved.StartsWith($InstallDir, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove a bundle outside the install directory: $resolved"
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
Copy-Item -LiteralPath $bundleSource -Destination $bundleTarget -Recurse -Force

# 2. Back up both profiles before changing them.
$backupDir = Join-Path $InstallDir 'backup'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
foreach ($pair in @(@{ Name = 'desktop'; Dir = $desktopDir }, @{ Name = 'acp'; Dir = $acpDir })) {
    foreach ($file in @('package.json', 'pnpm-lock.yaml')) {
        $source = Join-Path $pair.Dir $file
        if (Test-Path -LiteralPath $source) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $backupDir ($pair.Name + '-' + $file)) -Force
        }
    }
}

$oldHome = $env:DSH_HOME
$script:Dsh = $dsh
try {
    $env:DSH_HOME = $DshHome

    # 3. Install and enable the visible switch in the desktop profile.
    $fileSpec = 'file:' + ($bundleTarget -replace '\\', '/')
    Invoke-Dsh -Arguments @('plugin', '--profile', 'desktop', 'add', $fileSpec) -What 'Installing the SolidCraft switch' | Out-Null
    Sync-BundleLink -ProfileDir $desktopDir -Target $bundleTarget

    # pnpm keeps an existing local `file:` dependency as-is, so an upgrade can
    # leave the old copy (without the no-op entry) in node_modules. Force a
    # refresh when the installed copy does not match the bundle we just copied.
    $installedDir = Join-Path $desktopDir 'node_modules\dsh-solidcraft-bundle'
    $sourceVersion = (Get-Content -LiteralPath (Join-Path $bundleTarget 'package.json') -Raw | ConvertFrom-Json).version
    $installedVersion = $null
    if (Test-Path -LiteralPath (Join-Path $installedDir 'package.json')) {
        $installedVersion = (Get-Content -LiteralPath (Join-Path $installedDir 'package.json') -Raw | ConvertFrom-Json).version
    }
    $stale = (-not (Test-Path -LiteralPath (Join-Path $installedDir 'index.js'))) -or ($installedVersion -ne $sourceVersion)
    if ($stale) {
        Invoke-Dsh -Arguments @('plugin', '--profile', 'desktop', 'remove', 'dsh-solidcraft-bundle') -What 'Refreshing the installed SolidCraft switch' | Out-Null
        Invoke-Dsh -Arguments @('plugin', '--profile', 'desktop', 'add', $fileSpec) -What 'Reinstalling the SolidCraft switch' | Out-Null
        Sync-BundleLink -ProfileDir $desktopDir -Target $bundleTarget
        Write-Host "Refreshed the installed bundle to $sourceVersion."
    }

    # 4. The old kit installed a copy in acp. Remove it so the overlay is the
    # only configuration that reaches SolidCraft's agent.
    $acp = Get-Manifest -Path $acpManifest
    if ($acp) {
        $hasDependency = $acp.dependencies -and (@($acp.dependencies.PSObject.Properties.Name) -contains 'dsh-solidcraft-bundle')
        $hasSelection = $acp.dsh -and $acp.dsh.profile -and (@($acp.dsh.profile.bundles) -contains 'dsh-solidcraft-bundle')
        if ($hasDependency -or $hasSelection) {
            try {
                Invoke-Dsh -Arguments @('plugin', '--profile', 'acp', 'remove', 'dsh-solidcraft-bundle') -What 'Removing the old acp copy' | Out-Null
            } catch {
                Write-Warning ($_.Exception.Message)
            }
            Remove-BundleSelection -ManifestPath $acpManifest -Name 'dsh-solidcraft-bundle'
            Write-Host "Removed the old acp copy."
        }
    }
} finally {
    if ($null -eq $oldHome) { Remove-Item Env:\DSH_HOME -ErrorAction SilentlyContinue }
    else { $env:DSH_HOME = $oldHome }
}

# 5. The launcher: while the desktop switch is enabled, apply the overlay to acp.
$launcher = Join-Path $InstallDir 'dsh-acp.cmd'
$overlay = Join-Path $desktopDir 'node_modules\dsh-solidcraft-bundle\solidcraft.patch.yml'
$lines = @(
    '@echo off',
    'setlocal',
    ('set "DSHHOME=' + $DshHome + '"'),
    'set "MANIFEST=%DSHHOME%\profiles\desktop\package.json"',
    'set "OVERLAY=%DSHHOME%\profiles\desktop\node_modules\dsh-solidcraft-bundle\solidcraft.patch.yml"',
    'powershell.exe -NoProfile -NonInteractive -Command "$ErrorActionPreference=''Stop''; $m = Get-Content -LiteralPath ''%MANIFEST%'' -Raw | ConvertFrom-Json; if (@($m.dsh.profile.bundles) -notcontains ''dsh-solidcraft-bundle'') { exit 1 }; if (-not (Test-Path -LiteralPath ''%OVERLAY%'')) { exit 1 }" >nul 2>nul',
    'if errorlevel 1 (',
    ('    "' + $dsh + '" --profile acp %*'),
    ') else (',
    ('    "' + $dsh + '" --profile acp --patch "%OVERLAY%" %*'),
    ')',
    'exit /b %errorlevel%'
)
Set-Content -LiteralPath $launcher -Value $lines -Encoding Ascii

# 6. Verify the switch is selected and the overlay composes.
$desktop = Get-Manifest -Path $desktopManifest
$selected = $desktop -and $desktop.dsh -and $desktop.dsh.profile -and (@($desktop.dsh.profile.bundles) -contains 'dsh-solidcraft-bundle')

$oldHome = $env:DSH_HOME
try {
    $env:DSH_HOME = $DshHome
    $dump = Invoke-Dsh -Arguments @('--profile', 'acp', '--patch', $overlay, '--dump-config') -What 'Reading the composed acp profile'
    $help = & $launcher --help 2>&1 | Out-String
    $helped = $LASTEXITCODE -eq 0 -and $help -match 'Usage: dsh --profile acp'
} finally {
    if ($null -eq $oldHome) { Remove-Item Env:\DSH_HOME -ErrorAction SilentlyContinue }
    else { $env:DSH_HOME = $oldHome }
}

$hasAccountRoute = $dump -match 'provider: deepseek-account'
$hasPersona = ($dump -replace '\s+', ' ') -match 'running inside SolidCraft'

if (-not $selected) { Write-Warning 'The bundle is installed but not enabled in dsh.profile.bundles.' }
if (-not $hasAccountRoute) { Write-Warning 'The acp overlay did not compose the deepseek-account route.' }
if (-not $hasPersona) { Write-Warning 'The acp overlay did not compose the SolidCraft persona.' }
if (-not $helped) { Write-Warning 'The launcher did not print the acp help.' }

Write-Host ''
Write-Host "Installed 'SolidCraft assistant' in DSH's Plugins page." -ForegroundColor Green
if ($selected -and $hasAccountRoute -and $hasPersona -and $helped) {
    Write-Host 'Verified: switch enabled, overlay composes, launcher starts.' -ForegroundColor Green
}
Write-Host ''
Write-Host 'Manage it in DSH: Settings > Plugins > SolidCraft assistant'
Write-Host '  Enable / disable  turns the SolidCraft ACP integration on / off'
Write-Host '  Remove            uninstalls it; the launcher then runs plain dsh --profile acp'
Write-Host ''
Write-Host 'SolidCraft (one time per SolidCraft installation):'
Write-Host '  Preferences > AI > Agents > Add agent... > Custom command'
Write-Host '  Name:    DeepSeek Harness'
Write-Host ("  Command: " + $launcher)
Write-Host ''
Write-Host 'Restart SolidCraft if it was already running, then Connect.'

if (-not $NoClipboard) {
    try {
        Set-Clipboard -Value $launcher
        Write-Host 'The command is on the clipboard.'
    } catch {
        Write-Host '(Could not copy to the clipboard.)'
    }
}
