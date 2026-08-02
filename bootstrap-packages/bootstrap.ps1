# =========================================================
# bootstrap.ps1
# One-time environment setup
# =========================================================

Write-Host "`n== Rabbit PowerShell Bootstrap ==" -ForegroundColor Cyan

Set-PSRepository PSGallery `
    -InstallationPolicy Trusted `
    -ErrorAction SilentlyContinue

function Test-CommandExists {
    param([string]$Command)

    if ([string]::IsNullOrWhiteSpace($Command)) {
        return $false
    }

    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

function Refresh-Path {
    $env:PATH =
        [System.Environment]::GetEnvironmentVariable("PATH", "Machine") +
        ";" +
        [System.Environment]::GetEnvironmentVariable("PATH", "User")
}

function Install-WithWinget {
    param(
        [string]$Id,
        [ValidateSet("winget","msstore")]
        [string]$Source = "winget"
    )

    if (-not (Test-CommandExists "winget")) {
        return $false
    }

    try {
        if ($Source -eq "msstore") {
            winget install `
                --id $Id `
                --source msstore `
                --accept-package-agreements `
                --accept-source-agreements `
                | Out-Null
        }
        else {
            winget install `
                --id $Id `
                --source winget `
                --exact `
                --silent `
                --disable-interactivity `
                --accept-package-agreements `
                --accept-source-agreements `
                | Out-Null
        }

        return ($LASTEXITCODE -eq 0)
    }
    catch {
        return $false
    }
}

function Install-WithChoco {
    param([string]$Id)

    if (-not (Test-CommandExists "choco")) {
        return $false
    }

    try {
        choco install $Id -y --no-progress | Out-Null
        return ($LASTEXITCODE -eq 0)
    }
    catch {
        return $false
    }
}

function Install-PackageFallback {
    param(
        [string]$Name,
        [string]$Command,
        [string]$WingetId,
        [string]$ChocoId,
        [string[]]$TestPaths = @(),
        [string]$Source = "winget",
        [string]$DetectAppx = ""
    )

    if (Test-CommandExists $Command) {
        return
    }

    $foundPath = $TestPaths | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    if ($foundPath) {
        return
    }

    if ($DetectAppx -and (Get-AppxPackage -Name $DetectAppx -ErrorAction SilentlyContinue)) {
        return
    }

    # Skip if winget already has it registered as installed (catches packages
    # whose command/path/appx detection misses) so we don't re-run installs.
    if ($WingetId -and (Test-CommandExists "winget")) {
        winget list --id $WingetId --exact --disable-interactivity --accept-source-agreements 2>$null | Out-Null

        if ($LASTEXITCODE -eq 0) {
            return
        }
    }

    $installed = Install-WithWinget -Id $WingetId -Source $Source

    if (-not $installed -and $ChocoId -and $Source -eq "winget") {
        $installed = Install-WithChoco $ChocoId
    }

    Refresh-Path

    $ok = Test-CommandExists $Command

    if (-not $ok) {
        $foundPath = $TestPaths | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
        $ok = [bool]$foundPath
    }

    if (-not $ok -and $DetectAppx) {
        $ok = [bool](Get-AppxPackage -Name $DetectAppx -ErrorAction SilentlyContinue)
    }

    if (-not $ok) {
        Write-Warning "⚠️ Failed to install '$Name'"
    }
}

$Packages = @(
    @{
        Name     = "zoxide"
        Command  = "zoxide"
        WingetId = "ajeetdsouza.zoxide"
        ChocoId  = "zoxide"
    },
    @{
        Name     = "oh-my-posh"
        Command  = "oh-my-posh"
        WingetId = "JanDeDobbeleer.OhMyPosh"
        ChocoId  = "oh-my-posh"
    },
    @{
        Name     = "atuin"
        Command  = "atuin"
        WingetId = "atuinsh.atuin"
        ChocoId  = "atuin"
    },
    @{
        Name     = "fzf"
        Command  = "fzf"
        WingetId = "junegunn.fzf"
        ChocoId  = "fzf"
    },
    @{
        Name     = "fd"
        Command  = "fd"
        WingetId = "sharkdp.fd"
        ChocoId  = "fd"
    },
    @{
        Name     = "bat"
        Command  = "bat"
        WingetId = "sharkdp.bat"
        ChocoId  = "bat"
    },
    @{
        Name     = "eza"
        Command  = "eza"
        WingetId = "eza-community.eza"
        ChocoId  = "eza"
    },
    @{
        Name     = "yazi"
        Command  = "yazi"
        WingetId = "sxyazi.yazi"
        ChocoId  = "yazi"
    },
    @{
        Name      = "neovim"
        Command   = "nvim"
        WingetId  = "Neovim.Neovim"
        ChocoId   = "neovim"
        TestPaths = @(
            "$env:ProgramFiles\Neovim\bin\nvim.exe",
            "$env:LOCALAPPDATA\Microsoft\WinGet\Links\nvim.exe",
            "C:\ProgramData\chocolatey\bin\nvim.exe"
        )
    },
    @{
        Name      = "notepad++"
        Command   = "notepad++"
        WingetId  = "Notepad++.Notepad++"
        ChocoId   = "notepadplusplus.install"
        TestPaths = @(
            "$env:ProgramFiles\Notepad++\notepad++.exe",
            "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe"
        )
    },
    @{
        Name      = "autohotkey"
        Command   = ""
        WingetId  = "AutoHotkey.AutoHotkey"
        ChocoId   = "autohotkey"
        TestPaths = @(
            "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
            "$env:ProgramFiles\AutoHotkey\AutoHotkey.exe"
        )
    },
    @{
        Name     = "powershell 7"
        Command  = "pwsh"
        WingetId = "Microsoft.PowerShell"
        ChocoId  = "powershell-core"
    },
    @{
        Name      = "firefox developer edition"
        Command   = "firefox"
        WingetId  = "Mozilla.Firefox.DeveloperEdition"
        ChocoId   = "firefox-developer-edition"
        TestPaths = @("$env:ProgramFiles\Firefox\firefox.exe")
    },
    @{
        Name      = "paint.net"
        Command   = "paintdotnet"
        WingetId  = "dotPDN.PaintDotNet"
        ChocoId   = "paint.net"
        TestPaths = @("$env:ProgramFiles\paint.net\paintdotnet.exe")
    },
    @{
        Name      = "windows terminal"
        Command   = "wt"
        WingetId  = "Microsoft.WindowsTerminal"
        ChocoId   = ""
        TestPaths = @("$env:LOCALAPPDATA\Microsoft\WindowsApps\wt.exe")
    },
    @{
        Name      = "spotify"
        Command   = "spotify"
        WingetId  = "Spotify.Spotify"
        ChocoId   = "spotify"
        TestPaths = @("$env:APPDATA\Spotify\Spotify.exe")
    },
    @{
        Name      = "everything"
        Command   = "es"
        WingetId  = "voidtools.Everything"
        ChocoId   = "everything"
        TestPaths = @(
            "$env:ProgramFiles\Everything\Everything.exe",
            "$env:ProgramFiles\Everything\es.exe"
        )
    },
    @{
        Name       = "outlook for windows"
        Command    = ""
        WingetId   = "9NRX63209R7B"
        ChocoId    = ""
        Source     = "msstore"
        DetectAppx = "Microsoft.OutlookForWindows"
    },
    @{
        Name      = "winaero tweaker"
        Command   = ""
        WingetId  = "winaero.tweaker"
        ChocoId   = ""
        TestPaths = @("$env:ProgramFiles\Winaero Tweaker\WinaeroTweaker.exe")
    },
    @{
        Name      = "shutup10"
        Command   = ""
        WingetId  = "OO-Software.ShutUp10"
        ChocoId   = ""
        TestPaths = @(
            "${env:ProgramFiles(x86)}\O&O ShutUp10\OOSU10.exe"
        )
    }
)

foreach ($pkg in $Packages) {

    $params = @{
        Name     = $pkg.Name
        Command  = $pkg.Command
        WingetId = $pkg.WingetId
        ChocoId  = $pkg.ChocoId
    }

    if ($pkg.ContainsKey('TestPaths')) {
        $params.TestPaths = $pkg.TestPaths
    }

    if ($pkg.ContainsKey('Source')) {
        $params.Source = $pkg.Source
    }

    if ($pkg.ContainsKey('DetectAppx')) {
        $params.DetectAppx = $pkg.DetectAppx
    }

    Install-PackageFallback @params
}

$Modules = @(
    "Terminal-Icons",
    "PSReadLine",
    "PSWriteColor",
    "alias-tips"
)

foreach ($name in $Modules) {

    if (-not (Get-Module -ListAvailable -Name $name)) {

        try {
            Install-Module `
                -Name $name `
                -Scope CurrentUser `
                -Force `
                -AllowClobber `
                -SkipPublisherCheck `
                -ErrorAction Stop
        }
        catch {
            Write-Warning "⚠️ Couldn't install module '$name'"
        }
    }
}

# =========================================================
# 🖥️  Fonts & Windows Terminal
# =========================================================

$RepoRoot = Split-Path -Parent $PSScriptRoot

function Install-FontsFromFolder {
    param([string]$SourceDir)

    if (-not (Test-Path -LiteralPath $SourceDir)) {
        Write-Warning "⚠️ Font source folder not found: $SourceDir"
        return
    }

    $fontFiles = Get-ChildItem -LiteralPath $SourceDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in ".ttf", ".otf" }

    if (-not $fontFiles) {
        Write-Warning "⚠️ No .ttf/.otf fonts found in $SourceDir"
        return
    }

    Add-Type -AssemblyName PresentationCore

    $fontDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    New-Item -ItemType Directory -Path $fontDir -Force | Out-Null

    $fontsKey = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"

    foreach ($font in $fontFiles) {

        $dest = Join-Path $fontDir $font.Name

        if (-not (Test-Path -LiteralPath $dest)) {
            Copy-Item -LiteralPath $font.FullName -Destination $dest
        }

        try {
            $typeface = New-Object System.Windows.Media.GlyphTypeface((New-Object Uri $font.FullName))
            $family   = $typeface.Win32FamilyNames.Values | Select-Object -First 1
        }
        catch {
            $family = $font.BaseName
        }

        $valueName = "$family ($(if ($font.Extension -eq ".otf") { "OpenType" } else { "TrueType" }))"
        $existing  = Get-ItemProperty -Path $fontsKey -Name $valueName -ErrorAction SilentlyContinue

        if (-not $existing -or ($existing.$valueName -ne $font.Name)) {
            New-ItemProperty -Path $fontsKey -Name $valueName -Value $font.Name -PropertyType String -Force | Out-Null
        }
    }

    Write-Host "✔ Installed $($fontFiles.Count) fonts from $(Split-Path $SourceDir -Leaf)" -ForegroundColor Green
}

$fontSource = Join-Path $RepoRoot "color.schemes-fonts\FiraCode"

Write-Host "`n== Fonts ==" -ForegroundColor Cyan
Install-FontsFromFolder -SourceDir $fontSource

Write-Host "`n== Windows Terminal settings ==" -ForegroundColor Cyan

$settingsTemplate = Join-Path $RepoRoot "color.schemes-fonts\settings.json"

if (-not (Test-Path -LiteralPath $settingsTemplate)) {
    Write-Warning "⚠️ settings.json template missing (gitignored on an old clone?); skipping terminal config."
}
else {

    $wtPackage  = Get-AppxPackage -Name "Microsoft.WindowsTerminal" -ErrorAction SilentlyContinue
    $localState = if ($wtPackage) {
        Join-Path $env:LOCALAPPDATA "Packages\$($wtPackage.PackageFamilyName)\LocalState"
    }
    else {
        Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
    }

    if ($wtPackage -and -not (Test-Path -LiteralPath $localState)) {
        New-Item -ItemType Directory -Path $localState -Force | Out-Null
    }

    if (Test-Path -LiteralPath $localState) {

        $target  = Join-Path $localState "settings.json"
        $content = Get-Content -LiteralPath $settingsTemplate -Raw

        $escapedUser = $env:USERPROFILE.Replace("\", "\\")
        $content     = $content.Replace("C:\\Users\\Admin", $escapedUser)

        $existingContent = if (Test-Path -LiteralPath $target) {
            Get-Content -LiteralPath $target -Raw
        }
        else {
            ""
        }

        if ($existingContent -eq $content) {
            Write-Host "✔ Windows Terminal settings already up to date" -ForegroundColor Green
        }
        else {
            if ($existingContent) {
                $backup = "$target.bak-$(Get-Date -Format "yyyyMMdd-HHmmss")"
                Copy-Item -LiteralPath $target -Destination $backup
                Write-Host "✔ Backed up existing settings → $(Split-Path $backup -Leaf)" -ForegroundColor Green
            }

            [System.IO.File]::WriteAllText(
                $target,
                $content,
                (New-Object System.Text.UTF8Encoding $false)
            )

            Write-Host "✔ Deployed Windows Terminal settings → $target" -ForegroundColor Green
        }
    }
    else {
        Write-Warning "⚠️ Windows Terminal LocalState not found: $localState (start Windows Terminal once, then re-run)."
    }
}

# =========================================================
# 🛠️  Winaero Tweaker settings (applied via registry)
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

$iniPath = Join-Path $RepoRoot "bootstrap-packages\Winaero-Tweaker-Settings.ini"

if (-not (Test-Path -LiteralPath $iniPath)) {
    Write-Warning "⚠️ Winaero-Tweaker-Settings.ini not found in bootstrap-packages; skipping tweaks."
}
else {

    Write-Host "`n== Winaero Tweaker settings ==" -ForegroundColor Cyan

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
}

# =========================================================
# ⌨️  AutoHotkey keybinds (Win+... launchers & clipboard)
# =========================================================

function Resolve-PathOrEmpty {
    param([string[]]$Paths)

    foreach ($p in $Paths) {
        if ($p -and (Test-Path -LiteralPath $p)) {
            return $p
        }
    }

    return ""
}

function Get-CommandSource {
    param([string]$Name)

    $cmd = Get-Command $Name -ErrorAction SilentlyContinue

    if ($cmd) {
        return $cmd.Source
    }

    return ""
}

function New-LauncherLine {
    param(
        [string]$Hotkey,
        [string]$Target,
        [string]$Comment
    )

    if ($Target) {
        return "$Hotkey::Run `"$Target`"   ; $Comment"
    }

    return "; $Hotkey : SKIPPED ($Comment not found)"
}

$pwsh   = Get-CommandSource "pwsh"
$wt     = Get-CommandSource "wt"
$firefox   = Resolve-PathOrEmpty @("$env:ProgramFiles\Firefox\firefox.exe")
$notepad   = Resolve-PathOrEmpty @("$env:ProgramFiles\Notepad++\notepad++.exe", "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe")
$paint     = Resolve-PathOrEmpty @("$env:ProgramFiles\paint.net\paintdotnet.exe")
$spotify   = Resolve-PathOrEmpty @("$env:APPDATA\Spotify\Spotify.exe")
$everything = Resolve-PathOrEmpty @("$env:ProgramFiles\Everything\Everything.exe")
$search    = Resolve-PathOrEmpty @("$env:ProgramData\PhoenixOS\Search\Search.exe")

$AhkLines = @(
    "#Requires AutoHotkey v2.0",
    "#UseHook On",
    "",
    "; ===== App launchers (generated by bootstrap.ps1) ====="
)

$AhkLines += New-LauncherLine "#Enter" $pwsh      "PowerShell 7"
$AhkLines += New-LauncherLine "#b"     $firefox   "Firefox Developer Edition"
$AhkLines += New-LauncherLine "#f"     "explorer.exe" "File Explorer"
$AhkLines += New-LauncherLine "#n"     $notepad   "Notepad++"
$AhkLines += New-LauncherLine "#p"     $paint     "paint.NET"
$AhkLines += New-LauncherLine "#t"     $wt        "Windows Terminal"
$AhkLines += New-LauncherLine "#m"     "ms-outlook:" "Outlook for Windows"
$AhkLines += New-LauncherLine "#s"     $spotify   "Spotify"
$AhkLines += New-LauncherLine "#!s"    "ms-settings:" "System Settings"
$AhkLines += New-LauncherLine "#/"     $search    "PhoenixOS Search (requires Everything)"

$AhkLines += ""
$AhkLines += "; ===== Clipboard / edit ====="
$AhkLines += "#z::SendInput `"^z`"   ; Undo"
$AhkLines += "#x::SendInput `"^x`"   ; Cut"
$AhkLines += "#c::SendInput `"^c`"   ; Copy"
$AhkLines += "#v::SendInput `"^v`"   ; Paste"
$AhkLines += "#a::SendInput `"^y`"   ; Redo"
$AhkLines += ""
$AhkLines += "; ===== Close active window ====="
$AhkLines += "#q::WinClose `"A`""

$AhkScriptDir = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "AutoHotkey"
$AhkScript    = Join-Path $AhkScriptDir "keybinds.ahk"

New-Item -ItemType Directory -Path $AhkScriptDir -Force | Out-Null

$ahkContent = ($AhkLines -join "`r`n") + "`r`n"

$existingAhk = if (Test-Path -LiteralPath $AhkScript) {
    Get-Content -LiteralPath $AhkScript -Raw
}
else {
    ""
}

if ($existingAhk -eq $ahkContent) {
    Write-Host "✔ keybinds.ahk already up to date" -ForegroundColor Green
}
else {
    [System.IO.File]::WriteAllText(
        $AhkScript,
        $ahkContent,
        (New-Object System.Text.UTF8Encoding $false)
    )

    Write-Host "✔ Wrote $AhkScript" -ForegroundColor Green
}

$ahkExe = Resolve-PathOrEmpty @(
    "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
    "$env:ProgramFiles\AutoHotkey\AutoHotkey.exe"
)

if ($ahkExe) {

    $ahk2Exe = Get-ChildItem `
        -Path (Split-Path $ahkExe -Parent) `
        -Recurse -Filter "Ahk2Exe.exe" `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($ahk2Exe) {

        $checkOut = Join-Path $env:TEMP "keybinds.syntaxcheck.exe"

        & $ahk2Exe.FullName /in $AhkScript /out $checkOut /silent | Out-Null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✔ keybinds.ahk syntax OK (compiled with Ahk2Exe)" -ForegroundColor Green
        }
        else {
            Write-Warning "⚠️ keybinds.ahk syntax check FAILED (Ahk2Exe exit $LASTEXITCODE)"
        }

        Remove-Item -LiteralPath $checkOut -Force -ErrorAction SilentlyContinue
    }
    else {
        Write-Host "ℹ️  Ahk2Exe not found; AutoHotkey validates syntax when the script starts at login." -ForegroundColor Yellow
    }

    $startupDir = [Environment]::GetFolderPath("Startup")
    $shortcut   = Join-Path $startupDir "keybinds.ahk.lnk"

    if (-not (Test-Path -LiteralPath $shortcut)) {

        $shell = New-Object -ComObject WScript.Shell
        $sc    = $shell.CreateShortcut($shortcut)
        $sc.TargetPath       = $ahkExe
        $sc.Arguments        = "`"$AhkScript`""
        $sc.WorkingDirectory = $AhkScriptDir
        $sc.Save()

        Write-Host "✔ Autostart shortcut created: $shortcut" -ForegroundColor Green
    }
    else {
        Write-Host "✔ Autostart shortcut already exists: $shortcut" -ForegroundColor Green
    }
}
else {
    Write-Warning "⚠️ AutoHotkey not found; skipped keybinds.ahk validation and autostart."
}

$disabledKey   = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$disabledValue = "BCFMNPSTVXZQA"

$currentDisabled = Get-RegValue -Path $disabledKey -Name "DisabledHotkeys"

if ($currentDisabled -eq $disabledValue) {
    Write-Host "✔ DisabledHotkeys already set to '$disabledValue'" -ForegroundColor Green
}
else {
    Set-ItemProperty `
        -Path $disabledKey `
        -Name "DisabledHotkeys" `
        -Value $disabledValue `
        -Type String `
        -ErrorAction SilentlyContinue

    Write-Host "✔ DisabledHotkeys registry set to '$disabledValue'" -ForegroundColor Green
}

# Everything CLI (es.exe) on the user PATH
$everythingDir = "$env:ProgramFiles\Everything"

if (Test-Path -LiteralPath "$everythingDir\es.exe") {

    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")

    if (($userPath -split ";") -notcontains $everythingDir) {

        $newPath = if ($userPath) { "$userPath;$everythingDir" } else { $everythingDir }

        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")

        Write-Host "✔ Added '$everythingDir' to user PATH" -ForegroundColor Green
    }
    else {
        Write-Host "✔ '$everythingDir' already on user PATH" -ForegroundColor Green
    }
}

# =========================================================
# 🧠  opencode memory system (git clone + configure)
# =========================================================

function Install-OpencodeMemorySystem {
    $repoUrl = "https://github.com/ADHD-exe/opencode.git"
    $target  = Join-Path $HOME "Documents\opencode"

    Write-Host "`n== opencode memory system ==" -ForegroundColor Cyan

    if (-not (Test-CommandExists "git")) {
        Write-Warning "⚠️ git not found; skipping opencode memory system setup."
        return
    }

    if (Test-Path -LiteralPath (Join-Path $target ".git")) {
        Write-Host "ℹ️  opencode repo already present — pulling latest." -ForegroundColor Yellow
        git -C $target pull --ff-only | Out-Null

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "⚠️ git pull failed; continuing with existing copy."
        }
    }
    elseif (Test-Path -LiteralPath $target) {
        Write-Warning "⚠️ $target exists but is not a git repo; skipping (won't overwrite)."
        return
    }
    else {
        Write-Host "ℹ️  Cloning opencode repo → $target" -ForegroundColor Yellow
        git clone $repoUrl $target | Out-Null

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "⚠️ Failed to clone opencode repo."
            return
        }
    }

    $archive = Join-Path $target "scripts\archive.ps1"

    if (Test-Path -LiteralPath $archive) {
        & $archive
        Write-Host "✔ opencode memory system configured (memories\ dirs + INDEX.md)" -ForegroundColor Green
    }
    else {
        Write-Warning "⚠️ scripts\archive.ps1 not found; opencode memory system not configured."
    }
}

$opencodeAnswer = Read-Host "`nInstall & configure the opencode memory system from https://github.com/ADHD-exe/opencode.git? (y/N)"

if ($opencodeAnswer -match "^(y|yes)$") {
    Install-OpencodeMemorySystem
}

Write-Host "`n✔ Bootstrap complete" -ForegroundColor Green
