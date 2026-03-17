# 1. Define the font you want (e.g., CascadiaMono, FiraCode, JetBrainsMono)
$fontName = "CascadiaMono"
$tempPath = "$env:TEMP\NerdFontTemp"
$zipPath = "$tempPath\$fontName.zip"
$extractPath = "$tempPath\Extracted"

# 2. Create clean temp directories
if (Test-Path $tempPath) { Remove-Item $tempPath -Recurse -Force }
New-Item -ItemType Directory -Path $extractPath -Force | Out-Null

# 3. Download the font zip directly from GitHub releases
$url = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/$fontName.zip"
Write-Host "Downloading $fontName Nerd Font from GitHub..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $url -OutFile $zipPath

# 4. Extract font files
Write-Host "Extracting files..." -ForegroundColor Cyan
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

# 5. Install fonts to Windows Fonts folder and Registry
$shellApp = New-Object -ComObject Shell.Application
$sourceFolder = $shellApp.Namespace($extractPath)
$fontsFolder = $shellApp.Namespace(0x14) # 0x14 is the shell folder for Fonts

# Filter for font files and pass the collection to the Shell's CopyHere method
$fontsFolder.CopyHere(($sourceFolder.Items() | Where-Object { $_.Name -match '\.(ttf|otf)$' }), 0x10)

# 6. Cleanup
Remove-Item $tempPath -Recurse -Force
Write-Host "Installation Complete! Please restart your terminal." -ForegroundColor Magenta
