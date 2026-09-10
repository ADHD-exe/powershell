# =========================================================
# 🧭 NAVIGATION
# =========================================================

function ..   { Set-Location .. }
function ...  { Set-Location ../.. }
function .... { Set-Location ../../.. }

function home { Set-Location $HOME }
function docs { Set-Location ([Environment]::GetFolderPath("MyDocuments")) }
function dl   { Set-Location "$HOME\Downloads" }
function desk { Set-Location "$HOME\Desktop" }

function mkcd {
    param([string]$Dir)
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    Set-Location $Dir
}

# All four are eza in different view modes. They're functions rather than
# aliases so they can take a path and extra flags: `ls src`, `la -s size`.
function ls { eza --icons --group-directories-first @args }
function ll { eza --icons --group-directories-first --long --git --header @args }
function la { eza --icons --group-directories-first --long --git --header --all @args }
function lt { eza --icons --group-directories-first --tree --level=2 @args }

# =========================================================
# 📂 FILE / SYSTEM
# =========================================================

function touch {
    param([string]$File)
    if (Test-Path $File) { (Get-Item $File).LastWriteTime = Get-Date }
    else { New-Item $File -ItemType File | Out-Null }
}

function head { param([string]$Path,[int]$Lines=10) Get-Content $Path -Head $Lines }
function tail { param([string]$Path,[int]$Lines=10) Get-Content $Path -Tail $Lines }

# Takes precedence over the Info-ZIP unzip.exe that ships with Git for Windows
# (functions beat external programs). Extracts to the current directory unless
# a destination is given.
function unzip {
    param(
        [Parameter(Mandatory, Position = 0)][string]$Path,
        [Parameter(Position = 1)][string]$Destination = ".",
        [switch]$Force
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Warning "Archive not found: $Path"
        return
    }

    Expand-Archive -LiteralPath $Path -DestinationPath $Destination -Force:$Force
}

function which {
    param([string]$Name)
    (Get-Command $Name -ErrorAction SilentlyContinue)?.Source
}

function pgrep { param([string]$Name) Get-Process $Name -ErrorAction SilentlyContinue }

function pkill {
    param([string]$Name)
    $procs = pgrep $Name
    if ($procs) { $procs | Stop-Process -Force }
}

function k9 { param([string]$Name) pkill $Name }

# =========================================================
# 📋 CLIPBOARD
# =========================================================

# Named cbcopy/cbpaste, not copy/paste: PowerShell resolves aliases before
# functions, and `copy` is a built-in alias for Copy-Item - a function of that
# name can never run.
function cbcopy {
    param([Parameter(ValueFromPipeline=$true)]$InputObject)
    process { $InputObject | Set-Clipboard }
}

function cbpaste { Get-Clipboard }

function Copy-Pwd { (Get-Location).Path | Set-Clipboard }

function Copy-Path {
    param([string]$File)
    if ($File) { (Resolve-Path $File).Path | Set-Clipboard }
    else { (Get-Location).Path | Set-Clipboard }
}

function Copy-FileContent {
    param([Parameter(Mandatory)][string]$File)
    Get-Content -Raw -LiteralPath $File | Set-Clipboard
}

Set-Alias copypath Copy-Path
Set-Alias copyfile Copy-FileContent

# =========================================================
# ⚙️ SYSTEM
# =========================================================

function uptime {
    $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $elapsed = (Get-Date) - $boot
    Write-Host ("Up {0}d {1}h {2}m {3}s" -f $elapsed.Days,$elapsed.Hours,$elapsed.Minutes,$elapsed.Seconds)
}

function sysinfo {
    $os  = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    Write-Host "OS:  $($os.Caption)"
    Write-Host "CPU: $($cpu.Name)"
    uptime
}

function Admin { Start-Process pwsh -Verb RunAs }

function Port {
    param([int]$Port)
    Get-NetTCPConnection -LocalPort $Port
}

function Restart-Explorer {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer
}

function Restart-System {
    param([switch]$Force)
    if ($Force -or (Read-Host "Reboot this computer now? (y/N)") -eq 'y') {
        Restart-Computer -Force
    }
}

# =========================================================
# 🦊 APPLICATIONS
# =========================================================

function Get-NotepadPlusPlus {
    $candidates = @(
        "$env:ProgramFiles\Notepad++\notepad++.exe"
    )
    if (${env:ProgramFiles(x86)}) {
        $candidates += "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe"
    }

    $candidates |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-Object -First 1
}

function notepad {
    $exe = Get-NotepadPlusPlus
    if (-not $exe) {
        Write-Warning "Notepad++ is not installed. Run .\bootstrap-packages\bootstrap.ps1 to install it."
        return
    }
    & $exe $args
}

function edit { notepad $args }

function web {
    param([string]$Url)
    if ($Url) { Start-Process $Url }
}

function phonecam {
    # OpenCam - use an iPhone as a wireless webcam. Installed by the bootstrap
    # into Documents\OpenCam with its own venv; pythonw keeps the console hidden.
    $dir = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "OpenCam"
    $exe = Join-Path $dir "venv\Scripts\pythonw.exe"

    if (-not (Test-Path -LiteralPath $exe)) {
        Write-Warning "OpenCam isn't installed. Run .\bootstrap-packages\bootstrap.ps1 to set it up."
        return
    }

    Start-Process -FilePath $exe -ArgumentList "main.py" -WorkingDirectory $dir
}

