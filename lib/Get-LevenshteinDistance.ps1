# Get-LevenshteinDistance.ps1
# Shared implementation used by choco-naming-validation and its unit tests.
#
# Returns the Levenshtein edit distance between two strings (case-insensitive).
# Used to detect potential typosquatting by comparing a new package name against
# existing community repository package names.

function Get-LevenshteinDistance {
    param([string]$Source, [string]$Target)
    $s = $Source.ToLower()
    $t = $Target.ToLower()
    $n = $s.Length
    $m = $t.Length
    if ($n -eq 0) { return $m }
    if ($m -eq 0) { return $n }

    # Use CreateInstance + GetValue/SetValue instead of [int[,]]::new() with
    # indexer syntax — the latter has scope issues when dot-sourced inside
    # Pester BeforeAll blocks.
    $d = [Array]::CreateInstance([int], $n + 1, $m + 1)
    for ($i = 0; $i -le $n; $i++) { $d.SetValue($i, $i, 0) }
    for ($j = 0; $j -le $m; $j++) { $d.SetValue($j, 0, $j) }

    for ($i = 1; $i -le $n; $i++) {
        for ($j = 1; $j -le $m; $j++) {
            $cost     = if ($s[$i - 1] -eq $t[$j - 1]) { 0 } else { 1 }
            $top      = [int]$d.GetValue($i - 1, $j)
            $left     = [int]$d.GetValue($i, $j - 1)
            $diagonal = [int]$d.GetValue($i - 1, $j - 1)
            $val      = [Math]::Min([Math]::Min($top + 1, $left + 1), $diagonal + $cost)
            $d.SetValue($val, $i, $j)
        }
    }
    return [int]$d.GetValue($n, $m)
}
