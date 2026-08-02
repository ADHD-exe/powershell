# =========================================================
# registry-tweaks.ps1
# Standalone registry tweaks (Winaero settings)
#
# - All changes are per-user (HKCU) — no admin rights required.
# - Safe to re-run: every value is read first and only written
#   when it actually differs, so nothing is needlessly touched.
#
# Usage:  .\bootstrap-packages\registry-tweaks.ps1
# =========================================================

function Read-Ini {
    param([string]$Path)

    $ini     = @{}
    $section = ""

    foreach ($line in Get-Content -LiteralPath $Path) {

        $line = $line.Trim()

        if ($line -match '^\[(.+)\]$') {
            $section       = $Matches[1]
            $ini[$section] = @{}
            continue
        }

        if ($line -match '^([^=;#]+?)\s*=\s*(.*)$') {
            $ini[$section][$Matches[1].Trim()] = $Matches[2].Trim()
        }
    }

    return $ini
}

function Get-RegValue {
    param(
        [string]$Path,
        [string]$Name
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $key = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue

    if (-not $key) {
        return $null
    }

    return $key.GetValue($Name)
}

function Set-RegValue {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = "DWord"
    )

    $current = Get-RegValue -Path $Path -Name $Name

    if ($null -ne $current -and [string]$current -eq [string]$Value) {
        return $false
    }

    New-Item -Path $Path -Force | Out-Null

    if ([string]::IsNullOrEmpty($Name)) {
        Set-Item -Path $Path -Value $Value
        return $true
    }

    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
    return $true
}

$iniPath = Join-Path $PSScriptRoot "Winaero-Tweaker-Settings.ini"

if (-not (Test-Path -LiteralPath $iniPath)) {
    Write-Warning "⚠️ Winaero-Tweaker-Settings.ini not found next to registry-tweaks.ps1; skipping tweaks."
    return
}

Write-Host "`n== Registry tweaks (Winaero settings) ==" -ForegroundColor Cyan

$ini = Read-Ini -Path $iniPath

# Ads / suggestions / unwanted apps
if ($ini["pageAdsUnwantedApps"]) {

    $cdm = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"

    $adsMap = @{
        "UnwantedAppsDisabled"     = "SilentInstalledAppsEnabled"
        "FileExplorerAdsDisabled"  = "SubscribedContent-338389Enabled"
        "LockScreenAdsDisabled"    = "RotatingLockScreenEnabled"
        "StartSuggestionsDisabled" = "SystemPaneSuggestionsEnabled"
        "TipsAboutWindowsDisabled" = "SubscribedContent-338388Enabled"
        "WelcomePageDisabled"      = "SubscribedContent-310093Enabled"
        "SettingsAdsDisabled"      = "SoftLandingEnabled"
    }

    $count = 0

    foreach ($key in $adsMap.Keys) {
        if ($ini["pageAdsUnwantedApps"][$key] -eq "1") {
            if (Set-RegValue -Path $cdm -Name $adsMap[$key] -Value 0 -Type DWord) {
                $count++
            }
        }
    }

    if ($ini["pageAdsUnwantedApps"]["TimelineSuggestionsDisabled"] -eq "1") {
        if (Set-RegValue `
            -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
            -Name "ShowSyncProviderNotifications" `
            -Value 0 -Type DWord) {
            $count++
        }
    }

    if ($count -gt 0) {
        Write-Host "✔ Ads, suggestions and unwanted apps disabled ($count)" -ForegroundColor Green
    }
    else {
        Write-Host "✔ Ads, suggestions and unwanted apps already configured" -ForegroundColor Green
    }
}

