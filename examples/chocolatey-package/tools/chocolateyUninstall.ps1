# chocolateyUninstall.ps1

$ErrorActionPreference = 'Stop'

$packageName = 'example-package'
$toolsDir    = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Uninstall the primary binary
$uninstallArgs = @{
    packageName    = $packageName
    fileType       = 'exe'
    silentArgs     = '/S'
    file           = Join-Path $env:ProgramFiles 'ExampleTool\uninstall.exe'
    validExitCodes = @(0)
}

Uninstall-ChocolateyPackage @uninstallArgs

# Clean up registry key created during install
$registryKey = 'HKLM:\SOFTWARE\ExampleTool'
if (Test-Path $registryKey) {
    Remove-Item -Path $registryKey -Recurse -Force
}

# NOTE: The PATH modification made in chocolateyInstall.ps1 is NOT reversed here.
# This is an intentional omission to demonstrate the undocumented PATH modification
# anti-pattern: the install adds to PATH, but the uninstall doesn't clean it up.

Write-Host "$packageName uninstalled."
