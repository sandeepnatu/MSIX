<#
  build_msix.ps1 - builds the Microsoft Store package (.msix) for My Memories Album.

  SOURCE OF TRUTH = the INSTALLED copy (default: %LOCALAPPDATA%\Programs\My Memories Album).
  The sandbox\payload folder is NOT used (it is out of date).

  Rehearsal with placeholder identity (cannot be uploaded to the Store):
      .\build_msix.ps1 -TestSign

  Real Store build, after the name is reserved (copy the three values from Partner Center,
  Product management > Product identity):
      .\build_msix.ps1 -IdentityName "<Package/Identity/Name>" `
                       -Publisher "<Package/Identity/Publisher, e.g. CN=...>" `
                       -PublisherDisplayName "<Publisher display name>"

  Output (in .\out):
      MyMemoriesAlbum_<version>_x64.msix              unsigned - THIS is the one to upload (the Store signs it)
      MyMemoriesAlbum_<version>_x64_testsigned.msix   only with -TestSign - for trying it on this PC
#>
[CmdletBinding()]
param(
    [string]$IdentityName = 'PLACEHOLDER.MyMemoriesAlbum',
    [string]$Publisher = 'CN=PLACEHOLDER',
    [string]$PublisherDisplayName = 'Scan My Memories',
    [string]$Version = '1.0.0.0',
    [string]$Source = (Join-Path $env:LOCALAPPDATA 'Programs\My Memories Album'),
    [string]$OutDir = (Join-Path $PSScriptRoot 'out'),
    [switch]$ExcludeModels,
    [switch]$TestSign
)
$ErrorActionPreference = 'Stop'

function Say($m) { Write-Host $m -ForegroundColor Cyan }
function Warn($m) { Write-Host $m -ForegroundColor Yellow }

# ---- 1. Check the source ----------------------------------------------------------------
foreach ($f in 'python\pythonw.exe', 'app\app.py', 'app\MyMemoriesAlbum.pyw', 'app\bundled.flag', 'MyMemoriesAlbum.ico') {
    if (-not (Test-Path (Join-Path $Source $f))) { throw "Source is missing '$f' : $Source" }
}
if ($Version -notmatch '^\d+\.\d+\.\d+\.0$') {
    Warn "Version '$Version' does not end in .0 - the Store reserves the last number; use e.g. 1.0.0.0"
}
$placeholder = ($IdentityName -like 'PLACEHOLDER*') -or ($Publisher -eq 'CN=PLACEHOLDER')
if ($placeholder) { Warn 'Identity values are PLACEHOLDERS: this build is for rehearsal only and the Store will reject it.' }

# ---- 2. Find the SDK tools ---------------------------------------------------------------
function Find-SdkTool($name) {
    $c = Get-Command $name -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $roots = @("${env:ProgramFiles(x86)}\Windows Kits\10\bin", "$env:ProgramFiles\Windows Kits\10\bin")
    foreach ($r in $roots) {
        if (Test-Path $r) {
            $hit = Get-ChildItem $r -Recurse -Filter $name -ErrorAction SilentlyContinue |
                   Where-Object { $_.FullName -match '\\x64\\' } |
                   Sort-Object FullName -Descending | Select-Object -First 1
            if ($hit) { return $hit.FullName }
        }
    }
    return $null
}
$makeappx = Find-SdkTool 'makeappx.exe'
if (-not $makeappx) { throw 'makeappx.exe not found. Install the Windows 10/11 SDK (the "Windows SDK Signing Tools for Desktop Apps" and "MSIX Packaging" parts are enough), then run this again.' }
Say "makeappx: $makeappx"

# ---- 3. Stage a clean copy ---------------------------------------------------------------
$stage = Join-Path $OutDir 'stage'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage -Force | Out-Null

Say 'Copying the installed app (this takes a minute)...'
$xd = @('_backup_before_folder_groups')
$xf = @('app-backup*.py', 'faces-backup*.py', 'index-backup*.html', 'index-defect*.html', 'index-stable*.html',
        'simulate_trial_expired.py', 'changelog*', 'unins000.*', 'Scan My Memories website.url', 'install_cryptography.py',
        '*.pyc')
