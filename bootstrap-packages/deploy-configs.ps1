<#
.SYNOPSIS
    Deploys the app configs vendored in settings\ to where each app reads them.

.DESCRIPTION
    The profile calls a set of external tools, and several of them are
    customized rather than stock. Those customizations live in settings\ so a
    new machine gets the same behaviour, not just the same programs:

      settings\atuin\config.toml      -> ~\.config\atuin\config.toml
      settings\git\gitconfig          -> merged into the global git config
      settings\git\ignore             -> ~\.config\git\ignore
      settings\opencode\opencode.jsonc-> ~\.config\opencode\opencode.jsonc
      settings\notepad++\*.xml        -> %APPDATA%\Notepad++\
      settings\everything\Everything.ini -> %APPDATA%\Everything\
      settings\autohotkey\*.ahk       -> ~\Documents\AutoHotkey\ (+ autostart)

    Every step is idempotent: identical files are left alone, and anything
    about to be replaced is backed up alongside itself first. Called by
    bootstrap.ps1; also runnable on its own.

.EXAMPLE
    pwsh -File .\bootstrap-packages\deploy-configs.ps1
#>
[CmdletBinding()]
param(
    [switch]$Force
)

$RepoRoot    = Split-Path -Parent $PSScriptRoot
$SettingsDir = Join-Path $RepoRoot "settings"

function Write-Ok   { param([string]$m) Write-Host "OK   $m" -ForegroundColor Green }
function Write-Info { param([string]$m) Write-Host "..   $m" -ForegroundColor Yellow }
function Write-Bad  { param([string]$m) Write-Host "!!   $m" -ForegroundColor Red }

function Copy-Config {
    <#
        Copies one vendored config into place, backing up whatever was there.
        -Tokenize swaps __USERPROFILE__ for this machine's profile path, which
        is how the Notepad++ config stays portable across usernames.
    #>
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Target,
        [switch]$Tokenize
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        Write-Bad "Missing from repo: $Source"
        return
    }

    $label     = Split-Path $Target -Leaf
    $targetDir = Split-Path $Target -Parent

    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

    if ($Tokenize) {

        $content = Get-Content -LiteralPath $Source -Raw
        $content = $content.Replace("__USERPROFILE__", $env:USERPROFILE)
    }
    else {
        $content = Get-Content -LiteralPath $Source -Raw
    }

    $existing = if (Test-Path -LiteralPath $Target) {
        Get-Content -LiteralPath $Target -Raw
    }
    else {
        $null
    }

    if ($existing -eq $content) {
        Write-Ok "$label already up to date"
        return
    }

    if ($existing -ne $null) {

        $backup = "$Target.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

        Copy-Item -LiteralPath $Target -Destination $backup -Force
        Write-Info "Backed up existing $label -> $(Split-Path $backup -Leaf)"
    }

    [System.IO.File]::WriteAllText(
        $Target,
        $content,
        (New-Object System.Text.UTF8Encoding $false)
    )

    Write-Ok "Deployed $label -> $Target"
}

# =========================================================
# atuin
# =========================================================

Write-Host "`n== atuin ==" -ForegroundColor Cyan

Copy-Config `
    -Source (Join-Path $SettingsDir "atuin\config.toml") `
    -Target (Join-Path $HOME ".config\atuin\config.toml")

# =========================================================
# git
# =========================================================

Write-Host "`n== git ==" -ForegroundColor Cyan

Copy-Config `
    -Source (Join-Path $SettingsDir "git\ignore") `
    -Target (Join-Path $HOME ".config\git\ignore")

