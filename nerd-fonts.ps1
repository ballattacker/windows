<#
.SYNOPSIS
    Installs and REGISTERs Nerd Fonts on Windows (with registry entries).
.DESCRIPTION
    Downloads, extracts, copies fonts, AND adds registry entries so Windows/apps can see them.
    Supports per-user (default) or system-wide (-SystemWide) installation.
.EXAMPLE
    .\Install-NerdFonts.ps1
.EXAMPLE
    .\Install-NerdFonts.ps1 -SystemWide
#>

[CmdletBinding()]
param(
    [switch]$SystemWide
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "Stop"

# --- Configuration ---
if ($SystemWide) {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "System-wide installation requires Administrator. Run PowerShell as Admin or omit -SystemWide."
        exit 1
    }
    $fontDir = "$env:SystemRoot\Fonts"
    $regPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
} else {
    $fontDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    $regPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
}

if (-not (Test-Path $fontDir)) { New-Item -ItemType Directory -Path $fontDir -Force | Out-Null }
if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }

Write-Host "Fetching latest Nerd Fonts release..." -ForegroundColor Cyan
try {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" -Headers @{"Accept"="application/vnd.github.v3+json"}
} catch {
    Write-Error "Failed to fetch release: $_"
    exit 1
}

$fontZips = $release.assets | Where-Object { $_.name -like "*.zip" -and $_.name -notmatch "complete" } | Sort-Object name
if ($fontZips.Count -eq 0) { Write-Error "No font packages found."; exit 1 }

# --- Font Selection ---
Write-Host "`nAvailable packages:" -ForegroundColor Yellow
for ($i = 0; $i -lt $fontZips.Count; $i++) { Write-Host "  [$i] $($fontZips[$i].name)" }
Write-Host "`nSelect (comma-separated indices, or 'a' for all):" -ForegroundColor Yellow
$selection = Read-Host

$selectedZips = @()
if ($selection -eq "a") { $selectedZips = $fontZips }
else {
    $indices = $selection -split "," | ForEach-Object { $_.Trim() }
    foreach ($idx in $indices) {
        if ($idx -match "^\d+$" -and [int]$idx -lt $fontZips.Count) { $selectedZips += $fontZips[[int]$idx] }
    }
}
if ($selectedZips.Count -eq 0) { Write-Error "Invalid selection."; exit 1 }

# --- Install Loop ---
$tempDir = Join-Path $env:TEMP "NerdFonts_$(Get-Date -Format 'yyyyMMddHHmmss')"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    foreach ($zip in $selectedZips) {
        $zipPath = Join-Path $tempDir $zip.name
        Write-Host "`n[DOWNLOAD] $($zip.name)..." -ForegroundColor Green
        Invoke-WebRequest -Uri $zip.browser_download_url -OutFile $zipPath -UseBasicParsing

        $extractDir = Join-Path $tempDir ([System.IO.Path]::GetFileNameWithoutExtension($zip.name))
        if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
        Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

        $fonts = Get-ChildItem -Path $extractDir -Include "*.ttf", "*.otf" -Recurse
        foreach ($font in $fonts) {
            $dest = Join-Path $fontDir $font.Name
            $regName = if ($SystemWide) { $font.Name } else { "$fontDir\$($font.Name)" }
            
            if (-not (Test-Path $dest)) {
                Copy-Item -Path $font.FullName -Destination $dest -Force
                # Register font in Windows registry
                New-ItemProperty -Path $regPath -Name $regName -Value $font.Name -PropertyType String -Force | Out-Null
                Write-Host "  [OK] Installed & registered: $($font.Name)"
            } else {
                Write-Host "  [SKIP] Exists: $($font.Name)"
            }
        }
    }
    
    Write-Host "`n[SUCCESS] Done!" -ForegroundColor Green
    Write-Host "[TIP] Restart Windows Terminal/VS Code. If fonts still missing, run: 'sfc /scannow' or reboot." -ForegroundColor Yellow
} catch {
    Write-Error "[ERROR] $_"
} finally {
    if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force }
}