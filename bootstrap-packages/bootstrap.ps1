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
        Name      = "git"
        Command   = "git"
        WingetId  = "Git.Git"
        ChocoId   = "git"
        TestPaths = @("$env:ProgramFiles\Git\cmd\git.exe")
    },
    @{
        Name      = "git-lfs"
        Command   = "git-lfs"
        WingetId  = "GitHub.GitLFS"
        ChocoId   = "git-lfs"
    },
    @{
        Name      = "node.js lts"
        Command   = "node"
        WingetId  = "OpenJS.NodeJS.LTS"
        ChocoId   = "nodejs-lts"
        TestPaths = @("$env:ProgramFiles\nodejs\node.exe")
    },
    @{
        Name      = "tailscale"
        Command   = "tailscale"
        WingetId  = "tailscale.tailscale"
        ChocoId   = "tailscale"
        TestPaths = @("$env:ProgramFiles\Tailscale\tailscale.exe")
    },
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
        Command   = ""
        WingetId  = "voidtools.Everything.Lite"
        ChocoId   = "everything"
        TestPaths = @(
            "$env:ProgramFiles\Everything\Everything.exe"
        )
    },
    @{
        # The `es` CLI is a separate package - Everything Lite doesn't ship it,
        # which is why `es` was missing even with Everything installed.
        Name      = "everything cli (es)"
        Command   = "es"
        WingetId  = "voidtools.Everything.Cli"
        ChocoId   = ""
        TestPaths = @(
            "$env:ProgramFiles\Everything\es.exe",
            "$env:LOCALAPPDATA\Microsoft\WinGet\Links\es.exe"
        )
    },
    @{
        # Launched by keybinds.ahk (Win+E)
        Name      = "em client"
        Command   = ""
        WingetId  = "eMClient.eMClient"
        ChocoId   = ""
        TestPaths = @("${env:ProgramFiles(x86)}\eM Client\MailClient.exe")
    },
    @{
        # Discord client used by keybinds.ahk (Win+D)
        Name      = "equibop"
        Command   = ""
        WingetId  = "Equicord.Equibop"
        ChocoId   = ""
        TestPaths = @("$env:LOCALAPPDATA\Equibop\equibop.exe")
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
    },
    @{
        Name      = "opencode"
        Command   = "opencode"
        WingetId  = "SST.opencode"
        ChocoId   = ""
        TestPaths = @(
            "$env:LOCALAPPDATA\Microsoft\WinGet\Links\opencode.exe"
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
    "BurntToast",
    "syntax-highlighting",
    "PSEverything"
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
# 🧩  Modules from git (not on the PS Gallery)
# =========================================================

function Install-GitModule {
    <#
        Clones a module straight into the profile's Modules folder. The folder
        name must match the .psd1 basename or PowerShell can't discover the
        module by name, so it's passed explicitly rather than inferred from the
        repo name.
    #>
    param(
        [string]$Name,
        [string]$RepoUrl
    )

    $modulesDir = Join-Path (Split-Path -Parent $PSScriptRoot) "Modules"
    $target     = Join-Path $modulesDir $Name

    if (-not (Test-CommandExists "git")) {
        Write-Warning "⚠️ git not found; skipping module '$Name'."
        return
    }

    New-Item -ItemType Directory -Path $modulesDir -Force | Out-Null

    if (Test-Path -LiteralPath (Join-Path $target ".git")) {

        git -C $target pull --ff-only 2>&1 | Out-Null

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "⚠️ git pull failed for '$Name'; keeping the existing copy."
        }
        else {
            Write-Host "✔ '$Name' up to date" -ForegroundColor Green
        }
    }
    elseif (Test-Path -LiteralPath $target) {
        Write-Warning "⚠️ $target exists but isn't a git clone; leaving it alone."
        return
    }
    else {

        git clone --depth 1 $RepoUrl $target 2>&1 | Out-Null

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "⚠️ Couldn't clone '$Name' from $RepoUrl"
            return
        }

        Write-Host "✔ Cloned '$Name' -> $target" -ForegroundColor Green
    }

    # Cloned files carry the internet zone marker, and RemoteSigned refuses to
    # load unsigned scripts that have it.
    Get-ChildItem -LiteralPath $target -Recurse -File -ErrorAction SilentlyContinue |
        Unblock-File -ErrorAction SilentlyContinue
}