$gitTemplate = Join-Path $SettingsDir "git\gitconfig"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Bad "git not found - skipped global git config"
}
elseif (-not (Test-Path -LiteralPath $gitTemplate)) {
    Write-Bad "Missing from repo: $gitTemplate"
}
else {

    # Merged setting by setting rather than copied over the top, so an existing
    # ~\.gitconfig (and especially an existing identity) survives.
    function Set-GitGlobal {
        param(
            [string]$Key,
            [string]$Value,
            [switch]$OnlyIfUnset
        )

        $current = git config --global --get $Key 2>$null

        if ($OnlyIfUnset -and $current) {
            Write-Ok "git $Key already set ($current) - left alone"
            return
        }

        if ($current -eq $Value) {
            Write-Ok "git $Key already set"
            return
        }

        git config --global $Key $Value
        Write-Ok "git $Key = $Value"
    }

    $template = Get-Content -LiteralPath $gitTemplate -Raw

    # No identity is vendored - this repo is public. Take it from the template
    # if one is there, otherwise ask, but only when this machine has none:
    # without user.name and user.email, commits fail outright with
    # "unable to auto-detect email address" on a fresh install.
    function Set-GitIdentity {
        param(
            [string]$Key,
            [string]$TemplateKey,
            [string]$Example
        )

        $current = git config --global --get $Key 2>$null

        if ($current) {
            Write-Ok "git $Key already set ($current) - left alone"
            return
        }

        if ($template -match ('(?m)^\s*' + $TemplateKey + '\s*=\s*(.+)$')) {
            Set-GitGlobal -Key $Key -Value $Matches[1].Trim() -OnlyIfUnset
            return
        }

        $answer = Read-Host "`nNo git $Key is set on this machine. Enter one now (blank to skip)"

        if ($answer -and $answer.Trim()) {
            git config --global $Key $answer.Trim()
            Write-Ok "git $Key = $($answer.Trim())"
        }
        else {
            Write-Info "Skipped - set it later with: git config --global $Key $Example"
        }
    }

    Set-GitIdentity -Key "user.name"  -TemplateKey "name"  -Example '"Your Name"'
    Set-GitIdentity -Key "user.email" -TemplateKey "email" -Example "you@example.com"

    # Behavioural settings are applied unconditionally.
    Set-GitGlobal -Key 'url.git@github.com:.insteadOf' -Value "https://github.com/"
    Set-GitGlobal -Key "core.excludesfile" -Value (Join-Path $HOME ".config\git\ignore")

    if (Get-Command git-lfs -ErrorAction SilentlyContinue) {
        git lfs install --skip-repo 2>&1 | Out-Null
        Write-Ok "git-lfs filters registered"
    }
    else {
        Write-Info "git-lfs not installed - skipped its filter config"
    }
}

# =========================================================
# opencode
# =========================================================

Write-Host "`n== opencode ==" -ForegroundColor Cyan

$opencodeTarget = Join-Path $HOME ".config\opencode\opencode.jsonc"
$opencodeAlt    = Join-Path $HOME ".config\opencode\opencode.json"

if (Test-Path -LiteralPath $opencodeAlt) {
    # opencode reads either name; don't create a second, conflicting file.
    Write-Info "opencode.json already exists - left alone"
}
else {
    Copy-Config `
        -Source (Join-Path $SettingsDir "opencode\opencode.jsonc") `
        -Target $opencodeTarget
}

# =========================================================
# Notepad++
# =========================================================

# =========================================================
# fzf / PSFzf
# =========================================================

Write-Host "`n== fzf ==" -ForegroundColor Cyan

# Same destination the upstream Install-FzfConfig.ps1 uses, so the config is
# where its own docs say it is. The profile dot-sources PSFzf.config.ps1 from
# here at the end of its load, which is what that installer's $PROFILE block
# would otherwise do - doing it in the profile keeps this repo the single
# source of truth instead of letting an installer edit a tracked file.
$fzfSource = Join-Path $SettingsDir "fzf"
$fzfTarget = Join-Path $HOME ".config\fzf"

if (-not (Test-Path -LiteralPath $fzfSource)) {
    Write-Bad "Missing from repo: $fzfSource"
}
else {

    foreach ($name in "fzf.conf", "PSFzf.config.ps1", "fzf-preview.cmd", "fzf-action.cmd") {

        Copy-Config `
            -Source (Join-Path $fzfSource $name) `
            -Target (Join-Path $fzfTarget $name)
    }
}

# =========================================================
# Notepad++
# =========================================================

Write-Host "`n== Notepad++ ==" -ForegroundColor Cyan

$nppRunning = Get-Process notepad++ -ErrorAction SilentlyContinue

