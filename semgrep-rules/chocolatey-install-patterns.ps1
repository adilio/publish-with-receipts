# Semgrep test fixtures for chocolatey-install-patterns.yml
#
# This file is used by `semgrep --test semgrep-rules/` to validate that each
# rule matches what it should and does not match what it should not.
#
# Reference: https://semgrep.dev/docs/writing-rules/testing-rules/

# =============================================================================
# choco-unverified-download
# =============================================================================

# ruleid: choco-unverified-download
Invoke-WebRequest -Uri "https://example.com/file.exe" -OutFile $dest

# ruleid: choco-unverified-download
Invoke-WebRequest -Uri $downloadUrl -OutFile $localFile

# ruleid: choco-unverified-download
IWR -Uri $downloadUrl -OutFile $localFile

# ok: choco-unverified-download
$packageArgs = @{
    url      = "https://example.com/file.exe"
    checksum = "abc123"
}
Install-ChocolateyPackage @packageArgs

# =============================================================================
# choco-path-modification-undocumented
# =============================================================================

# ruleid: choco-path-modification-undocumented
Install-ChocolateyPath -PathToInstall $installDir -PathType 'Machine'

# ruleid: choco-path-modification-undocumented
Install-ChocolateyPath $toolsDir 'User'

# =============================================================================
# choco-registry-write-undocumented
# =============================================================================

# ruleid: choco-registry-write-undocumented
New-Item -Path "HKLM:\SOFTWARE\MyApp" -Force

# ruleid: choco-registry-write-undocumented
Set-ItemProperty -Path "HKLM:\SOFTWARE\MyApp" -Name "Version" -Value "1.0"

# ruleid: choco-registry-write-undocumented
New-ItemProperty -Path "HKLM:\SOFTWARE\MyApp" -Name "Install" -Value 1

# =============================================================================
# choco-hardcoded-internal-url
# =============================================================================

# ruleid: choco-hardcoded-internal-url
$updateEndpoint = "https://internal-updates.corp.example.com/api/v2"

# ruleid: choco-hardcoded-internal-url
$shareSource = "\\corp.example.com\packages"

# =============================================================================
# choco-weak-checksum-algorithm
# =============================================================================

# ruleid: choco-weak-checksum-algorithm
checksumType = "md5"

# ruleid: choco-weak-checksum-algorithm
checksumType = "sha1"

# ruleid: choco-weak-checksum-algorithm
ChecksumType = "md5"

# ok: choco-weak-checksum-algorithm
checksumType = "sha256"

# ok: choco-weak-checksum-algorithm
checksumType = "sha512"

# =============================================================================
# choco-scheduled-task-undocumented
# =============================================================================

# ruleid: choco-scheduled-task-undocumented
Register-ScheduledTask -TaskName "MyTask" -Action $action -Trigger $trigger

# ruleid: choco-scheduled-task-undocumented
New-ScheduledTask -Action $action -Trigger $trigger

# =============================================================================
# choco-service-install-no-cleanup
# =============================================================================

# ruleid: choco-service-install-no-cleanup
New-Service -Name "MyService" -BinaryPathName $exePath

# =============================================================================
# nuspec-unpinned-dependency (XML pattern — generic language)
# =============================================================================

# ruleid: nuspec-unpinned-dependency
<dependency id="chocolatey-core.extension" />

# ruleid: nuspec-unpinned-dependency
<dependency id='dotnet-runtime' />
