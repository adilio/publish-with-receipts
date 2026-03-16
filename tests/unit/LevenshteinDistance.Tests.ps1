#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for the Get-LevenshteinDistance function.

.DESCRIPTION
    The Levenshtein distance algorithm is used by the choco-naming-validation
    action to detect potential typosquatting by comparing package names against
    existing community repo packages.

    This test file defines and validates the same algorithm that is embedded in
    actions/choco-naming-validation/action.yml, ensuring algorithmic correctness
    independent of the GitHub Actions environment.
#>

BeforeAll {
    # Define the function under test — same algorithm as in action.yml.
    # Uses [Array]::CreateInstance and GetValue/SetValue instead of [int[,]]::new()
    # because Pester's BeforeAll scope interacts poorly with [int[,]] indexer syntax.
    function Get-LevenshteinDistance {
        param([string]$Source, [string]$Target)
        $s = $Source.ToLower()
        $t = $Target.ToLower()
        $n = $s.Length
        $m = $t.Length
        if ($n -eq 0) { return $m }
        if ($m -eq 0) { return $n }

        $d = [Array]::CreateInstance([int], $n + 1, $m + 1)
        for ($i = 0; $i -le $n; $i++) { $d.SetValue($i, $i, 0) }
        for ($j = 0; $j -le $m; $j++) { $d.SetValue($j, 0, $j) }

        for ($i = 1; $i -le $n; $i++) {
            for ($j = 1; $j -le $m; $j++) {
                $cost      = if ($s[$i - 1] -eq $t[$j - 1]) { 0 } else { 1 }
                $top       = [int]$d.GetValue($i - 1, $j)
                $left      = [int]$d.GetValue($i, $j - 1)
                $diagonal  = [int]$d.GetValue($i - 1, $j - 1)
                $val = [Math]::Min([Math]::Min($top + 1, $left + 1), $diagonal + $cost)
                $d.SetValue($val, $i, $j)
            }
        }
        return [int]$d.GetValue($n, $m)
    }
}

Describe 'Get-LevenshteinDistance' {

    Context 'Identical strings' {
        It 'returns 0 for identical lowercase strings' {
            Get-LevenshteinDistance -Source 'hello' -Target 'hello' | Should -Be 0
        }

        It 'returns 0 for identical single characters' {
            Get-LevenshteinDistance -Source 'a' -Target 'a' | Should -Be 0
        }

        It 'returns 0 case-insensitively (mixed case)' {
            Get-LevenshteinDistance -Source 'AzTable' -Target 'aztable' | Should -Be 0
        }

        It 'returns 0 case-insensitively (both uppercase)' {
            Get-LevenshteinDistance -Source 'EXAMPLE' -Target 'EXAMPLE' | Should -Be 0
        }
    }

    Context 'Empty string edge cases' {
        It 'returns target length when source is empty' {
            Get-LevenshteinDistance -Source '' -Target 'abc' | Should -Be 3
        }

        It 'returns source length when target is empty' {
            Get-LevenshteinDistance -Source 'abc' -Target '' | Should -Be 3
        }

        It 'returns 0 when both are empty' {
            Get-LevenshteinDistance -Source '' -Target '' | Should -Be 0
        }
    }

    Context 'Single-edit operations' {
        It 'returns 1 for a single insertion' {
            Get-LevenshteinDistance -Source 'abc' -Target 'abcd' | Should -Be 1
        }

        It 'returns 1 for a single deletion' {
            Get-LevenshteinDistance -Source 'abcd' -Target 'abc' | Should -Be 1
        }

        It 'returns 1 for a single substitution' {
            Get-LevenshteinDistance -Source 'abc' -Target 'axc' | Should -Be 1
        }

        It 'is symmetric (source/target swap gives same distance)' {
            $d1 = Get-LevenshteinDistance -Source 'abc' -Target 'axc'
            $d2 = Get-LevenshteinDistance -Source 'axc' -Target 'abc'
            $d1 | Should -Be $d2
        }
    }

    Context 'Multi-edit distances' {
        It 'returns 3 for the classic kitten/sitting example' {
            Get-LevenshteinDistance -Source 'kitten' -Target 'sitting' | Should -Be 3
        }

        It 'returns 3 for saturday/sunday' {
            Get-LevenshteinDistance -Source 'saturday' -Target 'sunday' | Should -Be 3
        }

        It 'returns source length when target is empty (n-edit example)' {
            Get-LevenshteinDistance -Source 'hello' -Target '' | Should -Be 5
        }
    }

    Context 'Typosquatting detection scenarios' {
        It 'detects Az.Table vs AzTable with distance 1 (dot insertion)' {
            # This is the Aqua Security PSGallery research example
            $distance = Get-LevenshteinDistance -Source 'AzTable' -Target 'Az.Table'
            $distance | Should -Be 1
        }

        It 'detects example-pkg vs example-package as close (within threshold 8)' {
            $distance = Get-LevenshteinDistance -Source 'example-pkg' -Target 'example-package'
            $distance | Should -BeLessOrEqual 8
        }

        It 'correctly shows example-pkg is further than threshold 2' {
            # Different enough names should exceed the default threshold of 2
            $distance = Get-LevenshteinDistance -Source 'totally-different' -Target 'unrelated-name'
            $distance | Should -BeGreaterThan 2
        }

        It 'flags common transposition typo: exmaple vs example' {
            # Standard Levenshtein counts transpositions (m↔a swap) as 2 edits.
            # The Damerau-Levenshtein algorithm would return 1, but this implementation
            # uses standard Levenshtein. Both are within the default threshold of 2.
            $distance = Get-LevenshteinDistance -Source 'exmaple' -Target 'example'
            $distance | Should -Be 2
        }

        It 'flags transposition: chocolatey vs chcolatey' {
            $distance = Get-LevenshteinDistance -Source 'chocolatey' -Target 'chcolatey'
            $distance | Should -Be 1
        }

        It 'shows unrelated package names are well beyond threshold 2' {
            $distance = Get-LevenshteinDistance -Source 'git' -Target 'notepadplusplus'
            $distance | Should -BeGreaterThan 2
        }
    }

    Context 'Package naming edge cases' {
        It 'handles hyphenated package names' {
            Get-LevenshteinDistance -Source 'my-package' -Target 'my-packages' | Should -Be 1
        }

        It 'handles dot-separated names' {
            Get-LevenshteinDistance -Source 'Az.Storage' -Target 'Az.Storages' | Should -Be 1
        }

        It 'handles numbers in package names' {
            Get-LevenshteinDistance -Source 'dotnet6' -Target 'dotnet7' | Should -Be 1
        }
    }
}
