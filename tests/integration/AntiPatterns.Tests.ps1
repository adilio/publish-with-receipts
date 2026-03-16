#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests verifying that the demo example files contain their
    documented intentional anti-patterns.

.DESCRIPTION
    These tests verify the correctness of the example material used in the
    "Provenance Before Publish" talk. The examples are deliberately flawed;
    if these tests fail it means the example files were accidentally cleaned up,
    which would break the pipeline demos.

    These tests do NOT execute any of the example code — they read source files
    and assert on expected patterns using string matching.

    Categories:
    - PowerShell module manifest (.psd1) flaws
    - PowerShell function source anti-patterns
    - Chocolatey install script flaws
    - Chocolatey package spec (.nuspec) flaws
#>

BeforeAll {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

    $script:psd1Path    = Join-Path $repoRoot 'examples/powershell-module/ExampleModule/ExampleModule.psd1'
    $script:unsafePath  = Join-Path $repoRoot 'examples/powershell-module/ExampleModule/Public/Invoke-UnsafeFunction.ps1'
    $script:safePath    = Join-Path $repoRoot 'examples/powershell-module/ExampleModule/Public/Invoke-SafeFunction.ps1'
    $script:installPath = Join-Path $repoRoot 'examples/chocolatey-package/tools/chocolateyInstall.ps1'
    $script:nuspecPath  = Join-Path $repoRoot 'examples/chocolatey-package/example-package.nuspec'
    $script:verifyPath  = Join-Path $repoRoot 'examples/chocolatey-package/tools/VERIFICATION.txt'

    # Pre-load file contents for multiple assertions
    $script:psd1Content    = Get-Content $script:psd1Path    -Raw
    $script:unsafeContent  = Get-Content $script:unsafePath  -Raw
    $script:safeContent    = Get-Content $script:safePath    -Raw
    $script:installContent = Get-Content $script:installPath -Raw
    $script:nuspecContent  = Get-Content $script:nuspecPath  -Raw

    # All example files must exist
    $script:allExamplesExist = (
        (Test-Path $script:psd1Path)    -and
        (Test-Path $script:unsafePath)  -and
        (Test-Path $script:safePath)    -and
        (Test-Path $script:installPath) -and
        (Test-Path $script:nuspecPath)
    )
}

Describe 'Example file existence' {
    It 'ExampleModule.psd1 exists' {
        Test-Path $script:psd1Path | Should -BeTrue
    }
    It 'Invoke-UnsafeFunction.ps1 exists' {
        Test-Path $script:unsafePath | Should -BeTrue
    }
    It 'Invoke-SafeFunction.ps1 exists' {
        Test-Path $script:safePath | Should -BeTrue
    }
    It 'chocolateyInstall.ps1 exists' {
        Test-Path $script:installPath | Should -BeTrue
    }
    It 'example-package.nuspec exists' {
        Test-Path $script:nuspecPath | Should -BeTrue
    }
    It 'VERIFICATION.txt exists' {
        Test-Path $script:verifyPath | Should -BeTrue
    }
}

Describe 'ExampleModule.psd1 — intentional anti-patterns' -Skip:(-not $script:allExamplesExist) {

    Context 'Floating dependency (Threat Vector 3)' {
        It 'uses ModuleVersion (minimum) without RequiredVersion for Az.Accounts' {
            # Demonstrates floating dependency — ModuleVersion is a minimum, not an exact pin
            $script:psd1Content | Should -Match 'ModuleVersion\s*=\s*[''"]2\.0\.0[''"]'
        }

        It 'does NOT use RequiredVersion for any module (would be pinned)' {
            $script:psd1Content | Should -Not -Match 'RequiredVersion'
        }

        It 'declares Az.Accounts as a required module' {
            $script:psd1Content | Should -Match "ModuleName\s*=\s*'Az\.Accounts'"
        }
    }

    Context 'ScriptsToProcess (Threat Vector 1 — typosquatting mechanism)' {
        It 'uses ScriptsToProcess (executes code at import time)' {
            $script:psd1Content | Should -Match 'ScriptsToProcess'
        }

        It 'ScriptsToProcess references Initialize-Module.ps1' {
            $script:psd1Content | Should -Match "Initialize-Module\.ps1"
        }
    }

    Context 'Incomplete metadata' {
        It 'is missing CompanyName field' {
            $script:psd1Content | Should -Not -Match 'CompanyName\s*='
        }

        It 'is missing Copyright field' {
            $script:psd1Content | Should -Not -Match 'Copyright\s*='
        }

        It 'has Author but no CompanyName (minimum metadata only)' {
            $script:psd1Content | Should -Match "Author\s*=\s*'Example Author'"
        }

        It 'PSData block is missing ProjectUri' {
            $script:psd1Content | Should -Not -Match 'ProjectUri\s*='
        }

        It 'PSData block is missing LicenseUri' {
            $script:psd1Content | Should -Not -Match 'LicenseUri\s*='
        }
    }
}

