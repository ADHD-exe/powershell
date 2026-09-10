# =========================================================
# 🧠 CORE UTILITIES
# =========================================================

function Require-Command {
    param([string]$Name,[string]$InstallHint="")
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        $hint = if ($InstallHint) { " Install: $InstallHint" } else { "" }
        Write-Warning "[$Name] not found.$hint"
    }
}

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

function ll { eza --icons --group-directories-first --git -la }
function lt { eza --tree --level=2 --icons }

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

function copy {
    param([Parameter(ValueFromPipeline=$true)]$InputObject)
    process { $InputObject | Set-Clipboard }
}

function paste { Get-Clipboard }

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
    . $PROFILE
    Write-Host "󰑐 Profile reloaded" -ForegroundColor Green
}

function fn { notepad "$PSScriptRoot\functions.ps1" }
function al { notepad "$(Split-Path -Parent $PSScriptRoot)\aliases-keybinds\aliases.ps1" }
function theme { notepad "$(Split-Path -Parent $PSScriptRoot)\color.schemes-fonts\oh-my-rabbit.omp.json" }

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

function Burn-AfterReading {
    Write-Host "History wipe routine placeholder"
}

Set-Alias burn Burn-AfterReading
Set-Alias help! Get-Help

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