if ($ExcludeModels) { $xf += '*.onnx' }
# *.pyc is skipped everywhere: the package folder is read-only, Python simply recompiles in memory.
& robocopy $Source $stage /E /NFL /NDL /NJH /NJS /NP /XD $xd /XF $xf | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed with code $LASTEXITCODE" }

# ---- 4. Logos from the app icon (uses the bundled Python + Pillow) -----------------------
Say 'Making logos...'
$assets = Join-Path $stage 'Assets'
& (Join-Path $stage 'python\python.exe') -I (Join-Path $PSScriptRoot 'make_assets.py') (Join-Path $stage 'MyMemoriesAlbum.ico') $assets
if ($LASTEXITCODE -ne 0) { throw 'Logo creation failed' }

# ---- 5. Manifest -------------------------------------------------------------------------
Say 'Writing manifest...'
function Esc($s) { [System.Security.SecurityElement]::Escape($s) }
$m = Get-Content (Join-Path $PSScriptRoot 'AppxManifest.template.xml') -Raw -Encoding UTF8
$m = $m.Replace('{{IDENTITY_NAME}}', (Esc $IdentityName))
$m = $m.Replace('{{PUBLISHER}}', (Esc $Publisher))
$m = $m.Replace('{{PUBLISHER_DISPLAY}}', (Esc $PublisherDisplayName))
$m = $m.Replace('{{VERSION}}', $Version)
$check = New-Object System.Xml.XmlDocument
$check.LoadXml($m)   # throws if the XML is broken
[System.IO.File]::WriteAllText((Join-Path $stage 'AppxManifest.xml'), $m, (New-Object System.Text.UTF8Encoding($false)))

# ---- 6. Pack -----------------------------------------------------------------------------
$msix = Join-Path $OutDir "MyMemoriesAlbum_${Version}_x64.msix"
if (Test-Path $msix) { Remove-Item $msix -Force }
Say 'Packing...'
& $makeappx pack /d $stage /p $msix /o
if ($LASTEXITCODE -ne 0) { throw "makeappx failed with code $LASTEXITCODE" }
Say ("Created: {0}  ({1:N0} MB)" -f $msix, ((Get-Item $msix).Length / 1MB))

# ---- 7. Optional test signing (self-signed; only for trying the package on this PC) ------
if ($TestSign) {
    $signtool = Find-SdkTool 'signtool.exe'
    if (-not $signtool) { throw 'signtool.exe not found (part of the Windows SDK).' }
    $cert = New-SelfSignedCertificate -Type Custom -Subject $Publisher -KeyUsage DigitalSignature `
        -FriendlyName 'My Memories Album test certificate' -CertStoreLocation 'Cert:\CurrentUser\My' `
        -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3', '2.5.29.19={text}')
    $cer = Join-Path $OutDir 'MyMemoriesAlbum_test.cer'
    Export-Certificate -Cert $cert -FilePath $cer | Out-Null
    $signed = Join-Path $OutDir "MyMemoriesAlbum_${Version}_x64_testsigned.msix"
    Copy-Item $msix $signed -Force
    & $signtool sign /fd SHA256 /sha1 $cert.Thumbprint $signed
    if ($LASTEXITCODE -ne 0) { throw "signtool failed with code $LASTEXITCODE" }
    Say "Test copy: $signed"
    Write-Host @"

To try it on this PC (PowerShell as Administrator, once):
    Import-Certificate -FilePath "$cer" -CertStoreLocation Cert:\LocalMachine\TrustedPeople
Then double-click the _testsigned.msix (or: Add-AppxPackage "$signed").
Remove it later with:  Get-AppxPackage *MyMemoriesAlbum* | Remove-AppxPackage
"@
}

Write-Host ''
if ($placeholder) { Warn 'Rehearsal build done. Build again with the real Partner Center values before uploading.' }
else { Say "Upload this file in Partner Center > Packages:  $msix" }
