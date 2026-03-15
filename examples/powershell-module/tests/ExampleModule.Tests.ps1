#Requires -Module Pester

# ExampleModule.Tests.ps1
#
# Basic Pester tests for ExampleModule. These tests verify that the module
# loads and its exported functions return the expected output. They are
# intentionally limited to functional testing — they do NOT check for
# supply chain issues like hardcoded secrets, unsafe patterns, or floating
# dependencies. That's the point: passing these tests is not the same as
# having supply chain visibility.

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '..' 'ExampleModule' 'ExampleModule.psd1'
    Import-Module $ModulePath -Force
}

AfterAll {
    Remove-Module ExampleModule -ErrorAction SilentlyContinue
}

Describe 'ExampleModule' {
    Context 'Module loading' {
        It 'imports without error' {
            { Import-Module (Join-Path $PSScriptRoot '..' 'ExampleModule' 'ExampleModule.psd1') -Force } |
                Should -Not -Throw
        }

        It 'exports Invoke-SafeFunction' {
            Get-Command -Module ExampleModule -Name 'Invoke-SafeFunction' |
                Should -Not -BeNullOrEmpty
        }

        It 'exports Invoke-UnsafeFunction' {
            Get-Command -Module ExampleModule -Name 'Invoke-UnsafeFunction' |
                Should -Not -BeNullOrEmpty
        }
    }

    Context 'Invoke-SafeFunction' {
        It 'returns a greeting for the given name' {
            Invoke-SafeFunction -Name 'World' | Should -Be 'Hello, World!'
        }

        It 'accepts pipeline input' {
            'Alice' | Invoke-SafeFunction | Should -Be 'Hello, Alice!'
        }

        It 'throws when Name is empty' {
            { Invoke-SafeFunction -Name '' } | Should -Throw
        }
    }
}

# NOTE: No tests cover Invoke-UnsafeFunction because it makes live network calls.
# This is realistic: teams often skip testing functions that require external
# dependencies, which means the unsafe patterns ship untested and unchallenged.
# The supply chain pipeline catches what functional tests miss.