if ($nppRunning -and -not $Force) {
    Write-Info "Notepad++ is running (it overwrites its config on exit) - skipped. Close it and re-run, or pass -Force."
}
else {

    $nppSource = Join-Path $SettingsDir "notepad++"
    $nppTarget = Join-Path $env:APPDATA "Notepad++"

    if (-not (Test-Path -LiteralPath $nppSource)) {
        Write-Bad "Missing from repo: $nppSource"
    }
    else {

        Get-ChildItem -LiteralPath $nppSource -Filter *.xml -File |
            ForEach-Object {
                Copy-Config `
                    -Source $_.FullName `
                    -Target (Join-Path $nppTarget $_.Name) `
                    -Tokenize
            }
    }
}

# =========================================================
# Everything
# =========================================================

Write-Host "`n== Everything ==" -ForegroundColor Cyan

$everythingRunning = Get-Process Everything -ErrorAction SilentlyContinue

if ($everythingRunning -and -not $Force) {
    Write-Info "Everything is running (it rewrites its ini on exit) - skipped. Close it and re-run, or pass -Force."
}
else {
    Copy-Config `
        -Source (Join-Path $SettingsDir "everything\Everything.ini") `
        -Target (Join-Path $env:APPDATA "Everything\Everything.ini")
}

# =========================================================
# AutoHotkey
# =========================================================

Write-Host "`n== AutoHotkey ==" -ForegroundColor Cyan

$ahkSource = Join-Path $SettingsDir "autohotkey"
$ahkTarget = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "AutoHotkey"

if (-not (Test-Path -LiteralPath $ahkSource)) {
    Write-Bad "Missing from repo: $ahkSource"
}
else {

    Get-ChildItem -LiteralPath $ahkSource -Filter *.ahk -File |
        ForEach-Object {
            Copy-Config `
                -Source $_.FullName `
                -Target (Join-Path $ahkTarget $_.Name)
        }

    $ahkExe = @(
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey32.exe",
        "$env:ProgramFiles\AutoHotkey\AutoHotkey.exe"
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

    if (-not $ahkExe) {
        Write-Bad "AutoHotkey not installed - scripts deployed but not started"
    }
    else {

        # Only keybinds.ahk autostarts; bandlab_ahk.ahk is launched on demand
        # because it swallows every alphanumeric key while it's running.
        $keybinds   = Join-Path $ahkTarget "keybinds.ahk"
        $startupDir = [Environment]::GetFolderPath("Startup")
        $shortcut   = Join-Path $startupDir "keybinds.ahk.lnk"

        if (Test-Path -LiteralPath $keybinds) {

            if (-not (Test-Path -LiteralPath $shortcut)) {

                $shell = New-Object -ComObject WScript.Shell
                $sc    = $shell.CreateShortcut($shortcut)
                $sc.TargetPath       = $ahkExe
                $sc.Arguments        = "`"$keybinds`""
                $sc.WorkingDirectory = $ahkTarget
                $sc.Save()

                Write-Ok "Autostart shortcut created: $shortcut"
            }
            else {
                Write-Ok "Autostart shortcut already exists"
            }

            # Validate the syntax if the compiler is around - a broken .ahk
            # otherwise fails silently until the next login.
            $ahk2Exe = Get-ChildItem `
                -Path (Split-Path $ahkExe -Parent) `
                -Recurse -Filter "Ahk2Exe.exe" `
                -ErrorAction SilentlyContinue |
                Select-Object -First 1

            if ($ahk2Exe) {

                $checkOut = Join-Path $env:TEMP "keybinds.syntaxcheck.exe"

                & $ahk2Exe.FullName /in $keybinds /out $checkOut /silent | Out-Null

                if ($LASTEXITCODE -eq 0) {
                    Write-Ok "keybinds.ahk syntax OK"
                }
                else {
                    Write-Bad "keybinds.ahk syntax check FAILED (Ahk2Exe exit $LASTEXITCODE)"
                }

                Remove-Item -LiteralPath $checkOut -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# Free up the Win+... combos the AHK script binds.
$disabledKey   = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$disabledValue = "BCDEFMNQSVXYZ"

$currentDisabled = (Get-ItemProperty -Path $disabledKey -Name "DisabledHotkeys" -ErrorAction SilentlyContinue).DisabledHotkeys

if ($currentDisabled -eq $disabledValue) {
    Write-Ok "DisabledHotkeys already set to '$disabledValue'"
}
else {
    Set-ItemProperty `
        -Path $disabledKey `
        -Name "DisabledHotkeys" `
        -Value $disabledValue `
        -Type String `
        -ErrorAction SilentlyContinue

    Write-Ok "DisabledHotkeys set to '$disabledValue' (takes effect after sign-out)"
}

# =========================================================
# Everything CLI on PATH (the `es` command)
# =========================================================

$everythingDir = "$env:ProgramFiles\Everything"

if (Test-Path -LiteralPath (Join-Path $everythingDir "es.exe")) {

    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")

    if (($userPath -split ";") -notcontains $everythingDir) {

        $newPath = if ($userPath) { "$userPath;$everythingDir" } else { $everythingDir }

        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        Write-Ok "Added '$everythingDir' to user PATH"
    }
    else {
        Write-Ok "'$everythingDir' already on user PATH"
    }
}

Write-Host "`n== Configs deployed ==" -ForegroundColor Cyan
