# chocolateyInstall.ps1
#
# THIS FILE CONTAINS INTENTIONAL SECURITY ANTI-PATTERNS for demonstration.
# Each flaw is labelled with the Semgrep rule / pipeline check that detects it.
#
# This file is intentionally edited for the demo PR so the Chocolatey
# security workflow runs and uploads SARIF annotations.
#
# This script runs with ELEVATED PRIVILEGE (admin) when 'choco install' is called.

$ErrorActionPreference = 'Stop'

$packageName = 'example-package'
$toolsDir    = Split-Path -Parent $MyInvocation.MyCommand.Definition

# --- Primary binary installation ---
# INTENTIONAL FLAW: Install-ChocolateyPackage with missing checksum.
# The choco-integrity-check action validates that every external binary download
# has a corresponding SHA256 checksum. Without it, the binary could be swapped
# by a compromised CDN or MITM attack.
#
# A correct call would include:
#   checksum      = 'abc123...'
#   checksumType  = 'sha256'
$packageArgs = @{
    packageName    = $packageName
    unzipLocation  = $toolsDir
    fileType       = 'exe'
    url            = 'http://example.com/downloads/example-tool-2.1.0-x86.exe'
    url64bit       = 'http://example.com/downloads/example-tool-2.1.0-x64.exe'
    # checksum     = ''   # INTENTIONAL FLAW: checksum is commented out / missing
    # checksumType = 'sha256'
    silentArgs     = '/S'
    validExitCodes = @(0)
}

Install-ChocolateyPackage @packageArgs

# --- Supplementary tool download ---
# INTENTIONAL FLAW: Direct Invoke-WebRequest without checksum verification.
# Semgrep rule: choco-unverified-download
# Using Invoke-WebRequest instead of Chocolatey's built-in helpers bypasses
# Chocolatey's checksum enforcement entirely. There is no integrity check on
# what gets downloaded and executed here.
$supplementaryUrl  = 'http://example.com/tools/helper-util.exe'
$supplementaryDest = Join-Path $toolsDir 'helper-util.exe'
Invoke-WebRequest -Uri $supplementaryUrl -OutFile $supplementaryDest
& $supplementaryDest --setup --quiet

# --- PATH modification ---
# INTENTIONAL FLAW: Modifying system PATH without documentation or corresponding
# cleanup in the uninstall script.
# Semgrep rule: choco-path-modification-undocumented
# PATH changes should be documented and reversed in chocolateyUninstall.ps1.
$installPath = Join-Path $env:ProgramFiles 'ExampleTool'
Install-ChocolateyPath -PathToInstall $installPath -PathType 'Machine'

# --- Registry modification ---
# INTENTIONAL FLAW: Writing to the registry without documentation.
# Semgrep rule: choco-registry-write-undocumented
# Registry writes should be documented and may need cleanup on uninstall.
$registryKey  = 'HKLM:\SOFTWARE\ExampleTool'
$registryData = @{
    InstallPath = $installPath
    Version     = '2.1.0'
    # INTENTIONAL FLAW: Hardcoded internal URL / credential in a package that
    # might be published to the community repo.
    # Semgrep rule: choco-hardcoded-internal-url
    UpdateServer = 'https://internal-updates.corp.example.com/api/v2'
}

New-Item -Path $registryKey -Force | Out-Null
foreach ($entry in $registryData.GetEnumerator()) {
    Set-ItemProperty -Path $registryKey -Name $entry.Key -Value $entry.Value
}

Write-Host "$packageName installed successfully."