Describe 'Invoke-UnsafeFunction.ps1 — intentional anti-patterns' -Skip:(-not $script:allExamplesExist) {

    Context 'Hardcoded secret (Threat Vector 4)' {
        It 'contains a hardcoded API key assignment' {
            # Triggers: powershell-hardcoded-secret
            $script:unsafeContent | Should -Match '\$ApiKey\s*=\s*"sk-live-'
        }

        It 'API key is a string literal, not from environment variable' {
            $script:unsafeContent | Should -Not -Match '\$ApiKey\s*=\s*\$env:'
        }
    }

    Context 'TLS certificate validation bypass (Threat Vector 2)' {
        It 'disables certificate validation via ServerCertificateValidationCallback' {
            # Triggers: powershell-disable-certificate-validation
            $script:unsafeContent | Should -Match 'ServerCertificateValidationCallback'
        }

        It 'sets the callback to always return true' {
            $script:unsafeContent | Should -Match '\{\s*\$true\s*\}'
        }
    }

    Context 'Download-and-execute pattern (Threat Vector 2)' {
        It 'uses Invoke-WebRequest to fetch remote content' {
            # Triggers: powershell-download-execute
            $script:unsafeContent | Should -Match 'Invoke-WebRequest\s+-Uri'
        }

        It 'passes fetched content to Invoke-Expression' {
            $script:unsafeContent | Should -Match 'Invoke-Expression'
        }

        It 'Invoke-WebRequest result is fed to Invoke-Expression (download-execute)' {
            # Both must be present; the action checks for the combined pattern
            $hasIWR = $script:unsafeContent -match 'Invoke-WebRequest'
            $hasIEX = $script:unsafeContent -match 'Invoke-Expression'
            ($hasIWR -and $hasIEX) | Should -BeTrue
        }
    }

    Context 'Base64 encoded command (obfuscation)' {
        It 'uses powershell.exe -EncodedCommand' {
            # Triggers: powershell-encoded-command
            $script:unsafeContent | Should -Match 'powershell\.exe\s+-EncodedCommand'
        }

        It 'constructs the encoded command using Base64' {
            $script:unsafeContent | Should -Match 'ToBase64String'
        }
    }
}

Describe 'Invoke-SafeFunction.ps1 — clean reference implementation' -Skip:(-not $script:allExamplesExist) {

    It 'does NOT contain Invoke-Expression' {
        $script:safeContent | Should -Not -Match 'Invoke-Expression|IEX'
    }

    It 'does NOT contain Invoke-WebRequest' {
        $script:safeContent | Should -Not -Match 'Invoke-WebRequest|IWR'
    }

    It 'does NOT contain hardcoded API key pattern' {
        $script:safeContent | Should -Not -Match '\$ApiKey\s*=\s*"'
    }

    It 'does NOT disable certificate validation' {
        $script:safeContent | Should -Not -Match 'ServerCertificateValidationCallback'
    }

    It 'uses ValidateNotNullOrEmpty for parameter validation' {
        $script:safeContent | Should -Match 'ValidateNotNullOrEmpty'
    }

    It 'has CmdletBinding for advanced function features' {
        $script:safeContent | Should -Match '\[CmdletBinding'
    }
}