Install-GitModule `
    -Name "YouShouldUse" `
    -RepoUrl "https://github.com/ADHD-exe/pwsh-you-should-use.git"

# =========================================================
# 🖥️  Fonts & Windows Terminal
# =========================================================

$RepoRoot = Split-Path -Parent $PSScriptRoot

function Install-FontsFromFolder {
    param([string]$SourceDir)

    if (-not (Test-Path -LiteralPath $SourceDir)) {
        Write-Warning "⚠️ Font source folder not found: $SourceDir"
        return $false
    }

    $fontFiles = Get-ChildItem -LiteralPath $SourceDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in ".ttf", ".otf" }

    if (-not $fontFiles) {
        Write-Warning "⚠️ No .ttf/.otf fonts found in $SourceDir"
        return $false
    }

    Add-Type -AssemblyName PresentationCore

    $fontDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    New-Item -ItemType Directory -Path $fontDir -Force | Out-Null

    $fontsKey = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"

    $changed = $false

    foreach ($font in $fontFiles) {

        $dest = Join-Path $fontDir $font.Name

        if (-not (Test-Path -LiteralPath $dest)) {
            Copy-Item -LiteralPath $font.FullName -Destination $dest
            $changed = $true
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
            $changed = $true
        }
    }

    Write-Host "✔ Installed $($fontFiles.Count) fonts from $(Split-Path $SourceDir -Leaf)" -ForegroundColor Green

    return $changed
}

$fontSource = Join-Path $RepoRoot "settings\fonts"

Write-Host "`n== Fonts ==" -ForegroundColor Cyan
$fontsChanged = Install-FontsFromFolder -SourceDir $fontSource

Write-Host "`n== Windows Terminal settings ==" -ForegroundColor Cyan

$settingsTemplate = Join-Path $RepoRoot "settings\settings.json"

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

# Windows Terminal caches its font list when it starts, so a terminal that was
# already running before the bundled Nerd Fonts were installed can't see them until
# it restarts — otherwise it throws "Unable to find the following fonts".
$fontDir     = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
$newestFont  = Get-ChildItem -LiteralPath $fontDir -Filter "*.ttf" -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
$wtProcesses = Get-Process WindowsTerminal -ErrorAction SilentlyContinue

$staleWtCache = [bool]($wtProcesses | Where-Object {
    $newestFont -and $_.StartTime -lt $newestFont.LastWriteTime
})

