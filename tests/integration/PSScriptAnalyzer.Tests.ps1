#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests that run PSScriptAnalyzer against the example PowerShell
    module and assert that expected findings are produced.

.DESCRIPTION
    These tests validate that PSScriptAnalyzer:
    1. Produces findings on the intentionally flawed module code
    2. Does NOT produce ERROR-severity findings on the clean Invoke-SafeFunction

    Tests are skipped automatically if PSScriptAnalyzer is not installed.
    To install: Install-Module PSScriptAnalyzer -Scope CurrentUser
#>

BeforeAll {
    $script:psaAvailable = $null -ne (Get-Module PSScriptAnalyzer -ListAvailable -ErrorAction SilentlyContinue)
    if ($script:psaAvailable) {
        Import-Module PSScriptAnalyzer -ErrorAction SilentlyContinue
    }

    $script:repoRoot   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:modulePath = Join-Path $script:repoRoot 'examples/powershell-module/ExampleModule'
    $script:safePath   = Join-Path $script:repoRoot 'examples/powershell-module/ExampleModule/Public/Invoke-SafeFunction.ps1'
    $script:unsafePath = Join-Path $script:repoRoot 'examples/powershell-module/ExampleModule/Public/Invoke-UnsafeFunction.ps1'
}

Describe 'PSScriptAnalyzer — module analysis' -Skip:(-not $script:psaAvailable) {

    Context 'Invoke-SafeFunction.ps1 — clean reference implementation' {
        BeforeAll {
            $script:safeResults = Invoke-ScriptAnalyzer -Path $script:safePath -Severity Error, Warning
        }

        It 'produces no ERROR-severity findings' {
            $errors = @($script:safeResults | Where-Object { $_.Severity -eq 'Error' })
            $errors.Count | Should -Be 0
        }
    }

    Context 'Module directory analysis' {
        BeforeAll {
            # Analyse the full module directory at Warning+ severity
            $script:moduleResults = Invoke-ScriptAnalyzer -Path $script:modulePath -Recurse -Severity Warning, Error
        }

        It 'produces at least one finding from the example module' {
            # The intentionally flawed code must trigger PSScriptAnalyzer
            @($script:moduleResults).Count | Should -BeGreaterThan 0
        }

        It 'findings are PSScriptAnalyzer DiagnosticRecord objects' {
            if (@($script:moduleResults).Count -gt 0) {
                $script:moduleResults[0].RuleName | Should -Not -BeNullOrEmpty
            }
        }

        It 'all findings have a RuleName, Severity, ScriptName, and Line' {
            foreach ($finding in $script:moduleResults) {
                $finding.RuleName   | Should -Not -BeNullOrEmpty
                $finding.Severity   | Should -Not -BeNullOrEmpty
                $finding.ScriptName | Should -Not -BeNullOrEmpty
                $finding.Line       | Should -BeGreaterThan 0
            }
        }
    }

    Context 'PSScriptAnalyzer result structure for SARIF conversion' {
        BeforeAll {
            $script:singleResult = Invoke-ScriptAnalyzer -Path $script:unsafePath -Severity Warning, Error, Information
        }

        It 'findings include a Message property' {
            foreach ($r in $script:singleResult) {
                $r.Message | Should -Not -BeNullOrEmpty
            }
        }

        It 'findings include column information' {
            foreach ($r in $script:singleResult) {
                $r.Column | Should -BeGreaterThan 0
            }
        }

        It 'findings include a ScriptPath property' {
            foreach ($r in $script:singleResult) {
                $r.ScriptPath | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'PSScriptAnalyzer can run across a directory recursively' {
        It 'recursive analysis completes without throwing' {
            { Invoke-ScriptAnalyzer -Path $script:modulePath -Recurse -ErrorAction Stop } |
                Should -Not -Throw
        }

        It 'recursive results are a collection' {
            $results = Invoke-ScriptAnalyzer -Path $script:modulePath -Recurse
            $results | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'PSScriptAnalyzer — module availability' {
    It 'PSScriptAnalyzer module is importable when installed' -Skip:(-not $script:psaAvailable) {
        { Import-Module PSScriptAnalyzer -ErrorAction Stop } | Should -Not -Throw
    }

    It 'Invoke-ScriptAnalyzer command is available when module is loaded' -Skip:(-not $script:psaAvailable) {
        Get-Command Invoke-ScriptAnalyzer | Should -Not -BeNullOrEmpty
    }
}
