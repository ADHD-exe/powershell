<#
.SYNOPSIS
    New-machine installer for the Rabbit PowerShell profile.

.DESCRIPTION
    The entry point for a fresh Windows box. It does the things that have to
    happen before bootstrap.ps1 can run at all:

      1. Installs the prerequisites bootstrap.ps1 itself depends on
         (winget check, git, PowerShell 7, Node.js).
      2. Puts this repo in the PowerShell 7 profile folder - OneDrive-aware,
         backing up anything already there.
      3. Installs the global npm packages the profile's aliases point at.
      4. Hands off to bootstrap-packages\bootstrap.ps1 under pwsh, which
         installs every app, CLI tool, PowerShell module and font, then
         deploys the app configs vendored in settings\.

    Runs from Windows PowerShell 5.1 or PowerShell 7, and is safe to re-run:
    every step checks before it acts.

.EXAMPLE
    # Fresh machine, nothing cloned yet:
    irm https://raw.githubusercontent.com/ADHD-exe/powershell/main/install.ps1 | iex

.EXAMPLE
    # From an existing clone:
    powershell -ExecutionPolicy Bypass -File .\install.ps1

.EXAMPLE
    # Lay the files down, install nothing:
    .\install.ps1 -SkipBootstrap
#>
[CmdletBinding()]
param(
    [string]$RepoUrl     = "https://github.com/ADHD-exe/powershell.git",
    [string]$Branch      = "main",
    [string]$Destination,
    [switch]$SkipBootstrap,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# =========================================================
# Helpers
# =========================================================

function Write-Step { param([string]$m) Write-Host "`n== $m ==" -ForegroundColor Cyan }
function Write-Ok   { param([string]$m) Write-Host "OK   $m" -ForegroundColor Green }
function Write-Info { param([string]$m) Write-Host "..   $m" -ForegroundColor Yellow }
function Write-Bad  { param([string]$m) Write-Host "!!   $m" -ForegroundColor Red }

function Test-CommandExists {
    param([string]$Command)

    if ([string]::IsNullOrWhiteSpace($Command)) {
        return $false
    }

    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

function Update-SessionPath {
    # winget drops shims in folders that aren't on this process's PATH yet.
    $machine = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    $user    = [Environment]::GetEnvironmentVariable("PATH", "User")

    $env:PATH = ($machine, $user | Where-Object { $_ }) -join ";"
}

function Install-Prerequisite {
    param(
        [string]$Name,
        [string]$Command,
        [string]$WingetId,
        [string[]]$TestPaths = @()
    )

    if (Test-CommandExists $Command) {
        Write-Ok "$Name already installed"
        return $true
    }

    $found = $TestPaths | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    if ($found) {
        Write-Ok "$Name already installed ($found)"
        return $true
    }

    if (-not (Test-CommandExists "winget")) {
        Write-Bad "$Name is missing and winget isn't available to install it."
        return $false
    }

    Write-Info "Installing $Name ..."

    winget install `
        --id $WingetId `
        --source winget `
        --exact `
        --silent `
        --disable-interactivity `
        --accept-package-agreements `
        --accept-source-agreements | Out-Null

    Update-SessionPath

    if (Test-CommandExists $Command) {
        Write-Ok "$Name installed"
        return $true
    }

    $found = $TestPaths | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    if ($found) {
        Write-Ok "$Name installed ($found)"
        return $true
    }

    Write-Bad "Couldn't install $Name (winget id: $WingetId)"
    return $false
}

function Get-ProfileDirectory {
    # PowerShell 7 decides this itself, and it moves when Documents is
    # redirected to OneDrive - so ask pwsh rather than guessing.
    if (Test-CommandExists "pwsh") {

        try {
            $profilePath = & pwsh -NoProfile -NoLogo -Command '$PROFILE.CurrentUserAllHosts' 2>$null

            if ($profilePath) {
                return (Split-Path -Parent ([string]$profilePath).Trim())
            }
        }
        catch {
            # fall through to the manual guess below
        }
    }

    $docs = [Environment]::GetFolderPath("MyDocuments")

    if (-not $docs) {
        $docs = Join-Path $HOME "Documents"
    }

    return (Join-Path $docs "PowerShell")
}

Write-Host "`n=================================================" -ForegroundColor Magenta
Write-Host "  Rabbit PowerShell Profile - machine installer"   -ForegroundColor Magenta
Write-Host "=================================================" -ForegroundColor Magenta

# =========================================================
# 1. Prerequisites
# =========================================================

Write-Step "Prerequisites"

if (-not (Test-CommandExists "winget")) {
    Write-Bad "winget (App Installer) not found."
    Write-Host "     Install 'App Installer' from the Microsoft Store, then re-run this script." -ForegroundColor Yellow
    Write-Host "     ms-windows-store://pdp/?productid=9NBLGGH4NNS1" -ForegroundColor Yellow
    throw "winget is required to install the prerequisites."
}

Write-Ok "winget available"

$gitOk = Install-Prerequisite `
    -Name "git" `
    -Command "git" `
    -WingetId "Git.Git" `
    -TestPaths @("$env:ProgramFiles\Git\cmd\git.exe")

$pwshOk = Install-Prerequisite `
    -Name "PowerShell 7" `
    -Command "pwsh" `
    -WingetId "Microsoft.PowerShell" `
    -TestPaths @("$env:ProgramFiles\PowerShell\7\pwsh.exe")

# Node is here because the profile's `oc` / `ai` aliases resolve to openclaw
# and opencode, which ship as global npm packages rather than winget ones.
$nodeOk = Install-Prerequisite `
    -Name "Node.js LTS" `
    -Command "node" `
    -WingetId "OpenJS.NodeJS.LTS" `
    -TestPaths @("$env:ProgramFiles\nodejs\node.exe")

if (-not $pwshOk) {
    throw "PowerShell 7 is required - the profile uses PS7-only syntax."
}

if (-not $gitOk) {
    throw "git is required to fetch the profile repo."
}

# =========================================================
# 2. Place the repo in the profile folder
# =========================================================

Write-Step "Profile location"

if (-not $Destination) {
    $Destination = Get-ProfileDirectory
}

Write-Host "     Target: $Destination" -ForegroundColor Gray

# Are we already running from inside a clone of this repo?
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { "" }

$runningFromClone = $scriptRoot -and
    (Test-Path -LiteralPath (Join-Path $scriptRoot "Microsoft.PowerShell_profile.ps1")) -and
    (Test-Path -LiteralPath (Join-Path $scriptRoot "bootstrap-packages\bootstrap.ps1"))

$alreadyInPlace = $runningFromClone -and
    ((Resolve-Path -LiteralPath $scriptRoot).Path.TrimEnd('\') -ieq $Destination.TrimEnd('\'))

if ($alreadyInPlace) {

    Write-Ok "Already running from the profile folder - nothing to copy"
    $RepoRoot = $Destination
}
else {

    # Anything already at the destination gets copied aside, not overwritten.
    $existingProfile = Join-Path $Destination "Microsoft.PowerShell_profile.ps1"

    if ((Test-Path -LiteralPath $existingProfile) -and -not $Force) {

        $backup = "$Destination.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

        Write-Info "Existing profile found - backing it up to $backup"
        Copy-Item -LiteralPath $Destination -Destination $backup -Recurse -Force
    }

    $source = $scriptRoot

    if (-not $runningFromClone) {

        $temp = Join-Path $env:TEMP "rabbit-powershell-$(Get-Random)"

        Write-Info "Cloning $RepoUrl ($Branch) ..."

        git clone --depth 1 --branch $Branch $RepoUrl $temp | Out-Null

        if ($LASTEXITCODE -ne 0) {
            throw "git clone failed: $RepoUrl"
        }

        $source = $temp
    }
    else {
        Write-Info "Copying from the local clone at $source"
    }

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    Get-ChildItem -LiteralPath $source -Force |
        ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force
        }

    Write-Ok "Profile files placed in $Destination"

    if (-not $runningFromClone) {
        Remove-Item -LiteralPath $source -Recurse -Force -ErrorAction SilentlyContinue
    }

    $RepoRoot = $Destination
}

# The profile folder's own execution policy, so the profile is allowed to load.
$configPath = Join-Path $RepoRoot "powershell.config.json"

if (-not (Test-Path -LiteralPath $configPath)) {

    '{"Microsoft.PowerShell:ExecutionPolicy":"RemoteSigned"}' |
        Set-Content -LiteralPath $configPath -Encoding UTF8

    Write-Ok "Wrote powershell.config.json (RemoteSigned)"
}

$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser

if ($currentPolicy -eq "Restricted" -or $currentPolicy -eq "Undefined") {

    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
    Write-Ok "Execution policy set to RemoteSigned (CurrentUser)"
}
else {
    Write-Ok "Execution policy already permissive ($currentPolicy)"
}

# =========================================================
# 3. Global npm packages the profile's aliases point at
# =========================================================

Write-Step "npm packages"

if ($nodeOk -and (Test-CommandExists "npm")) {

    $npmPackages = @(
        @{ Name = "openclaw";                  Command = "openclaw" },
        @{ Name = "@anthropic-ai/claude-code"; Command = "claude"   }
    )

    foreach ($pkg in $npmPackages) {

        if (Test-CommandExists $pkg.Command) {
            Write-Ok "$($pkg.Name) already installed"
            continue
        }

        Write-Info "Installing $($pkg.Name) ..."

        npm install -g $pkg.Name 2>&1 | Out-Null

        Update-SessionPath

        if (Test-CommandExists $pkg.Command) {
            Write-Ok "$($pkg.Name) installed"
        }
        else {
            Write-Bad "Couldn't install $($pkg.Name) - run 'npm install -g $($pkg.Name)' by hand"
        }
    }
}
else {
    Write-Bad "Node/npm unavailable - skipped openclaw and claude-code"
}

# =========================================================
# 4. Hand off to the package bootstrap
# =========================================================

if ($SkipBootstrap) {

    Write-Step "Done (bootstrap skipped)"
    Write-Host "     Run it yourself with:" -ForegroundColor Gray
    Write-Host "     pwsh -ExecutionPolicy Bypass -File `"$RepoRoot\bootstrap-packages\bootstrap.ps1`"" -ForegroundColor Gray
    return
}

Write-Step "Handing off to bootstrap.ps1"

$bootstrap = Join-Path $RepoRoot "bootstrap-packages\bootstrap.ps1"

if (-not (Test-Path -LiteralPath $bootstrap)) {
    throw "bootstrap.ps1 not found at $bootstrap"
}

$pwshExe = (Get-Command pwsh -ErrorAction SilentlyContinue).Source

if (-not $pwshExe) {
    $pwshExe = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
}

& $pwshExe -NoProfile -ExecutionPolicy Bypass -File $bootstrap

Write-Step "Finished"
Write-Host "     Open a new pwsh window (or run 'reload') to load the profile." -ForegroundColor Gray
