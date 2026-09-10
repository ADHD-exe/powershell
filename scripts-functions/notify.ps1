# Toast + terminal-bell notification when a command finishes or fails.
# Bell triggers Windows Terminal's bellStyle (audible/window/taskbar) set in settings.json.

if (-not (Get-Module -ListAvailable -Name BurntToast)) {
    try {
        Set-PSRepository PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue

        Install-Module `
            -Name BurntToast `
            -Scope CurrentUser `
            -Force `
            -AllowClobber `
            -SkipPublisherCheck `
            -ErrorAction Stop
    }
    catch {
        Write-Warning "Couldn't install BurntToast: $($_.Exception.Message)"
    }
}

Import-Module BurntToast -ErrorAction SilentlyContinue

# Commands running at least this long trigger a notification when they finish.
$global:NotifyThresholdSeconds = 8

$global:NotifyIconPath = "$PSScriptRoot\pwsh-icon.png"

function global:Send-TaskNotification {
    param(
        [string]$Title = "Notification",
        [string]$Message = "Task complete"
    )

    [Console]::Out.Write([char]7)

    if (Get-Command New-BurntToastNotification -ErrorAction SilentlyContinue) {
        try {
            if (Test-Path $global:NotifyIconPath) {
                New-BurntToastNotification -Text $Title, $Message -AppLogo $global:NotifyIconPath
            }
            else {
                New-BurntToastNotification -Text $Title, $Message
            }
        }
        catch {}
    }
}

function notify {
    param(
        [Parameter(Position = 0)]
        [string]$Message = "Task complete"
    )

    Send-TaskNotification -Title "Notification" -Message $Message
}

if (Test-Path Function:\prompt) {
    $global:__PreNotifyPrompt = ${function:prompt}
}
else {
    $global:__PreNotifyPrompt = { "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) " }
}

function global:prompt {

    $commandSucceeded = $?
    $hist = Get-History -Count 1

    if ($hist -and $hist.Id -ne $global:__LastNotifiedHistoryId) {

        $duration = $hist.EndExecutionTime - $hist.StartExecutionTime
        $failed = -not $commandSucceeded

        if ($failed -or $duration.TotalSeconds -ge $global:NotifyThresholdSeconds) {

            $global:__LastNotifiedHistoryId = $hist.Id

            $cmdText = $hist.CommandLine
            if ($cmdText.Length -gt 60) {
                $cmdText = $cmdText.Substring(0, 57) + "..."
            }

            $title = if ($failed) { "Command failed" } else { "Command finished" }

            Send-TaskNotification -Title $title -Message "$cmdText ($([int]$duration.TotalSeconds)s)"
        }
    }

    & $global:__PreNotifyPrompt
}