# SmartScreen for Microsoft Store apps
if ($ini["pageDisableSmartScreen"]["DisableSmartScreenInStore"] -eq "1") {
    if (Set-RegValue `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AppHost" `
        -Name "EnableWebContentEvaluation" `
        -Value 0 -Type DWord) {
        Write-Host "✔ SmartScreen for Microsoft Store apps disabled" -ForegroundColor Green
    }
    else {
        Write-Host "✔ SmartScreen for Microsoft Store apps already disabled" -ForegroundColor Green
    }
}

# Explorer "New" menu items
if ($ini["pageExplorerNewMenu"]) {

    $count = 0

    foreach ($ext in ".bat", ".cmd", ".reg", ".vbs", ".ps1") {
        if ($ini["pageExplorerNewMenu"][$ext] -eq "1") {
            if (Set-RegValue -Path "HKCU:\Software\Classes\$ext\ShellNew" -Name "NullFile" -Value "" -Type String) {
                $count++
            }
        }
    }

    if ($count -gt 0) {
        Write-Host "✔ New-menu entries added for $count file types" -ForegroundColor Green
    }
    else {
        Write-Host "✔ New-menu entries already configured" -ForegroundColor Green
    }
}

# "Run as administrator" context menu
if ($ini["pageContextMenuRunAsAdministrator"]) {

    $runAs = @(
        @{
            Ext = "msi"
            Key = "HKCU:\Software\Classes\msi_auto_file\Shell\runas"
            Cmd = 'msiexec.exe /i "%1"'
        },
        @{
            Ext = "vbs"
            Key = "HKCU:\Software\Classes\SystemFileAssociations\.vbs\Shell\runas"
            Cmd = 'wscript.exe "%1"'
        },
        @{
            Ext = "ps1"
            Key = "HKCU:\Software\Classes\SystemFileAssociations\.ps1\Shell\runas"
            Cmd = '"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -NoExit -Command "if((Get-ExecutionPolicy) -ne ''AllSigned'') { Set-ExecutionPolicy -Scope Process Bypass }; & ''%1''"'
        }
    )

    foreach ($entry in $runAs) {
        if ($ini["pageContextMenuRunAsAdministrator"][$entry.Ext] -eq "1") {

            $cmdKey     = "$($entry.Key)\command"
            $cmdChanged = (Get-RegValue -Path $cmdKey -Name "") -ne $entry.Cmd

            if ($cmdChanged) {
                New-Item -Path $cmdKey -Force | Out-Null
                Set-Item -Path $cmdKey -Value $entry.Cmd
            }

            if (Set-RegValue -Path $entry.Key -Name "HasLUAShield" -Value "" -Type String) {
                $cmdChanged = $true
            }

            if ($cmdChanged) {
                Write-Host "✔ 'Run as administrator' added for .$($entry.Ext)" -ForegroundColor Green
            }
            else {
                Write-Host "✔ 'Run as administrator' already configured for .$($entry.Ext)" -ForegroundColor Green
            }
        }
    }
}

# "Run with PowerShell 7" for .ps1 files
if ($ini["pageContextMenuRunModifyPS1"]["AddPowerShell7"] -eq "1") {

    $ps1Shell = "HKCU:\Software\Classes\SystemFileAssociations\.ps1\Shell\RunPowershell7"
    $ps1Cmd   = 'pwsh.exe -NoExit -Command "if((Get-ExecutionPolicy) -ne ''AllSigned'') { Set-ExecutionPolicy -Scope Process Bypass }; & ''%1''"'

    $changed = $false

    if ((Get-RegValue -Path $ps1Shell -Name "") -ne "Run with PowerShell 7") {
        New-Item -Path $ps1Shell -Force | Out-Null
        Set-Item -Path $ps1Shell -Value "Run with PowerShell 7"
        $changed = $true
    }

    $cmdKey = "$ps1Shell\Command"
    if ((Get-RegValue -Path $cmdKey -Name "") -ne $ps1Cmd) {
        New-Item -Path $cmdKey -Force | Out-Null
        Set-Item -Path $cmdKey -Value $ps1Cmd
        $changed = $true
    }

    if ($ini["pageContextMenuRunModifyPS1"]["ShowExtended"] -eq "1") {
        if (Set-RegValue -Path $ps1Shell -Name "Extended" -Value "" -Type String) {
            $changed = $true
        }
    }

    if ($changed) {
        Write-Host "✔ 'Run with PowerShell 7' added for .ps1 files" -ForegroundColor Green
    }
    else {
        Write-Host "✔ 'Run with PowerShell 7' already configured for .ps1 files" -ForegroundColor Green
    }
}

# Icon cache size
if ($ini["pageIconCacheSize"]["Max Cached Icons"]) {
    if (Set-RegValue `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" `
        -Name "IconCacheSize" `
        -Value ([int]$ini["pageIconCacheSize"]["Max Cached Icons"]) `
        -Type DWord) {
        Write-Host "✔ Icon cache size set to $($ini['pageIconCacheSize']['Max Cached Icons']) MB" -ForegroundColor Green
    }
    else {
        Write-Host "✔ Icon cache size already set to $($ini['pageIconCacheSize']['Max Cached Icons']) MB" -ForegroundColor Green
    }
}

Write-Host "ℹ️  Context-menu and icon-cache changes need Explorer to restart (run 'rsex')." -ForegroundColor Yellow
Write-Host "`n✔ Registry tweaks complete" -ForegroundColor Green
