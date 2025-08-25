# Prompt
Import-Module posh-git
oh-my-posh init pwsh --config ~/.config/powershell/minitancy.omp.json | Invoke-Expression

# ons
Import-Module Terminal-Icons

# Alias
Set-Alias grep rg 
Set-Alias touch ni
Set-Alias vim nvim

# Variables
Set-Item -Path Env:\XDG_CONFIG_HOME -Value 'C:\Users\frank\.config'
Set-Item -Path Env:\LUA_PATH -Value 'C:\Users\frank\.config\nvim\?.lua;'
Set-Item -Path Env:\BAT_CONFIG_PATH -Value 'C:\Users\frank\.config\bat\bat.conf'
Set-Item -Path Env:\DOTREE_CONFIG -Value 'C:\Users\frank\.config\dotree\config.json'
$Env:KOMOREBI_CONFIG_HOME = 'C:\Users\frank\.config\komorebi'

# PSReadLine
Set-PSReadLineOption -Colors @{
  Command = 'red'
  Error = 'darkRed'
  Variable = 'darkYellow'
  Parameter = 'blue'
  Keyword = 'darkCyan'
  # InlinePrediction = 'darkYellow'
  Operator = 'darkYellow'
}

# Utilities

function make-link ($target, $link) {
    New-Item -Path $link -ItemType SymbolicLink -Value $target
}

function which ($command) {
    Get-Command -Name $command -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}

function home () {
    Set-Location $HOME
}

function yasb() {
    C:\Users\frank\.config\yasb\.venv\Scripts\activate.ps1
    python C:\Users\frank\.config\yasb\src\main.py
    deactivate
}

function refresh() {
  . $PROFILE
}
