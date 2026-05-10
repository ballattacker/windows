# 1. Define paths
$installDir = "$env:ProgramFiles\dual-key-remap"
$startupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$zipFile = "$env:TEMP\dual-key-remap.zip"
$repoUrl = "https://api.github.com/repos/ililim/dual-key-remap/releases/latest"

# 2. Ensure script is running as Admin to write to Program Files
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Please run this script as Administrator."
    return
}

# 3. Get the latest download URL from GitHub API
Write-Host "Fetching latest release info..." -ForegroundColor Cyan
$releaseInfo = Invoke-RestMethod -Uri $repoUrl
$downloadUrl = $releaseInfo.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -ExpandProperty browser_download_url

# 4. Download and Extract
Write-Host "Downloading dual-key-remap..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile
New-Item -ItemType Directory -Force -Path $installDir | Out-Null
Expand-Archive -Path $zipFile -DestinationPath $installDir -Force

# 5. Create default config (CapsLock -> Escape/Ctrl)
# $configContent = @"
# remap_key=CAPSLOCK
# when_alone=ESCAPE
# with_other=CTRL
# "@
# $configContent | Out-File -FilePath "$installDir\config.txt" -Encoding ascii

# 6. Create Startup Shortcut
Write-Host "Setting up startup shortcut..." -ForegroundColor Cyan
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$startupFolder\dual-key-remap.lnk")
$Shortcut.TargetPath = "$installDir\dual-key-remap.exe"
$Shortcut.WorkingDirectory = $installDir
$Shortcut.Save()

# 7. Start the application
Write-Host "Starting dual-key-remap..." -ForegroundColor Cyan
Start-Process -FilePath "$installDir\dual-key-remap.exe" -WorkingDirectory $installDir

Write-Host "Successfully installed to $installDir" -ForegroundColor Green
Write-Host "CapsLock is now remapped! Edit config.txt in the install folder to change settings."

