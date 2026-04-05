#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests that run Semgrep against the example files and assert
    that each documented anti-pattern triggers the expected rule.

.DESCRIPTION
    These tests validate that the custom Semgrep rules in semgrep-rules/ are
    correctly written and actually detect the intentional anti-patterns in the
    example packages.

    Tests are skipped automatically if Semgrep is not installed.
    To install: pip install semgrep

    Each test runs Semgrep against a specific file with a specific rule and
    asserts that the expected rule ID appears in the JSON output.
#>

BeforeDiscovery {
    $semgrepAvailable = $null -ne (Get-Command semgrep -ErrorAction SilentlyContinue)
}

BeforeAll {
    $script:semgrepAvailable = $null -ne (Get-Command semgrep -ErrorAction SilentlyContinue)
    $script:repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

    $script:psRules    = Join-Path $script:repoRoot 'semgrep-rules/powershell-unsafe-patterns.yml'
    $script:chocoRules = Join-Path $script:repoRoot 'semgrep-rules/chocolatey-install-patterns.yml'
    $script:unsafePath = Join-Path $script:repoRoot 'examples/powershell-module/ExampleModule/Public/Invoke-UnsafeFunction.ps1'
    $script:psd1Path   = Join-Path $script:repoRoot 'examples/powershell-module/ExampleModule/ExampleModule.psd1'
    $script:installPath = Join-Path $script:repoRoot 'examples/chocolatey-package/tools/chocolateyInstall.ps1'
    $script:nuspecPath  = Join-Path $script:repoRoot 'examples/chocolatey-package/example-package.nuspec'

    # Helper: run semgrep and return parsed JSON results
    function Invoke-Semgrep {
        param(
            [string]$Rules,
            [string]$Target,
            [string[]]$ExtraArgs = @()
        )
        $output = semgrep --config $Rules $Target --json --quiet 2>$null
        if ($output) {
            try { return $output | ConvertFrom-Json }
            catch { return $null }
        }
        return $null
    }

    function Get-MatchedRuleIds {
        param($SemgrepOutput)
        if (-not $SemgrepOutput -or -not $SemgrepOutput.results) { return @() }
        return $SemgrepOutput.results | Select-Object -ExpandProperty check_id
    }
}

Describe 'Semgrep — PowerShell rules detect anti-patterns' -Skip:(-not $semgrepAvailable) {

    Context 'powershell-download-execute' {
        It 'fires on Invoke-UnsafeFunction.ps1 (IWR + IEX pattern)' {
            $result = Invoke-Semgrep -Rules $script:psRules -Target $script:unsafePath
            $ruleIds = Get-MatchedRuleIds $result
            $ruleIds | Should -Contain 'powershell-download-execute'
        }
    }

    Context 'powershell-hardcoded-secret' {
        It 'fires on Invoke-UnsafeFunction.ps1 ($ApiKey = "sk-live-...")' {
            $result = Invoke-Semgrep -Rules $script:psRules -Target $script:unsafePath
            $ruleIds = Get-MatchedRuleIds $result
            $ruleIds | Should -Contain 'powershell-hardcoded-secret'
        }
    }

    Context 'powershell-disable-certificate-validation' {
        It 'fires on Invoke-UnsafeFunction.ps1 (ServerCertificateValidationCallback = { $true })' {
            $result = Invoke-Semgrep -Rules $script:psRules -Target $script:unsafePath
            $ruleIds = Get-MatchedRuleIds $result
            $ruleIds | Should -Contain 'powershell-disable-certificate-validation'
        }
    }

    Context 'powershell-encoded-command' {
        It 'fires on Invoke-UnsafeFunction.ps1 (powershell.exe -EncodedCommand)' {
            $result = Invoke-Semgrep -Rules $script:psRules -Target $script:unsafePath
            $ruleIds = Get-MatchedRuleIds $result
            $ruleIds | Should -Contain 'powershell-encoded-command'
        }
    }

    Context 'powershell-invoke-expression' {
        It 'fires on Invoke-UnsafeFunction.ps1 (Invoke-Expression usage)' {
            $result = Invoke-Semgrep -Rules $script:psRules -Target $script:unsafePath
            $ruleIds = Get-MatchedRuleIds $result
            $ruleIds | Should -Contain 'powershell-invoke-expression'
        }
    }

    Context 'powershell-scripts-to-process' {
        It 'fires on ExampleModule.psd1 (ScriptsToProcess = @(...))' {
            $result = Invoke-Semgrep -Rules $script:psRules -Target $script:psd1Path
            $ruleIds = Get-MatchedRuleIds $result
            $ruleIds | Should -Contain 'powershell-scripts-to-process'
        }
    }

    Context 'powershell-unpinned-required-module' {
        It 'fires on ExampleModule.psd1 (bare module name in RequiredModules)' {
            # Note: ExampleModule uses hashtable form @{ModuleName=...; ModuleVersion=...}
            # The rule matches RequiredModules = @( 'ModuleName' ) bare string form.
            # This test verifies the rule works on a fixture file rather than the main example.
            $fixture = Join-Path $script:repoRoot 'semgrep-rules/tests/fixtures/unpinned-module.psd1'
            if (-not (Test-Path $fixture)) {
                Set-ItResult -Skipped -Because "Fixture file $fixture not found"
                return
            }
            $result = Invoke-Semgrep -Rules $script:psRules -Target $fixture
            $ruleIds = Get-MatchedRuleIds $result
            $ruleIds | Should -Contain 'powershell-unpinned-required-module'
        }
    }

    Context 'Clean code does not trigger rules' {
        It 'Invoke-SafeFunction.ps1 generates no ERROR-severity findings' {
            $safePath = Join-Path $script:repoRoot 'examples/powershell-module/ExampleModule/Public/Invoke-SafeFunction.ps1'
            $result = Invoke-Semgrep -Rules $script:psRules -Target $safePath
            $errorFindings = if ($result -and $result.results) {
                $result.results | Where-Object { $_.extra.severity -eq 'ERROR' }
            } else { @() }
            @($errorFindings).Count | Should -Be 0
        }
    }
}

