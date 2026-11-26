<#
  Install the test-signed MSIX package for My Memories Album.
  Run this in an ELEVATED (Administrator) PowerShell:
      Right-click Terminal > "Run as administrator"
      cd C:\Dev\PhotoTidy\sandbox\msix\out
      .\install_test.ps1
#>
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 1. Import the test certificate
$cer = Join-Path $dir 'MyMemoriesAlbum_test.cer'
if (-not (Test-Path $cer)) { throw "Certificate not found: $cer" }
Write-Host 'Importing test certificate...' -ForegroundColor Cyan
Import-Certificate -FilePath $cer -CertStoreLocation Cert:\LocalMachine\TrustedPeople | Out-Null
Write-Host 'Certificate imported.' -ForegroundColor Green

# 2. Check if an existing MSIX install is present and remove it
$existing = Get-AppxPackage -Name '*MyMemoriesAlbum*' -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host 'Removing existing MSIX install...' -ForegroundColor Yellow
    $existing | Remove-AppxPackage
    Write-Host 'Removed.' -ForegroundColor Green
}

# 3. Install the test-signed MSIX
$msix = Join-Path $dir 'MyMemoriesAlbum_1.0.0.0_x64_testsigned.msix'
if (-not (Test-Path $msix)) { throw "MSIX not found: $msix" }
Write-Host 'Installing MSIX package...' -ForegroundColor Cyan
Add-AppxPackage -Path $msix
Write-Host 'Installed!' -ForegroundColor Green

# 4. Verify
$pkg = Get-AppxPackage -Name '*MyMemoriesAlbum*'
if ($pkg) {
    Write-Host ''
    Write-Host "Package: $($pkg.PackageFullName)" -ForegroundColor Green
    Write-Host "Install location: $($pkg.InstallLocation)" -ForegroundColor Green
    Write-Host "Status: $($pkg.Status)" -ForegroundColor Green
    Write-Host ''
    Write-Host 'Look for "My Memories Album" in the Start menu and try launching it.' -ForegroundColor Cyan
} else {
    Write-Host 'WARNING: Package not found after install!' -ForegroundColor Red
}
