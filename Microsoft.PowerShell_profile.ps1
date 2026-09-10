# =========================================================
# Rabbit PowerShell Profile
# =========================================================

if ($global:RABBIT_PROFILE_LOADED) {
    return
}

$global:RABBIT_PROFILE_LOADED = $true

[Console]::InputEncoding  = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

$env:XDG_CONFIG_HOME ??= "$HOME\.config"
$env:XDG_DATA_HOME   ??= "$HOME\.local\share"
$env:XDG_STATE_HOME  ??= "$HOME\.local\state"
$env:XDG_CACHE_HOME  ??= "$HOME\.cache"

$env:EDITOR = "nvim"
$env:VISUAL = "nvim"

function Import-ProfileModules {

    $modules = @(
        "Terminal-Icons",
        "PSReadLine",
        "PSWriteColor",
        "alias-tips"
    )

    $scriptDirs = @(
        "$PSScriptRoot\aliases-keybinds",
        "$PSScriptRoot\completions",
        "$PSScriptRoot\scripts-functions",
        "$PSScriptRoot\Scripts",
        "$PSScriptRoot\bootstrap-packages"
    )

    $modules += Get-ChildItem -Path $scriptDirs -Recurse -Filter *.ps1 -File -ErrorAction SilentlyContinue |
        ForEach-Object {
            Select-String `
                -Path $_.FullName `
                -Pattern 'Import-Module\s+([A-Za-z][A-Za-z0-9_.\-]*)' `
                -AllMatches
        } |
        ForEach-Object { $_.Matches } |
        ForEach-Object { $_.Groups[1].Value } |
        Sort-Object -Unique

    foreach ($module in ($modules | Sort-Object -Unique)) {

        if (-not (Get-Module -ListAvailable -Name $module)) {

            Write-Host "Installing PowerShell module '$module'..." -ForegroundColor Cyan

            try {
                Set-PSRepository PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue

                Install-Module `
                    -Name $module `
                    -Scope CurrentUser `
                    -Force `
                    -AllowClobber `
                    -SkipPublisherCheck `
                    -ErrorAction Stop
            }
            catch {
                Write-Warning "Couldn't install module '$module': $($_.Exception.Message)"
            }
        }

        Import-Module $module -ErrorAction SilentlyContinue
    }
}

Import-ProfileModules

if (Get-Command zoxide -ErrorAction SilentlyContinue) {

    Invoke-Expression (& {
        zoxide init --cmd z powershell | Out-String
    })
}

if (Get-Command atuin -ErrorAction SilentlyContinue) {

    Invoke-Expression (& {
        atuin init powershell | Out-String
    })
}

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {

    Invoke-Expression (& {
        oh-my-posh init pwsh `
            --config "$PSScriptRoot\settings\oh-my-rabbit.omp.json" |
            Out-String
    })

    $null = & prompt 2>$null
}


Set-PSReadLineOption `
    -PredictionSource HistoryAndPlugin

Set-PSReadLineOption `
    -PredictionViewStyle InLineView

Set-PSReadLineOption `
    -HistorySaveStyle SaveIncrementally

Set-PSReadLineOption `
    -Colors @{
        Command   = '#87CEEB'
        Parameter = '#98FB98'
        Operator  = '#FFB6C1'
        Variable  = '#DDA0DD'
        String    = '#FFDAB9'
        Number    = '#B0E0E6'
        Type      = '#F0E68C'
        Comment   = '#D3D3D3'
        Keyword   = '#8367c7'
        Error     = '#FF6347'
    }

Set-PSReadLineKeyHandler `
    -Key 'UpArrow' `
    -Function HistorySearchBackward

Set-PSReadLineKeyHandler `
    -Key 'DownArrow' `
    -Function HistorySearchForward

Set-PSReadLineKeyHandler `
    -Chord 'Ctrl+UpArrow' `
    -Function HistorySearchBackward

Set-PSReadLineKeyHandler `
    -Chord 'Ctrl+DownArrow' `
    -Function HistorySearchForward

Set-PSReadLineKeyHandler `
    -Key Tab `
    -Function MenuComplete

Set-PSReadLineKeyHandler -Chord Ctrl+f -ScriptBlock {

    $files = if (
        (Get-Command git -ErrorAction SilentlyContinue) -and
        (git rev-parse --is-inside-work-tree 2>$null)
    ) {
        git ls-files
    }
    else {
        fd `
            --type file `
            --hidden `
            --exclude .git
    }

    $selected = $files |
        fzf `
            --height 50% `
            --layout reverse `
            --border `
            --preview "bat --style=numbers --color=always {}"

    if ($selected) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($selected)
    }
}

Set-PSReadLineKeyHandler -Chord Alt+Spacebar -ScriptBlock {

    $selected = zoxide query -l |
        fzf `
            --height 40% `
            --layout reverse `
            --border `
            --preview "eza --icons --group-directories-first {}"

    if ($selected) {

        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()

        Set-Location $selected

        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
}

function yy {

    $tmp = [System.IO.Path]::GetTempFileName()

    yazi $PWD --cwd-file="$tmp"

    if (Test-Path $tmp) {

        $cwd = Get-Content -Path $tmp -ErrorAction SilentlyContinue

        if ($cwd -and (Test-Path $cwd)) {
            Set-Location $cwd
        }

        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}

Set-PSReadLineKeyHandler -Chord Ctrl+y -ScriptBlock {

    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()

    yy

    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}

Set-PSReadLineKeyHandler -Key Ctrl+Spacebar -ScriptBlock {

    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()

    Invoke-CommandPalette

    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}

$ProfileScriptDirs = @(
    "$PSScriptRoot\aliases-keybinds",
    "$PSScriptRoot\completions",
    "$PSScriptRoot\scripts-functions"
)

foreach ($dir in $ProfileScriptDirs) {

    if (Test-Path $dir) {

        Get-ChildItem -Path $dir -Filter *.ps1 -File |
            ForEach-Object {
                . $_.FullName
            }
    }
}

Write-Host "⚡ Ctrl+f File Search | Alt+Space Smart Jump | Ctrl+y Yazi | Ctrl+Space Command Palette" `
    -ForegroundColor DarkGray


