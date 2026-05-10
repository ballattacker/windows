<#
.SYNOPSIS
    Installs and registers Nerd Fonts on Windows.
.DESCRIPTION
    Downloads, extracts, copies, and registers Nerd Fonts. 
    Defaults to SYSTEM-WIDE installation (requires Admin).
    Use -UserOnly for per-user install, or -Font to specify fonts non-interactively.
.PARAMETER Font
    Array of font package names to install (e.g., 'FiraCode', 'JetBrainsMono'). 
    Partial matches supported. Omit to enter interactive mode.
.PARAMETER UserOnly
    Overrides default and installs for the current user only (no admin required).
.PARAMETER ListAvailable
    Lists all available font packages and exits.
.EXAMPLE
    .\Install-NerdFonts.ps1 -Font FiraCode, Hack
.EXAMPLE
    .\Install-NerdFonts.ps1 -UserOnly
.EXAMPLE
    .\Install-NerdFonts.ps1 -ListAvailable
#>

[CmdletBinding()]
param(
    [string[]]$Font,
    [switch]$UserOnly,
    [switch]$ListAvailable
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "Stop"

# --- Configuration ---
$isSystemWide = -not $UserOnly.IsPresent
if ($isSystemWide) {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "System-wide installation requires Administrator privileges. Run PowerShell as Administrator or add -UserOnly."
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

Write-Host "Fetching latest Nerd Fonts release from GitHub..." -ForegroundColor Cyan
try {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" -Headers @{"Accept"="application/vnd.github.v3+json"}
} catch {
    Write-Error "Failed to fetch release data. Check internet or GitHub API rate limits. Error: $_"
    exit 1
}

$allFontZips = $release.assets | Where-Object { $_.name -like "*.zip" -and $_.name -notmatch "complete" } | Sort-Object name

if ($allFontZips.Count -eq 0) {
    Write-Error "No font packages found in the latest release."
    exit 1
}

# --- List Available & Exit ---
if ($ListAvailable) {
    Write-Host "`nAvailable Nerd Fonts packages:" -ForegroundColor Yellow
    $allFontZips | ForEach-Object { Write-Host "  - $($_.name)" }
    exit 0
}

# --- Select Fonts ---
$selectedZips = @()
if ($Font) {
    foreach ($name in $Font) {
        $match = $allFontZips | Where-Object { $_.name -like "*$name*" } | Select-Object -First 1
        if ($match) {
            $selectedZips += $match
        } else {
            Write-Warning "No package matching '$name' found. Skipping."
        }
    }
    if ($selectedZips.Count -eq 0) {
        Write-Error "No valid fonts selected. Use -ListAvailable to see options."
        exit 1
    }
} else {
    # Interactive fallback
    Write-Host "`nAvailable Nerd Fonts packages:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $allFontZips.Count; $i++) {
        Write-Host "  [$i] $($allFontZips[$i].name)"
    }
    Write-Host "`nSelect font(s) (comma-separated indices, or 'a' for all):" -ForegroundColor Yellow
    $selection = Read-Host

    if ($selection -eq "a") {
        $selectedZips = $allFontZips
    } else {
        $indices = $selection -split "," | ForEach-Object { $_.Trim() }
        foreach ($idx in $indices) {
            if ($idx -match "^\d+$" -and [int]$idx -lt $allFontZips.Count) {
                $selectedZips += $allFontZips[[int]$idx]
            }
        }
    }
    if ($selectedZips.Count -eq 0) {
        Write-Error "Invalid selection. Exiting."
        exit 1
    }
}

# --- Installation Loop ---
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
            
            if (-not (Test-Path $dest)) {
                Copy-Item -Path $font.FullName -Destination $dest -Force
                
                # Register font in Windows registry (standard format)
                $regKey = "$($font.BaseName) (TrueType)"
                New-ItemProperty -Path $regPath -Name $regKey -Value $font.Name -PropertyType String -Force | Out-Null
                Write-Host "  [OK] Installed & registered: $($font.Name)"
            } else {
                Write-Host "  [SKIP] Already exists: $($font.Name)"
            }
        }
    }
    
    Write-Host "`n[SUCCESS] Installation complete!" -ForegroundColor Green
    Write-Host "[NEXT] Restart Windows Terminal, VS Code, or your IDE. If fonts still don't appear, reboot or clear the font cache." -ForegroundColor Yellow
} catch {
    Write-Error "[ERROR] Installation failed: $_"
} finally {
    if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force }
}