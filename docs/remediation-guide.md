# Remediation Guide

This guide explains how to fix every finding type that the `publish-with-receipts` pipeline can surface. Each section maps to a specific tool or Semgrep rule and provides copy-paste remediation patterns.

---

## Contents

1. [PSScriptAnalyzer findings](#psscriptanalyzer-findings)
2. [Semgrep — PowerShell rules](#semgrep--powershell-rules)
3. [Semgrep — Chocolatey rules](#semgrep--chocolatey-rules)
4. [Dependency pin check](#dependency-pin-check)
5. [Grype vulnerability scan](#grype-vulnerability-scan)
6. [Provenance and SBOM](#provenance-and-sbom)
7. [Suppressing false positives](#suppressing-false-positives)

---

## PSScriptAnalyzer findings

PSScriptAnalyzer reports findings against the [PowerShell Best Practices and Style Guide](https://poshcode.gitbook.io/powershell-practice-and-style/). Findings appear in the **Security → Code Scanning** tab as PR annotations.

### PSAvoidUsingWriteHost

**Problem:** `Write-Host` cannot be redirected and bypasses the PowerShell pipeline.

**Fix:** Replace `Write-Host` with `Write-Verbose`, `Write-Output`, or `Write-Information`:

```powershell
# Before
Write-Host "Processing $item"

# After
Write-Verbose "Processing $item"
```

### PSUseShouldProcessForStateChangingFunctions

**Problem:** A function that changes state (verb: `Set-`, `New-`, `Remove-`) does not support `-WhatIf`/`-Confirm`.

**Fix:** Add `[CmdletBinding(SupportsShouldProcess)]` and wrap the state-changing operation:

```powershell
function Remove-MyResource {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Name)

    if ($PSCmdlet.ShouldProcess($Name, 'Remove resource')) {
        # actual removal here
    }
}
```

### PSAvoidUsingPlainTextForPassword

**Problem:** A parameter named `Password`, `Credential`, etc. is typed as `[string]`.

**Fix:** Use `[SecureString]` or `[PSCredential]`:

```powershell
# Before
param([string]$Password)

# After
param([SecureString]$Password)
# or
param([PSCredential]$Credential)
```

### PSAvoidUsingConvertToSecureStringWithPlainText

**Problem:** `ConvertTo-SecureString` is called with `-AsPlainText -Force`, which defeats its purpose.

**Fix:** Accept a `[SecureString]` directly, or read the value from a secrets manager:

```powershell
# Before
$secure = ConvertTo-SecureString "mysecret" -AsPlainText -Force

# After — read from environment (set via GitHub Actions secrets)
$secure = ConvertTo-SecureString $env:MY_SECRET -AsPlainText -Force
# Better — prompt at runtime
$secure = Read-Host "Enter password" -AsSecureString
```

### PSUseDeclaredVarsMoreThanAssignments

**Problem:** A variable is assigned but never read (dead code).

**Fix:** Remove the assignment, or use the variable where intended. If the assignment is intentional (e.g., capturing pipeline output to discard it), use `$null`:

```powershell
$null = Some-CommandWithOutput  # explicitly discard
```

---

## Semgrep — PowerShell rules

### `powershell-download-execute`

**Severity:** ERROR — CWE-494

**What it caught:** A script fetches remote content (`Invoke-WebRequest` / `Invoke-RestMethod`) and passes it directly to `Invoke-Expression`.

**Why it's dangerous:** Any entity that controls the remote endpoint (compromised server, CDN, DNS hijack, MITM) can execute arbitrary code in the caller's context.

**Fix:** Never execute remote content without verification. Options in order of preference:

```powershell
# Option 1: Use a local, version-pinned script instead of a remote one.
# Commit the script to your repository and reference it by relative path.
. ./scripts/Initialize-Environment.ps1

# Option 2: If a remote script is unavoidable, download it, hash it,
# compare to a known-good SHA256, THEN execute.
$destPath = Join-Path $env:TEMP "setup-$(New-Guid).ps1"
Invoke-WebRequest -Uri $url -OutFile $destPath -UseBasicParsing

$expectedHash = 'a1b2c3d4...'   # SHA256 from a trusted source (e.g., GitHub release notes)
$actualHash   = (Get-FileHash $destPath -Algorithm SHA256).Hash
if ($actualHash -ne $expectedHash) {
    Remove-Item $destPath -Force
    throw "Script hash mismatch. Expected: $expectedHash  Got: $actualHash"
}
& $destPath
Remove-Item $destPath -Force
```

### `powershell-hardcoded-secret`

**Severity:** ERROR — CWE-798

**What it caught:** An API key, token, password, or connection string is assigned as a string literal in source code.

**Fix:** Use environment variables injected by your CI/CD platform:

```powershell
# Before
$ApiKey = "sk-live-abc123..."

# After — environment variable (set in GitHub Actions secrets)
$ApiKey = $env:MY_SERVICE_API_KEY
if (-not $ApiKey) { throw "MY_SERVICE_API_KEY is not set." }
```

For Azure environments, use Key Vault:

```powershell
$ApiKey = (Get-AzKeyVaultSecret -VaultName 'my-vault' -Name 'api-key').SecretValueText
```

GitHub Actions secret setup:

```yaml
# In your workflow:
env:
  MY_SERVICE_API_KEY: ${{ secrets.MY_SERVICE_API_KEY }}
```

### `powershell-disable-certificate-validation`

**Severity:** ERROR — CWE-295

**What it caught:** `[System.Net.ServicePointManager]::ServerCertificateValidationCallback` is set to always return `$true`, disabling TLS verification for the entire PowerShell session.

**Fix:** Remove the override and fix the underlying certificate issue:

```powershell
# REMOVE this:
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# If using a self-signed cert in a dev environment, instead:
# - Add the cert to the trusted root store on the machine
# - Use -SkipCertificateCheck on Invoke-WebRequest (PS 6+, scoped to that one call)
Invoke-WebRequest -Uri $url -SkipCertificateCheck   # only for specific dev scenarios
```

### `powershell-encoded-command`

**Severity:** WARNING — CWE-116

**What it caught:** A `-EncodedCommand` argument or `[Convert]::FromBase64String` + `Invoke-Expression` is used to run obfuscated code.

**Fix:** Use plain text scripts. If passing complex arguments to a child `pwsh` process is the goal, use `-Command` with proper escaping or a script file:

```powershell
# Instead of base64-encoded command, use a script file:
$args = @('-NonInteractive', '-File', './scripts/do-thing.ps1', '-Param', 'value')
& pwsh @args
```

If the encoded command was generated for legitimate cross-platform argument escaping (e.g., by `Start-Job` or Azure Automation), add a comment explaining the origin:

```powershell
# semgrep:ignore powershell-encoded-command
# Generated by Azure Automation DSC configuration compiler — not hand-crafted obfuscation.
& pwsh.exe -EncodedCommand $generatedBase64
```

### `powershell-unpinned-required-module`

**Severity:** WARNING — CWE-1104

**What it caught:** `RequiredModules` in a `.psd1` manifest lists a bare module name with no version constraint.

**Fix:** Add exact version pins using `RequiredVersion`:

```powershell
# Before — floating
RequiredModules = @('Az.Accounts', 'Az.Storage')

# After — pinned to exact versions
RequiredModules = @(
    @{ ModuleName = 'Az.Accounts'; RequiredVersion = '2.13.2' }
    @{ ModuleName = 'Az.Storage';  RequiredVersion = '5.10.1' }
)
```

To find the current version of an installed module:

```powershell
(Get-Module Az.Accounts -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version
```

### `powershell-add-type-dynamic`

**Severity:** WARNING — CWE-95

**What it caught:** `Add-Type -TypeDefinition` is called with a variable, meaning C# code is compiled at runtime from a potentially mutable string.

**Fix:** Use a literal here-string for the C# source:

```powershell
# Before — dynamic (risk if $csharpCode is tainted)
Add-Type -TypeDefinition $csharpCode

# After — literal, version-controlled source
Add-Type -TypeDefinition @'
using System;
public class MyHelper {
    public static string Greet(string name) => $"Hello, {name}";
}
'@
```

If the C# source genuinely varies at runtime, validate it strictly before compiling.

### `powershell-assembly-load-dynamic`

**Severity:** WARNING — CWE-114

**What it caught:** An assembly is loaded from a variable path, which can be a DLL planting vector if the path is writable by non-admin users.

**Fix:** Load assemblies from paths that are:
1. Under your module's own directory (`$PSScriptRoot`)
2. Verified against a known hash before loading

```powershell
# Verify before loading
$dllPath = Join-Path $PSScriptRoot 'lib/MyDependency.dll'
$expectedHash = 'sha256:abc123...'
$actualHash   = "sha256:$((Get-FileHash $dllPath -Algorithm SHA256).Hash.ToLower())"

if ($actualHash -ne $expectedHash) {
    throw "DLL hash mismatch for $dllPath"
}
[System.Reflection.Assembly]::LoadFrom($dllPath) | Out-Null
```

---

## Semgrep — Chocolatey rules

### `choco-unverified-download`

**Severity:** ERROR — CWE-494

**What it caught:** `Invoke-WebRequest -OutFile` is used directly in a Chocolatey install script instead of the built-in helpers that enforce checksum verification.

**Fix:** Replace with `Install-ChocolateyPackage` or `Get-ChocolateyWebFile` with a SHA256 checksum:

```powershell
# Before
Invoke-WebRequest -Uri $url -OutFile $toolsDir\myapp.exe

# After
$packageArgs = @{
    packageName   = $env:ChocolateyPackageName
    fileType      = 'EXE'
    url           = 'https://example.com/myapp-1.2.3-x86.exe'
    url64bit      = 'https://example.com/myapp-1.2.3-x64.exe'
    checksum      = 'a1b2c3d4e5f6...'  # SHA256 of the x86 binary
    checksum64    = 'f6e5d4c3b2a1...'  # SHA256 of the x64 binary
    checksumType  = 'sha256'
    checksumType64= 'sha256'
    silentArgs    = '/S'
    validExitCodes= @(0)
}
Install-ChocolateyPackage @packageArgs
```

### `choco-install-package-no-checksum`

**Severity:** ERROR — CWE-354

**What it caught:** `Install-ChocolateyPackage` is called without a `checksum` argument.

**Fix:** Add `checksum`, `checksumType`, and optionally `checksum64`/`checksumType64`:

```powershell
Install-ChocolateyPackage @{
    packageName  = $env:ChocolateyPackageName
    url          = $url
    checksum     = 'a1b2c3d4...'   # SHA256 — get from vendor release page
    checksumType = 'sha256'
}
```

To compute a SHA256 hash of a downloaded file:

```powershell
(Get-FileHash .\myapp.exe -Algorithm SHA256).Hash
```

### `choco-weak-checksum-algorithm`

**Severity:** ERROR — CWE-327

**What it caught:** `checksumType = 'md5'` or `checksumType = 'sha1'` is used. Both are computationally feasible to forge.

**Fix:** Change to `sha256`:

```powershell
# Before
checksumType = 'md5'

# After
checksumType = 'sha256'
# Then update the checksum value to match the SHA256 hash of the binary
```

### `choco-hardcoded-internal-url`

**Severity:** ERROR — CWE-615

**What it caught:** A hardcoded internal network URL or UNC path appears in a package that may be published externally.

**Fix:** Use Chocolatey package parameters to pass environment-specific values:

```powershell
# Before
$url = 'https://internal-builds.corp.example.com/myapp/1.2.3/myapp.exe'

# After — read from package parameters
$pp  = Get-PackageParameters
$url = $pp['SourceUrl']
if (-not $url) { throw "SourceUrl package parameter is required." }
```

Callers pass the parameter at install time:

```powershell
choco install mypackage --params "'/SourceUrl:https://internal-builds.corp.example.com/myapp/1.2.3/myapp.exe'"
```

For truly internal-only packages, document this in the `.nuspec` description and restrict distribution to your internal Chocolatey feed.

### `choco-path-modification-undocumented`

**Severity:** WARNING

**What it caught:** `Install-ChocolateyPath` is called, modifying the system or user PATH.

**Fix:** Document the PATH change in your package description and reverse it in `chocolateyUninstall.ps1`:

```powershell
# chocolateyInstall.ps1
Install-ChocolateyPath $toolsDir 'Machine'  # or 'User'

# chocolateyUninstall.ps1 — MUST have a matching removal
Uninstall-ChocolateyPath $toolsDir 'Machine'
```

### `choco-registry-write-undocumented`

**Severity:** WARNING

**What it caught:** A registry key is written under `HKLM:\` during install.

**Fix:** Reverse the registry change in the uninstall script:

```powershell
# chocolateyInstall.ps1
New-Item     -Path 'HKLM:\SOFTWARE\MyApp' -Force | Out-Null
Set-ItemProperty -Path 'HKLM:\SOFTWARE\MyApp' -Name 'InstallDir' -Value $toolsDir

# chocolateyUninstall.ps1
Remove-Item -Path 'HKLM:\SOFTWARE\MyApp' -Recurse -Force -ErrorAction SilentlyContinue
```

### `nuspec-unpinned-dependency`

**Severity:** WARNING — CWE-1104

**What it caught:** A `<dependency>` element in the `.nuspec` file has no `version` attribute.

**Fix:** Pin to an exact version or a bounded range:

```xml
<!-- Before — any version -->
<dependency id="chocolatey" />

<!-- After — exact pin (recommended for security) -->
<dependency id="chocolatey" version="[1.3.0]" />

<!-- After — bounded range (allows patch updates within the minor) -->
<dependency id="chocolatey" version="[1.3.0, 1.4.0)" />
```

NuGet version range notation:
- `[1.0]` — exactly version 1.0
- `[1.0, 2.0)` — ≥1.0 and <2.0
- `[1.0, 2.0]` — ≥1.0 and ≤2.0
- `1.0` — minimum 1.0 (floating — avoid for security-sensitive packages)

---

## Dependency pin check

The `dependency-pin-check` action surfaces floating dependencies at pipeline time. All findings from this action have remediations described above:

- **psd1 / `[HIGH]` no version constraint** → see [powershell-unpinned-required-module](#powershell-unpinned-required-module)
- **psd1 / `[MEDIUM]` ModuleVersion only** → add `MaximumVersion` or switch to `RequiredVersion`
- **nuspec / `[HIGH]` no version attribute** → see [nuspec-unpinned-dependency](#nuspec-unpinned-dependency)
- **nuspec / `[MEDIUM]` minimum-version constraint** → use `[x.y.z]` or bounded range

To enforce pinning (block the pipeline instead of surfacing findings):

```yaml
# In your workflow:
- uses: ./actions/dependency-pin-check
  with:
    fail-on-unpinned: 'true'   # change from 'false'
```

---

## Grype vulnerability scan

Grype reports CVEs found in the SBOM against NVD and the GitHub Advisory Database. Findings appear in Code Scanning and in the `grype-*.json` artifact.

### Interpreting severity levels

| Severity | Action |
|----------|--------|
| Critical | Remediate immediately. Block publish if `fail-on-severity: critical` is set. |
| High     | Remediate before next release. Consider blocking. |
| Medium   | Track and remediate in the next sprint. |
| Low/Negligible | Track; usually acceptable to carry. |

### Updating a dependency to fix a CVE

For PowerShell modules: update `RequiredVersion` in `RequiredModules`:

```powershell
@{ ModuleName = 'VulnerableModule'; RequiredVersion = '2.0.1' }  # fixed version
```

For Chocolatey packages: update the URL and recalculate the checksum:

```powershell
$url     = 'https://example.com/myapp-2.0.1.exe'  # updated URL
$checksum = 'new-sha256-hash...'                   # recalculate after downloading
```

### Suppressing a false positive

If Grype incorrectly flags a component (e.g., the CVE does not affect your usage, or the package name collision is a false match):

1. Verify the CVE does not apply to your package using the CVE details page.
2. Add an entry to a Grype ignore file (`.grype.yaml` in the repo root):

```yaml
# .grype.yaml
ignore:
  - vulnerability: CVE-2023-XXXXX
    reason: "This CVE affects only the web interface component, which is not included."
    fix-state: not-fixed   # or: fixed, won't-fix
```

Then reference the ignore file in the workflow:

```yaml
- uses: ./actions/vulnerability-scan
  with:
    sbom-path: my-sbom.cdx.json
    # Add to the vulnerability-scan action inputs if extended to support ignore files
```

### Setting enforcement thresholds

```yaml
- uses: ./actions/vulnerability-scan
  with:
    sbom-path: powershell-module-sbom.cdx.json
    fail-on-severity: 'critical'   # fail only on critical
    # fail-on-severity: 'high'     # fail on high+
    # fail-on-severity: ''         # never fail (surface only)
```

---

## Provenance and SBOM

### SBOM is empty or missing components

**Cause:** Syft may not recognise PowerShell module or Chocolatey package formats natively. This is expected — the SBOM captures file hashes even when component names cannot be resolved.

**What to do:** The file-level hashes in the SBOM are still valuable for integrity verification. For richer component data (e.g., NuGet package graph), consider supplementing with `cdxgen`:

```bash
cdxgen --type powershell ./examples/powershell-module -o powershell-sbom.cdx.json
```

### Provenance SHA256 does not match what I expect

**Cause:** The `provenance-generate` action hashes a directory by first creating a tar archive of it. The hash depends on file ordering, timestamps, and the tar implementation.

**What to do:** The primary purpose of the provenance hash is to tie a specific pipeline run to a specific version of the artifact. For reproducibility verification, run the same pipeline on the same commit and compare the hashes. Small differences in tar behaviour between platforms (Linux vs Windows) are expected for directory hashes.

For file-level hashes, use the SBOM `component.hashes` array — Syft hashes individual files using SHA256 and SHA1.

### Provenance verification

To verify a provenance document is authentic (not forged after the fact), the current SLSA v0.2 output from this pipeline is not cryptographically signed. To upgrade to a signed, verifiable attestation:

1. Replace `./actions/provenance-generate` with `slsa-framework/slsa-github-generator` (SLSA Level 2+).
2. Use `gh attestation verify` to verify artifacts against GitHub's Sigstore-backed attestation store.

See [enterprise-integration.md](./enterprise-integration.md) for more detail on attestation options.

---

## Suppressing false positives

Not every finding represents a real problem. When you've reviewed a finding and determined it's a false positive, suppress it inline with a justification comment so reviewers understand the decision.

### Semgrep suppressions

Add `# nosemgrep: <rule-id>` on the line before the flagged code:

```powershell
# nosemgrep: powershell-invoke-expression
# Justification: $scriptBlock is a locally-defined [scriptblock], not external input.
$result = Invoke-Expression $scriptBlock
```

To suppress multiple rules on a single line, separate rule IDs with commas:

```powershell
# nosemgrep: powershell-invoke-expression, powershell-download-execute
$result = Invoke-Expression $localBlock
```

To suppress for an entire file, add the comment at the top:

```powershell
# nosemgrep
# This file contains deliberately insecure patterns for testing purposes.
```

**Rule IDs** are the `id:` values in the YAML rule files:
- `powershell-download-execute`
- `powershell-hardcoded-secret`
- `powershell-invoke-expression`
- `powershell-encoded-command`
- `choco-unverified-download`
- etc. (see `semgrep-rules/*.yml`)

### PSScriptAnalyzer suppressions

Use the `[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute]` attribute to suppress findings on a function or script scope:

```powershell
# Suppress a single rule on a specific function
function Write-StatusMessage {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'This is a user-facing status function; Write-Host is intentional.'
    )]
    param([string]$Message)
    Write-Host $Message
}
```

For script-level suppression, place the attribute at the top of the file:

```powershell
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param()
```

### When not to suppress

Suppress only after you have:
1. Read the rule description to understand what it's detecting
2. Verified the specific instance is not exploitable in your context
3. Added a justification comment explaining *why* it's safe

A suppression without a justification is a finding deferred, not resolved. If you're not sure whether something is a real finding, err on the side of fixing it.
