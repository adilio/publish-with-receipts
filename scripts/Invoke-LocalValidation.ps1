#Requires -Version 5.1
<#
.SYNOPSIS
    Run the publish-with-receipts supply chain checks locally before pushing.

.DESCRIPTION
    Mirrors the GitHub Actions pipeline steps for local developer feedback.
    Runs the subset of checks that make sense outside of a CI environment:
      - PSScriptAnalyzer (static analysis)
      - Semgrep (custom security rules)
      - Dependency pin check (.psd1 / .nuspec)
      - SBOM generation (Syft)
      - Vulnerability scan (Grype)

    Tools that are not installed are skipped with a warning, not a hard error.
    SARIF output is written to a local 'local-results/' directory.

.PARAMETER Target
    Which package to validate: 'powershell', 'chocolatey', or 'both'.
    Default: 'both'

.PARAMETER OutputDir
    Directory to write output files (SBOM, SARIF, summaries).
    Default: './local-results'

.PARAMETER FailOnFindings
    If set, exit with code 1 when any tool reports findings.
    Default: $false (surface findings without blocking)

.PARAMETER SkipSBOM
    Skip SBOM generation and vulnerability scan (Syft/Grype).
    Useful for quick local checks where a full inventory is not needed.

.EXAMPLE
    # Quick check before committing
    ./scripts/Invoke-LocalValidation.ps1 -Target powershell

.EXAMPLE
    # Full check, fail on findings, custom output dir
    ./scripts/Invoke-LocalValidation.ps1 -Target both -FailOnFindings -OutputDir ./scan-output

.NOTES
    Required tools (install once):
      PSScriptAnalyzer : Install-Module PSScriptAnalyzer -Scope CurrentUser
      Semgrep          : pip install semgrep  (or brew install semgrep on macOS)
      Syft             : https://github.com/anchore/syft#installation
      Grype            : https://github.com/anchore/grype#installation
#>
[CmdletBinding()]
param(
    [ValidateSet('powershell', 'chocolatey', 'both')]
    [string]$Target = 'both',

    [string]$OutputDir = './local-results',

    [switch]$FailOnFindings,

    [switch]$SkipSBOM
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
$script:exitCode  = 0
$script:findings  = [System.Collections.Generic.List[string]]::new()
$script:repoRoot  = Split-Path -Parent $PSScriptRoot

function Write-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "▶ $Message" -ForegroundColor Yellow
}

function Write-OK {
    param([string]$Message)
    Write-Host "  ✓ $Message" -ForegroundColor Green
}

function Write-Issue {
    param([string]$Message)
    Write-Host "  ✗ $Message" -ForegroundColor Red
    $script:findings.Add($Message)
    if ($FailOnFindings) { $script:exitCode = 1 }
}

function Write-Skip {
    param([string]$Message)
    Write-Host "  ~ $Message" -ForegroundColor Gray
}

