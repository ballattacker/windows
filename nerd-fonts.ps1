# 1. Install the NerdFonts management module if not present
if (!(Get-Module -ListAvailable -Name NerdFonts)) {
    Write-Host "Installing NerdFonts helper module..." -ForegroundColor Cyan
    Install-Module -Name NerdFonts -Scope CurrentUser -Force
}

# 2. Install Cascadia Code Nerd Font (CaskaydiaCove)
# Note: In the Nerd Fonts project, the "Cascadia Code" patch is named "CaskaydiaCove"
Write-Host "Downloading and installing Cascadia Code Nerd Font..." -ForegroundColor Cyan
Install-NerdFont -Name "CaskaydiaCove"

Write-Host "Successfully installed! You can now select 'CaskaydiaCove Nerd Font' in Terminal settings." -ForegroundColor Green

Write-Host "Downloading and installing Cascadia Mono Nerd Font..." -ForegroundColor Cyan
Install-NerdFont -Name "CaskaydiaMono"

Write-Host "Successfully installed! You can now select 'CaskaydiaMono Nerd Font' in Terminal settings." -ForegroundColor Green
