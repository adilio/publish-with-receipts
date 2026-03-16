#Requires -Version 7.0
<#
.SYNOPSIS
    Runs the full publish-with-receipts test suite using Pester.

.DESCRIPTION
    Discovers and runs all Pester test files in the tests/ directory:
      - tests/unit/           Unit tests (pure PowerShell logic, no external deps)
      - tests/integration/    Integration tests (may require PSScriptAnalyzer, Semgrep)
      - tests/e2e/            End-to-end tests (run Invoke-LocalValidation.ps1)
      - examples/*/tests/     Functional tests for example module code

    Tests that require tools not currently installed are skipped automatically.

    Optionally runs `semgrep --test semgrep-rules/` to validate Semgrep rule fixtures.

.PARAMETER Scope
    Which test scope to run: 'all', 'unit', 'integration', 'e2e', or 'module'.
    Default: 'all'

.PARAMETER IncludeSemgrepTest
    Also run `semgrep --test semgrep-rules/` after the Pester suite.
    Requires Semgrep to be installed. Default: $false

.PARAMETER OutputFormat
    Pester output format: 'Detailed', 'Normal', 'Minimal', 'None'.
    Default: 'Detailed'

.PARAMETER JUnitOutput
    Path to write JUnit XML output (for CI integration).
    Default: '' (disabled)

.EXAMPLE
    # Run all tests
    ./tests/Run-Tests.ps1

.EXAMPLE
    # Run only unit tests
    ./tests/Run-Tests.ps1 -Scope unit

.EXAMPLE
    # Run all tests including semgrep --test, output JUnit XML for CI
    ./tests/Run-Tests.ps1 -IncludeSemgrepTest -JUnitOutput ./test-results.xml
#>
[CmdletBinding()]
param(
    [ValidateSet('all', 'unit', 'integration', 'e2e', 'module')]
    [string]$Scope = 'all',

    [switch]$IncludeSemgrepTest,

    [ValidateSet('Detailed', 'Normal', 'Minimal', 'None')]
    [string]$OutputFormat = 'Detailed',

    [string]$JUnitOutput = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

# ---------------------------------------------------------------------------
# Ensure Pester is available
# ---------------------------------------------------------------------------
if (-not (Get-Module Pester -ListAvailable | Where-Object { $_.Version -ge [version]'5.0' })) {
    Write-Host "Pester 5.0+ not found. Installing..." -ForegroundColor Yellow
    Install-Module Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck -Scope CurrentUser
}
Import-Module Pester -MinimumVersion 5.0 -Force

# ---------------------------------------------------------------------------
# Build test path list
# ---------------------------------------------------------------------------
$testPaths = switch ($Scope) {
    'unit'        { @(Join-Path $repoRoot 'tests/unit') }
    'integration' { @(Join-Path $repoRoot 'tests/integration') }
    'e2e'         { @(Join-Path $repoRoot 'tests/e2e') }
    'module'      { @(Join-Path $repoRoot 'examples/powershell-module/tests') }
    'all'         {
        @(
            Join-Path $repoRoot 'tests/unit'
            Join-Path $repoRoot 'tests/integration'
            Join-Path $repoRoot 'tests/e2e'
            Join-Path $repoRoot 'examples/powershell-module/tests'
        )
    }
}

# Filter to paths that exist
$testPaths = $testPaths | Where-Object { Test-Path $_ }

if ($testPaths.Count -eq 0) {
    Write-Error "No test paths found for scope '$Scope'."
    exit 1
}

# ---------------------------------------------------------------------------
# Configure Pester
# ---------------------------------------------------------------------------
$config = New-PesterConfiguration
$config.Run.Path            = $testPaths
$config.Output.Verbosity    = $OutputFormat
$config.Run.PassThru        = $true
$config.TestResult.Enabled  = $JUnitOutput -ne ''

if ($JUnitOutput -ne '') {
    $config.TestResult.OutputPath   = $JUnitOutput
    $config.TestResult.OutputFormat = 'JUnitXml'
}

# ---------------------------------------------------------------------------
# Run Pester
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "  publish-with-receipts Test Suite" -ForegroundColor Cyan
Write-Host "  Scope: $Scope" -ForegroundColor Cyan
Write-Host "  Paths: $($testPaths -join ', ')" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""

$pesterResult = Invoke-Pester -Configuration $config

# ---------------------------------------------------------------------------
# Run Semgrep --test if requested
# ---------------------------------------------------------------------------
$semgrepExitCode = 0
if ($IncludeSemgrepTest) {
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  Semgrep Rule Tests (semgrep --test)" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host ""

    if ($null -eq (Get-Command semgrep -ErrorAction SilentlyContinue)) {
        Write-Warning "Semgrep not installed. Skipping semgrep --test. Install with: pip install semgrep"
    } else {
        $semgrepRulesDir = Join-Path $repoRoot 'semgrep-rules'
        Write-Host "Running: semgrep --test $semgrepRulesDir"
        semgrep --test $semgrepRulesDir
        $semgrepExitCode = $LASTEXITCODE
        if ($semgrepExitCode -eq 0) {
            Write-Host "  ✓ All Semgrep rule tests passed." -ForegroundColor Green
        } else {
            Write-Host "  ✗ Semgrep rule tests failed (exit code $semgrepExitCode)." -ForegroundColor Red
        }
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "  Summary" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan

$passed  = $pesterResult.PassedCount
$failed  = $pesterResult.FailedCount
$skipped = $pesterResult.SkippedCount
$total   = $pesterResult.TotalCount

Write-Host "  Pester:  $passed passed, $failed failed, $skipped skipped (of $total)"
if ($IncludeSemgrepTest) {
    Write-Host "  Semgrep: $(if ($semgrepExitCode -eq 0) { 'PASSED' } else { 'FAILED' })"
}
Write-Host ""

$overallFailed = $failed -gt 0 -or $semgrepExitCode -ne 0
if ($overallFailed) {
    Write-Host "  RESULT: FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "  RESULT: PASSED" -ForegroundColor Green
    exit 0
}