function Test-Command {
    param([string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
$outputPath = if ([System.IO.Path]::IsPathRooted($OutputDir)) { $OutputDir } else { Join-Path $script:repoRoot $OutputDir }
if (-not (Test-Path $outputPath)) {
    New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
}

Write-Header "Publish-with-Receipts — Local Validation"
Write-Host "  Repo root  : $($script:repoRoot)"
Write-Host "  Target     : $Target"
Write-Host "  Output dir : $outputPath"
Write-Host "  Fail mode  : $(if ($FailOnFindings) { 'fail on findings' } else { 'surface only' })"

# ---------------------------------------------------------------------------
# Tool availability
# ---------------------------------------------------------------------------
Write-Step "Checking tool availability"

$hasPSScriptAnalyzer = $null -ne (Get-Module PSScriptAnalyzer -ListAvailable -ErrorAction SilentlyContinue)
$hasSemgrep          = Test-Command 'semgrep'
$hasSyft             = Test-Command 'syft'
$hasGrype            = Test-Command 'grype'

Write-Host "  PSScriptAnalyzer : $(if ($hasPSScriptAnalyzer) { '✓ installed' } else { '✗ not found — Install-Module PSScriptAnalyzer' })"
Write-Host "  Semgrep          : $(if ($hasSemgrep) { '✓ installed' } else { '✗ not found — pip install semgrep' })"
Write-Host "  Syft             : $(if ($hasSyft) { '✓ installed' } else { '✗ not found — https://github.com/anchore/syft' })"
Write-Host "  Grype            : $(if ($hasGrype) { '✓ installed' } else { '✗ not found — https://github.com/anchore/grype' })"

# ---------------------------------------------------------------------------
# Utility: run PSScriptAnalyzer on a path
# ---------------------------------------------------------------------------
function Invoke-PSScriptAnalyzerCheck {
    param([string]$Path, [string]$SarifOutput)

    Write-Step "PSScriptAnalyzer → $Path"

    if (-not $hasPSScriptAnalyzer) {
        Write-Skip "PSScriptAnalyzer not installed. Skipping."
        return
    }

    Import-Module PSScriptAnalyzer -ErrorAction Stop

    $results = Invoke-ScriptAnalyzer -Path $Path -Recurse -Severity Warning, Error

    if ($results.Count -eq 0) {
        Write-OK "No findings at Warning+ severity."
    } else {
        foreach ($r in $results) {
            Write-Issue "[$($r.Severity)] $($r.RuleName) — $($r.ScriptName):$($r.Line) — $($r.Message)"
        }
    }

    # Minimal SARIF output (console SARIF writer)
    $sarifPath = Join-Path $outputPath $SarifOutput
    $sarif = @{
        '$schema' = 'https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json'
        version   = '2.1.0'
        runs      = @(@{
            tool    = @{ driver = @{ name = 'PSScriptAnalyzer'; version = (Get-Module PSScriptAnalyzer -ListAvailable | Select-Object -First 1).Version.ToString() } }
            results = @($results | ForEach-Object {
                @{
                    ruleId  = $_.RuleName
                    level   = if ($_.Severity -eq 'Error') { 'error' } else { 'warning' }
                    message = @{ text = $_.Message }
                    locations = @(@{
                        physicalLocation = @{
                            artifactLocation = @{ uri = $_.ScriptPath }
                            region           = @{ startLine = $_.Line; startColumn = $_.Column }
                        }
                    })
                }
            })
        })
    }
    $sarif | ConvertTo-Json -Depth 10 | Set-Content -Path $sarifPath -Encoding utf8
    Write-Host "  SARIF written to: $sarifPath"
}

# ---------------------------------------------------------------------------
# Utility: run Semgrep
# ---------------------------------------------------------------------------
function Invoke-SemgrepCheck {
    param([string]$Path, [string[]]$Rules, [string]$SarifOutput)

    Write-Step "Semgrep → $Path"

    if (-not $hasSemgrep) {
        Write-Skip "Semgrep not installed. Skipping."
        return
    }

    $sarifPath  = Join-Path $outputPath $SarifOutput
    $rulesArgs  = $Rules | ForEach-Object { "--config"; (Join-Path $script:repoRoot $_) }

    # Semgrep exits 1 when it finds issues — that's expected, not an error
    $null = semgrep $rulesArgs $Path --sarif --output $sarifPath 2>&1
    $semgrepExit = $LASTEXITCODE

    if ($semgrepExit -eq 0) {
        Write-OK "No Semgrep findings."
    } elseif ($semgrepExit -eq 1) {
        $findingCount = 0
        if (Test-Path $sarifPath) {
            $sarifData = Get-Content $sarifPath | ConvertFrom-Json
            $findingCount = ($sarifData.runs[0].results | Measure-Object).Count
        }
        Write-Issue "Semgrep: $findingCount finding(s). See $sarifPath"
    } else {
        Write-Issue "Semgrep exited with code $semgrepExit (tool error, not a finding)."
    }

    Write-Host "  SARIF written to: $sarifPath"
}

# ---------------------------------------------------------------------------
# Utility: dependency pin check (inline, mirrors action logic)
# ---------------------------------------------------------------------------
function Invoke-DependencyPinCheck {
    param([string]$SearchPath)

    Write-Step "Dependency pin check → $SearchPath"

    $pinFindings = [System.Collections.Generic.List[string]]::new()

    # .psd1 manifests
    Get-ChildItem -Path $SearchPath -Recurse -Filter '*.psd1' -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $data = Import-PowerShellDataFile -Path $_.FullName -ErrorAction Stop
        } catch {
            Write-Host "  ! Could not parse $($_.Name): $_"
            return
        }

        foreach ($req in @($data.RequiredModules)) {
            if (-not $req) { continue }
            if ($req -is [string]) {
                $pinFindings.Add("[HIGH] $($_.Name) — RequiredModules '$req' has no version constraint")
            } elseif ($req -is [hashtable]) {
                $name            = if ($req.ContainsKey('ModuleName'))      { $req['ModuleName'] }      else { '(unknown)' }
                $hasRequired     = $req.ContainsKey('RequiredVersion') -and $req['RequiredVersion']
                $hasMaximum      = $req.ContainsKey('MaximumVersion')  -and $req['MaximumVersion']
                $hasMinimum      = $req.ContainsKey('ModuleVersion')   -and $req['ModuleVersion']
                if (-not $hasRequired -and -not $hasMaximum -and $hasMinimum) {
                    $pinFindings.Add("[MEDIUM] $($_.Name) — Module '$name' uses ModuleVersion (minimum) without MaximumVersion or RequiredVersion")
                } elseif (-not $hasRequired -and -not $hasMinimum) {
                    $pinFindings.Add("[HIGH] $($_.Name) — Module '$name' has no version constraint")
                }
            }
        }
    }

    # .nuspec files
    Get-ChildItem -Path $SearchPath -Recurse -Filter '*.nuspec' -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            [xml]$xml = Get-Content $_.FullName -ErrorAction Stop
        } catch {
            Write-Host "  ! Could not parse $($_.Name): $_"
            return
        }
        $deps = $xml.SelectNodes('//dependency')
        foreach ($dep in $deps) {
            if (-not $dep) { continue }
            $id  = $dep.id
            $ver = $dep.version
            if ([string]::IsNullOrWhiteSpace($ver)) {
                $pinFindings.Add("[HIGH] $($_.Name) — Dependency '$id' has no version attribute")
            } elseif ($ver -notmatch '^\[' -and $ver -notmatch '^\(' -and $ver -notmatch '^\d+\.\d+\.\d+') {
                $pinFindings.Add("[MEDIUM] $($_.Name) — Dependency '$id' version '$ver' appears to be a minimum-version constraint")
            }
        }
    }

    if ($pinFindings.Count -eq 0) {
        Write-OK "All dependencies are pinned or bounded."
    } else {
        foreach ($f in $pinFindings) {
            Write-Issue "Pinning: $f"
        }
    }
}

