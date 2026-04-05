# Get-PinLevel.ps1
# Shared implementation used by dependency-pin-check and its unit tests.
#
# Classifies a NuGet/PowerShell dependency version string into one of:
#   exact   - three- or four-part semver (e.g. '1.2.3', '1.2.3.4')
#   bounded - NuGet range notation starting with '[' or '(' (e.g. '[1.0, 2.0)')
#   minimum - anything else (e.g. '1.0', '2') — treated as a minimum-version constraint
#   none    - empty or whitespace — no version constraint at all

function Get-PinLevel {
    param([string]$Version)
    if ([string]::IsNullOrWhiteSpace($Version)) { return 'none' }
    # NuGet/nuspec range notation
    if ($Version -match '^\[' -or $Version -match '^\(') { return 'bounded' }
    # Exact three-part semver
    if ($Version -match '^\d+\.\d+\.\d+(\.\d+)?$') { return 'exact' }
    # Anything else (e.g. '1.0', '2') is treated as minimum
    return 'minimum'
}
