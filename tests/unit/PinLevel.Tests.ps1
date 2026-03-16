#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for the Get-PinLevel function.

.DESCRIPTION
    The Get-PinLevel function is used by the dependency-pin-check action to
    classify dependency version constraints as: exact, bounded, minimum, or none.

    Classification rules:
      none    - empty or whitespace (any version resolves)
      bounded - NuGet range notation starting with '[' or '(' (e.g. '[1.0, 2.0)')
      exact   - three-part or four-part semver digit string (e.g. '1.2.3')
      minimum - anything else (e.g. '1.0', '2', '1.2' — treated as minimum-version)

    This test file defines and validates the same algorithm embedded in
    actions/dependency-pin-check/action.yml.
#>

BeforeAll {
    # Define the function under test — same implementation as in action.yml
    function Get-PinLevel {
        param([string]$Version)
        if ([string]::IsNullOrWhiteSpace($Version)) { return 'none' }
        if ($Version -match '^\[' -or $Version -match '^\(') { return 'bounded' }
        if ($Version -match '^\d+\.\d+\.\d+(\.\d+)?$') { return 'exact' }
        return 'minimum'
    }
}

Describe 'Get-PinLevel' {

    Context 'Returns "none" for missing or empty versions' {
        It 'returns none for empty string' {
            Get-PinLevel -Version '' | Should -Be 'none'
        }

        It 'returns none for whitespace-only string' {
            Get-PinLevel -Version '   ' | Should -Be 'none'
        }

        It 'returns none for null' {
            Get-PinLevel -Version $null | Should -Be 'none'
        }
    }

    Context 'Returns "exact" for full semver versions' {
        It 'classifies three-part semver as exact' {
            Get-PinLevel -Version '1.2.3' | Should -Be 'exact'
        }

        It 'classifies four-part version as exact' {
            Get-PinLevel -Version '1.2.3.4' | Should -Be 'exact'
        }

        It 'classifies 0.x.y as exact' {
            Get-PinLevel -Version '0.1.0' | Should -Be 'exact'
        }

        It 'classifies large version numbers as exact' {
            Get-PinLevel -Version '10.20.300' | Should -Be 'exact'
        }

        It 'classifies 1.0.0 as exact (not minimum)' {
            Get-PinLevel -Version '1.0.0' | Should -Be 'exact'
        }

        It 'classifies 2.13.2 (realistic Az.Accounts version) as exact' {
            Get-PinLevel -Version '2.13.2' | Should -Be 'exact'
        }
    }

    Context 'Returns "bounded" for NuGet range notation' {
        It 'classifies exact pin bracket notation as bounded' {
            # NuGet: [1.0] means exactly 1.0
            Get-PinLevel -Version '[1.0]' | Should -Be 'bounded'
        }

        It 'classifies half-open range as bounded' {
            # NuGet: [1.0, 2.0) means >=1.0 and <2.0
            Get-PinLevel -Version '[1.0, 2.0)' | Should -Be 'bounded'
        }

        It 'classifies closed range as bounded' {
            # NuGet: [1.0, 2.0] means >=1.0 and <=2.0
            Get-PinLevel -Version '[1.0, 2.0]' | Should -Be 'bounded'
        }

        It 'classifies exclusive lower bound range as bounded' {
            # NuGet: (1.0, 2.0) means >1.0 and <2.0
            Get-PinLevel -Version '(1.0, 2.0)' | Should -Be 'bounded'
        }

        It 'classifies three-part version in bracket notation as bounded' {
            Get-PinLevel -Version '[1.2.3]' | Should -Be 'bounded'
        }

        It 'classifies range with three-part versions as bounded' {
            Get-PinLevel -Version '[1.3.0, 1.4.0)' | Should -Be 'bounded'
        }
    }

    Context 'Returns "minimum" for loose version constraints' {
        It 'classifies major.minor as minimum' {
            # PowerShell ModuleVersion = "1.0" means minimum 1.0
            Get-PinLevel -Version '1.0' | Should -Be 'minimum'
        }

        It 'classifies major-only as minimum' {
            Get-PinLevel -Version '2' | Should -Be 'minimum'
        }

        It 'classifies major.minor.patch-prerelease as minimum (not standard semver)' {
            # Non-digit suffix prevents exact classification
            Get-PinLevel -Version '1.2.3-beta' | Should -Be 'minimum'
        }

        It 'classifies version with leading v as minimum (not matching digit-only regex)' {
            Get-PinLevel -Version 'v1.2.3' | Should -Be 'minimum'
        }
    }

    Context 'Realistic psd1 and nuspec version examples' {
        It 'ModuleVersion 2.0.0 (minimum, no upper bound) classifies as exact since it is full semver' {
            # ExampleModule.psd1 uses @{ ModuleVersion = '2.0.0' } without RequiredVersion
            # The *version string itself* is exact, but the semantic is minimum.
            # The action handles this at a higher level by checking which key is present.
            # Get-PinLevel only evaluates the version string in isolation.
            Get-PinLevel -Version '2.0.0' | Should -Be 'exact'
        }

        It 'NuGet dependency version "1.0" classifies as minimum' {
            Get-PinLevel -Version '1.0' | Should -Be 'minimum'
        }

        It 'NuGet pinned version "[1.3.0]" classifies as bounded' {
            Get-PinLevel -Version '[1.3.0]' | Should -Be 'bounded'
        }

        It 'NuGet range "[1.3.0, 1.4.0)" classifies as bounded' {
            Get-PinLevel -Version '[1.3.0, 1.4.0)' | Should -Be 'bounded'
        }
    }
}