# ---------------------------------------------------------------------------
# Utility: SBOM + vulnerability scan
# ---------------------------------------------------------------------------
function Invoke-SBOMAndVulnScan {
    param([string]$Path, [string]$SbomName)

    if ($SkipSBOM) {
        Write-Skip "SBOM/Grype skipped (-SkipSBOM is set). Omit -SkipSBOM to include these checks."
        return
    }

    $sbomPath = Join-Path $outputPath "$SbomName.cdx.json"

    Write-Step "SBOM generation (Syft) → $Path"
    if (-not $hasSyft) {
        Write-Skip "Syft not installed. Skipping SBOM."
    } else {
        syft $Path --output cyclonedx-json=$sbomPath 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-OK "SBOM written to: $sbomPath"
        } else {
            Write-Issue "Syft exited with code $LASTEXITCODE"
        }
    }

    Write-Step "Vulnerability scan (Grype) → $sbomPath"
    if (-not $hasGrype) {
        Write-Skip "Grype not installed. Skipping vulnerability scan."
    } elseif (-not (Test-Path $sbomPath)) {
        Write-Skip "SBOM not found. Skipping vulnerability scan."
    } else {
        $grypeOut  = Join-Path $outputPath "$SbomName-vuln.json"
        $grypeSarif = Join-Path $outputPath "$SbomName-vuln.sarif"
        grype sbom:$sbomPath --output json --file $grypeOut 2>&1 | Out-Null
        grype sbom:$sbomPath --output sarif --file $grypeSarif 2>&1 | Out-Null

        if (Test-Path $grypeOut) {
            $data   = Get-Content $grypeOut | ConvertFrom-Json
            $vulns  = @($data.matches)
            $critical = @($vulns | Where-Object { $_.vulnerability.severity -eq 'Critical' }).Count
            $high     = @($vulns | Where-Object { $_.vulnerability.severity -eq 'High' }).Count
            $medium   = @($vulns | Where-Object { $_.vulnerability.severity -eq 'Medium' }).Count

            if ($vulns.Count -eq 0) {
                Write-OK "No known vulnerabilities."
            } else {
                if ($critical -gt 0) { Write-Issue "Grype: $critical Critical vulnerability/ies found" }
                if ($high     -gt 0) { Write-Issue "Grype: $high High vulnerability/ies found" }
                if ($medium   -gt 0) { Write-Host "  ~ Grype: $medium Medium (informational)" -ForegroundColor Gray }
                Write-Host "  Full report: $grypeOut"
            }
        }
    }
}

