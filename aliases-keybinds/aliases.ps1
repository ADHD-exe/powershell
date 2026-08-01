# =========================================================
# Rabbit Aliases
# =========================================================

Set-Alias oc opencode
Set-Alias c clear
Set-Alias cls clear

Set-Alias vim nvim
Set-Alias v nvim

Set-Alias y yy

Set-Alias ls ll

Set-Alias reload Reload-Profile
Set-Alias profile Edit-Profile

Set-Alias rsex Restart-Explorer


Set-Alias grep Select-String
Set-Alias ai opencode

if (Get-Command eza -ErrorAction SilentlyContinue) {
    Set-Alias ls eza
}

if (Get-Command bat -ErrorAction SilentlyContinue) {
    Set-Alias cat bat
}

Set-Alias ep Edit-Profile