Describe 'chocolateyInstall.ps1 — intentional anti-patterns' -Skip:(-not $script:allExamplesExist) {

    Context 'Missing checksum (Threat Vector 5)' {
        It 'contains an external URL for binary download' {
            # Triggers: choco-integrity-check, choco-install-package-no-checksum
            $script:installContent | Should -Match "url\s*=\s*'?`"?https?://"
        }

        It 'does NOT have a checksum argument (intentionally missing)' {
            # The checksum line is commented out
            $activeLines = $script:installContent -split "`n" | Where-Object { $_ -notmatch '^\s*#' }
            ($activeLines -join "`n") | Should -Not -Match 'checksum\s*='
        }
    }

    Context 'Direct Invoke-WebRequest bypass (Threat Vector 2)' {
        It 'uses Invoke-WebRequest directly for a supplementary download' {
            # Triggers: choco-unverified-download
            $script:installContent | Should -Match 'Invoke-WebRequest\s+-Uri'
        }

        It 'executes the directly downloaded file without checksum' {
            # Triggers: choco-execute-downloaded-content
            $script:installContent | Should -Match '&\s+\$supplementaryDest'
        }
    }

    Context 'Undocumented PATH modification (Threat Vector 6)' {
        It 'calls Install-ChocolateyPath' {
            # Triggers: choco-path-modification-undocumented
            $script:installContent | Should -Match 'Install-ChocolateyPath'
        }
    }

    Context 'Undocumented registry write (Threat Vector 6)' {
        It 'writes to HKLM registry' {
            # Triggers: choco-registry-write-undocumented
            $script:installContent | Should -Match "HKLM:\\\\SOFTWARE"
        }

        It 'uses New-Item for registry key creation' {
            $script:installContent | Should -Match 'New-Item\s+-Path'
        }

        It 'uses Set-ItemProperty for registry value setting' {
            $script:installContent | Should -Match 'Set-ItemProperty'
        }
    }

    Context 'Hardcoded internal URL (Threat Vector 4)' {
        It 'contains a hardcoded internal update server URL' {
            # Triggers: choco-hardcoded-internal-url
            $script:installContent | Should -Match 'internal-updates\.corp\.example\.com'
        }
    }
}

Describe 'example-package.nuspec — intentional anti-patterns' -Skip:(-not $script:allExamplesExist) {

    Context 'Unpinned dependencies (Threat Vector 3)' {
        It 'declares chocolatey-core.extension dependency' {
            $script:nuspecContent | Should -Match 'chocolatey-core\.extension'
        }

        It 'uses minimum-version constraint (version="1.0") not exact pin' {
            # Triggers: nuspec-unpinned-dependency, dependency-pin-check
            $script:nuspecContent | Should -Match 'version="1\.0"'
        }

        It 'uses minimum-version constraint (version="6.0") not exact pin' {
            $script:nuspecContent | Should -Match 'version="6\.0"'
        }

        It 'does NOT use exact-pin bracket notation for any dependency' {
            # Exact pin would look like version="[3.2.1]"
            $script:nuspecContent | Should -Not -Match 'version="\['
        }
    }

    Context 'Incomplete metadata' {
        It 'is missing projectUrl element' {
            $script:nuspecContent | Should -Not -Match '<projectUrl>'
        }

        It 'is missing iconUrl element' {
            $script:nuspecContent | Should -Not -Match '<iconUrl>'
        }

        It 'is missing licenseUrl element' {
            $script:nuspecContent | Should -Not -Match '<licenseUrl>'
        }

        It 'is missing tags element' {
            $script:nuspecContent | Should -Not -Match '<tags>'
        }
    }
}

Describe 'VERIFICATION.txt — intentional incompleteness' {
    BeforeAll {
        $script:verifyContent = if (Test-Path $script:verifyPath) {
            Get-Content $script:verifyPath -Raw
        } else { '' }
    }

    It 'VERIFICATION.txt exists (file is present)' {
        Test-Path $script:verifyPath | Should -BeTrue
    }

    It 'VERIFICATION.txt is marked as intentionally incomplete' {
        # The file has an "INTENTIONAL FLAW" marker and no real checksums for actual binaries.
        # It does contain example SHA256 hashes in a documentation section (after "---"),
        # but the real file entries lack checksums — which is exactly the flaw being tested.
        $script:verifyContent | Should -Match 'INTENTIONAL FLAW'
    }

    It 'VERIFICATION.txt lacks a real binary-filename-to-checksum mapping' {
        # A properly completed VERIFICATION.txt would have "FILE 1:" or "FILE 2:" lines
        # paired with a real checksum NOT inside the example documentation block.
        # The intentionally incomplete file has FILE entries only inside the "---" example block.
        # Verify the file does NOT start a FILE entry before the "---" separator.
        $beforeExample = ($script:verifyContent -split '---')[0]
        $beforeExample | Should -Not -Match 'Checksum:\s+[0-9a-fA-F]{64}'
    }
}
