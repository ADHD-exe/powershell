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

        if ($existingContent -and ($existingContent -ne $content)) {
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
    else {
        Write-Warning "⚠️ Windows Terminal LocalState not found: $localState (start Windows Terminal once, then re-run)."
    }
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
Set-Content -Path $AhkScript -Value $AhkLines -Encoding UTF8

Write-Host "✔ Wrote $AhkScript" -ForegroundColor Green

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

Set-ItemProperty `
    -Path $disabledKey `
    -Name "DisabledHotkeys" `
    -Value $disabledValue `
    -Type String `
    -ErrorAction SilentlyContinue

Write-Host "✔ DisabledHotkeys registry set to '$disabledValue'" -ForegroundColor Green

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

Write-Host "`n✔ Bootstrap complete" -ForegroundColor Green
