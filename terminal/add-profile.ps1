$fragmentPath = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\Fragments\User"
if (!(Test-Path $fragmentPath)) { New-Item -ItemType Directory -Path $fragmentPath }

# Copy your profile from your dotfiles repo to the fragments folder
Copy-Item "./archlinux-profile.json" -Destination "$fragmentPath\archlinux-profile.json"