if (($fontsChanged -or $staleWtCache) -and $wtProcesses) {

    $wtExe = Get-Command wt -ErrorAction SilentlyContinue

    $restartAnswer = Read-Host "`nWindows Terminal was running before the bundled Nerd Fonts were installed, so it can't see them until it restarts (this will close your current tabs). Restart Windows Terminal now? (y/N)"

    if ($restartAnswer -match "^(y|yes)$") {

        if ($wtExe) {

            $restartCmd = "Start-Sleep -Seconds 5; " +
                "Get-Process WindowsTerminal -ErrorAction SilentlyContinue | Stop-Process -Force; " +
                "Start-Sleep -Milliseconds 1500; " +
                "Start-Process -FilePath `"$($wtExe.Source)`""

            Start-Process pwsh `
                -WindowStyle Hidden `
                -ArgumentList @("-NoProfile", "-Command", $restartCmd)

            Write-Host "✔ Windows Terminal will restart in a few seconds to pick up the new fonts" -ForegroundColor Green
        }
        else {
            Write-Warning "⚠️ Couldn't find 'wt' to relaunch Windows Terminal; close and reopen it manually."
        }
    }
    else {
        Write-Host "ℹ️  Close all Windows Terminal windows once to clear the 'Unable to find the following fonts' error." -ForegroundColor Yellow
    }
}

# =========================================================
# 🎛️  App configs & customizations
# =========================================================

# Everything under settings\ that isn't fonts or the terminal template:
# atuin, git, opencode, Notepad++, Everything, and the AutoHotkey scripts.
$deployConfigs = Join-Path $PSScriptRoot "deploy-configs.ps1"

if (Test-Path -LiteralPath $deployConfigs) {
    & $deployConfigs
}
else {
    Write-Warning "⚠️ deploy-configs.ps1 not found; app configs not deployed."
}

# =========================================================
# 🌸  Freyja AI companion (git clone + configure)
# =========================================================

function Set-OpencodeFreyja {
    param(
        [string]$PersonaFile,
        [string]$MemoryIndex
    )

    $configDir  = Join-Path $HOME ".config\opencode"
    $configPath = @(
        (Join-Path $configDir "opencode.json"),
        (Join-Path $configDir "opencode.jsonc")
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

    if (-not $configPath) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        $configPath = Join-Path $configDir "opencode.json"
    }

    $raw = if (Test-Path -LiteralPath $configPath) {
        Get-Content -LiteralPath $configPath -Raw
    }
    else {
        ""
    }

    $persona   = $PersonaFile -replace "\\", "/"
    $memoryIdx = $MemoryIndex -replace "\\", "/"
    $wanted    = @($persona, $memoryIdx)

    try {
        $config = $raw | ConvertFrom-Json -ErrorAction Stop

        $existing = @()
        if ($config.PSObject.Properties["instructions"] -and $config.instructions) {
            $existing = @($config.instructions)
        }

        $merged = @($existing + $wanted) | Where-Object { $_ } | Select-Object -Unique

        $needsWrite = [bool]($wanted | Where-Object { $existing -notcontains $_ })

        if ($needsWrite) {
            $config | Add-Member -NotePropertyName "instructions" -NotePropertyValue @($merged) -Force

            $out = $config | ConvertTo-Json -Depth 12

            [System.IO.File]::WriteAllText(
                $configPath,
                $out + "`n",
                (New-Object System.Text.UTF8Encoding $false)
            )

            Write-Host "✔ Registered Freyja in opencode config → $configPath" -ForegroundColor Green
        }
        else {
            Write-Host "✔ Freyja already registered in opencode config" -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "⚠️ Couldn't read opencode config as JSON; add the Freyja files to its 'instructions' manually."
    }
}

function Install-Freyja {
    $repoUrl = "git@github.com:ADHD-exe/freyja.git"
    $target  = Join-Path $HOME "Documents\freyja"

    Write-Host "`n== Freyja ==" -ForegroundColor Cyan

    if (-not (Test-CommandExists "git")) {
        Write-Warning "⚠️ git not found; skipping Freyja setup."
        return
    }

    if (Test-Path -LiteralPath (Join-Path $target ".git")) {
        Write-Host "ℹ️  Freyja repo already present — pulling latest." -ForegroundColor Yellow
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
        Write-Host "ℹ️  Cloning Freyja repo → $target" -ForegroundColor Yellow
        git clone $repoUrl $target | Out-Null

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "⚠️ Failed to clone Freyja repo."
            return
        }
    }

    $archive = Join-Path $target "memories\scripts\archive.ps1"

    if (Test-Path -LiteralPath $archive) {
        & $archive
        Write-Host "✔ Freyja installed & memory system configured (memories\ dirs + INDEX.md)" -ForegroundColor Green
    }
    else {
        Write-Warning "⚠️ memories\scripts\archive.ps1 not found; Freyja memory system not configured."
    }

    $personaFile = Join-Path $target "Freyja.txt"
    $memoryIndex = Join-Path $target "memories\INDEX.md"

    if ((Test-Path -LiteralPath $personaFile) -and (Test-Path -LiteralPath $memoryIndex)) {
        Set-OpencodeFreyja -PersonaFile $personaFile -MemoryIndex $memoryIndex
    }
    else {
        Write-Warning "⚠️ Freyja persona or memory index missing; opencode won't load Freyja."
    }
}

$freyjaAnswer = Read-Host "`nDownload, install & configure Freyja from https://github.com/ADHD-exe/freyja.git? (y/N)"

if ($freyjaAnswer -match "^(y|yes)$") {
    Install-Freyja
}

Write-Host "`n✔ Bootstrap complete" -ForegroundColor Green