function search {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Query)
    $q = [uri]::EscapeDataString(($Query -join ' '))
    web "https://www.google.com/search?q=$q"
}

function bing {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Query)
    $q = [uri]::EscapeDataString(($Query -join ' '))
    web "https://www.bing.com/search?q=$q"
}

function ddg {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Query)
    $q = [uri]::EscapeDataString(($Query -join ' '))
    web "https://duckduckgo.com/?q=$q"
}

function gh-search {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Query)
    $q = [uri]::EscapeDataString(($Query -join ' '))
    web "https://github.com/search?q=$q"
}

function so {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Query)
    $q = [uri]::EscapeDataString(($Query -join ' '))
    web "https://stackoverflow.com/search?q=$q"
}

# =========================================================
# 🧬 GIT
# =========================================================

function gpull { git pull }
function gcom { git add .; git commit -m "$args" }
function lazyg { git add .; git commit -m "$args"; git push }

# =========================================================
# 📝 CONFIGURATION
# =========================================================

function Edit-Profile { nvim $PROFILE }

function Reload-Profile {
    Remove-Variable RABBIT_PROFILE_LOADED -Scope Global -ErrorAction SilentlyContinue

    # oh-my-posh, notify.ps1 and YouShouldUse each wrap the prompt. Reloading
    # without unwinding that chain makes them wrap each other's wrappers, which
    # ends in a call-depth overflow. Deleting the prompt doesn't work either:
    # `. $PROFILE` here dot-sources into this function's scope, so oh-my-posh's
    # re-init never reaches global and the prompt would be lost. So unwind to
    # the original prompt that notify.ps1 saved, then let them re-wrap cleanly.
    if (Get-Command Disable-YouShouldUse -ErrorAction SilentlyContinue) {
        Disable-YouShouldUse -ErrorAction SilentlyContinue
    }

    if ($global:__PreNotifyPrompt) {
        Set-Item -Path Function:global:prompt -Value $global:__PreNotifyPrompt
    }

    . $PROFILE
    Write-Host "󰑐 Profile reloaded" -ForegroundColor Green
}

function fn { notepad "$PSScriptRoot\functions.ps1" }
function al { notepad "$PSScriptRoot\aliases.ps1" }
function theme { notepad "$(Split-Path -Parent $PSScriptRoot)\settings\oh-my-rabbit.omp.json" }

# =========================================================
# 🔐 HISTORY
# =========================================================

function forget {
    param([Parameter(Mandatory)][string]$Pattern)
    $historyFile = (Get-PSReadLineOption).HistorySavePath
    if (Test-Path $historyFile) {
        (Get-Content $historyFile) |
            Where-Object { $_ -notmatch [regex]::Escape($Pattern) } |
            Set-Content $historyFile
    }
}

Set-Alias help! Get-Help

# `man <command>` -> Get-Help <command> -Full, so the full article is the
# default rather than the summary. PowerShell ships `man` as an alias for
# `help`; aliases outrank functions, so aliases.ps1 removes it first.
function man {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Name,
        [switch]$Detailed,
        [switch]$Examples,
        [switch]$Online,
        [switch]$ShowWindow,
        [string]$Parameter
    )

    # Get-Help puts each view in its own parameter set, so they're forwarded
    # one at a time rather than splatted - -Full alongside any other view
    # switch makes Get-Help fail to resolve the set.
    if ($Detailed)   { return Get-Help $Name -Detailed }
    if ($Examples)   { return Get-Help $Name -Examples }
    if ($Online)     { return Get-Help $Name -Online }
    if ($ShowWindow) { return Get-Help $Name -ShowWindow }
    if ($Parameter)  { return Get-Help $Name -Parameter $Parameter }

    Get-Help $Name -Full
}

# =========================================================
# COMMAND PALETTE
# =========================================================

function Invoke-CommandPalette {

    $commands = @(
        "⚡ Edit Profile"
        "📦 Reload Profile"
        "🌳 Git Status"
        "🚀 Git Push"
        "📥 Git Pull"
        "🗂️ Yazi"
        "🏠 Home"
        "📁 Downloads"
        "📄 Documents"
        "🖥️ Desktop"
    )

    $selection = $commands |
        fzf `
            --height 40% `
            --layout reverse `
            --border `
            --prompt "⚡ Rabbit Command Palette > " `
            --header "Modern PowerShell Toolkit"

    switch ($selection) {

        "⚡ Edit Profile" { Edit-Profile }
        "📦 Reload Profile" { Reload-Profile }
        "🌳 Git Status" { gs }
        "🚀 Git Push" { gp }
        "📥 Git Pull" { gl }
        "🗂️ Yazi" { yy }
        "🏠 Home" { home }
        "📁 Downloads" { dl }
        "📄 Documents" { docs }
        "🖥️ Desktop" { desk }
    }
}