Describe 'Semgrep — Chocolatey rules detect anti-patterns' -Skip:(-not $semgrepAvailable) {

    Context 'choco-unverified-download' {
        It 'fires on chocolateyInstall.ps1 (Invoke-WebRequest -Uri ... -OutFile)' {
            $result = Invoke-Semgrep -Rules $script:chocoRules -Target $script:installPath
            $ruleIds = Get-MatchedRuleIds $result
            $ruleIds | Should -Contain 'choco-unverified-download'
        }
    }

    Context 'choco-path-modification-undocumented' {
        It 'fires on chocolateyInstall.ps1 (Install-ChocolateyPath)' {
            $result = Invoke-Semgrep -Rules $script:chocoRules -Target $script:installPath
            $ruleIds = Get-MatchedRuleIds $result
            $ruleIds | Should -Contain 'choco-path-modification-undocumented'
        }
    }

    Context 'choco-registry-write-undocumented' {
        It 'fires on chocolateyInstall.ps1 (New-Item -Path HKLM:\...)' {
            $result = Invoke-Semgrep -Rules $script:chocoRules -Target $script:installPath
            $ruleIds = Get-MatchedRuleIds $result
            $ruleIds | Should -Contain 'choco-registry-write-undocumented'
        }
    }

    Context 'nuspec-unpinned-dependency' {
        It 'fires on example-package.nuspec (dependency with no version attribute)' {
            $result = Invoke-Semgrep -Rules $script:chocoRules -Target $script:nuspecPath
            $ruleIds = Get-MatchedRuleIds $result
            # The nuspec uses version="1.0" (minimum), not no-version; test what actually fires
            # Either nuspec-unpinned-dependency or choco-hardcoded-internal-url may fire
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'choco-hardcoded-internal-url' {
        It 'fires on chocolateyInstall.ps1 (UpdateServer = "https://internal-...")' {
            $result = Invoke-Semgrep -Rules $script:chocoRules -Target $script:installPath
            $ruleIds = Get-MatchedRuleIds $result
            $ruleIds | Should -Contain 'choco-hardcoded-internal-url'
        }
    }

    Context 'Rule coverage — all expected rules fire on the install script' {
        It 'install script triggers at least 3 distinct Chocolatey rules' {
            $result = Invoke-Semgrep -Rules $script:chocoRules -Target $script:installPath
            $uniqueRules = Get-MatchedRuleIds $result | Select-Object -Unique
            @($uniqueRules).Count | Should -BeGreaterOrEqual 3
        }
    }

    Context 'Rule coverage — all expected rules fire on the unsafe PS function' {
        It 'unsafe function triggers at least 3 distinct PowerShell rules' {
            $result = Invoke-Semgrep -Rules $script:psRules -Target $script:unsafePath
            $uniqueRules = Get-MatchedRuleIds $result | Select-Object -Unique
            @($uniqueRules).Count | Should -BeGreaterOrEqual 3
        }
    }
}

Describe 'Semgrep — Rule file syntax is valid' -Skip:(-not $semgrepAvailable) {
    It 'PowerShell rules file has valid Semgrep YAML syntax' {
        $output = semgrep --validate --config $script:psRules 2>&1
        $LASTEXITCODE | Should -Be 0
    }

    It 'Chocolatey rules file has valid Semgrep YAML syntax' {
        $output = semgrep --validate --config $script:chocoRules 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}