# ---------------------------------------------------------------------------
# PowerShell module checks
# ---------------------------------------------------------------------------
if ($Target -in 'powershell', 'both') {
    Write-Header "PowerShell Module — examples/powershell-module"

    $psModulePath = Join-Path $script:repoRoot 'examples/powershell-module'

    Invoke-PSScriptAnalyzerCheck `
        -Path       $psModulePath `
        -SarifOutput 'psscriptanalyzer-local.sarif'

    Invoke-SemgrepCheck `
        -Path        $psModulePath `
        -Rules       @('semgrep-rules/powershell-unsafe-patterns.yml') `
        -SarifOutput 'semgrep-powershell-local.sarif'

    Invoke-DependencyPinCheck -SearchPath $psModulePath

    Invoke-SBOMAndVulnScan `
        -Path    $psModulePath `
        -SbomName 'powershell-module'
}

# ---------------------------------------------------------------------------
# Chocolatey package checks
# ---------------------------------------------------------------------------
if ($Target -in 'chocolatey', 'both') {
    Write-Header "Chocolatey Package — examples/chocolatey-package"

    $chocoPackagePath = Join-Path $script:repoRoot 'examples/chocolatey-package'

    Invoke-SemgrepCheck `
        -Path        $chocoPackagePath `
        -Rules       @('semgrep-rules/chocolatey-install-patterns.yml', 'semgrep-rules/powershell-unsafe-patterns.yml') `
        -SarifOutput 'semgrep-chocolatey-local.sarif'

    Invoke-DependencyPinCheck -SearchPath $chocoPackagePath

    Invoke-SBOMAndVulnScan `
        -Path     $chocoPackagePath `
        -SbomName 'chocolatey-package'
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Header "Summary"

if ($script:findings.Count -eq 0) {
    Write-Host "  ✓ No findings to report." -ForegroundColor Green
} else {
    Write-Host "  $($script:findings.Count) finding(s):" -ForegroundColor Red
    foreach ($f in $script:findings) {
        Write-Host "    • $f" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "  Output files written to: $outputPath"
Write-Host ""

if ($script:exitCode -ne 0) {
    Write-Host "  Exiting with code 1 (findings found, -FailOnFindings is set)." -ForegroundColor Red
}

exit $script:exitCode
