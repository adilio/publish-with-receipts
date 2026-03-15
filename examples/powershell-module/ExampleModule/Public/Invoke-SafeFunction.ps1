function Invoke-SafeFunction {
    <#
    .SYNOPSIS
        Returns a greeting message for the given name.

    .DESCRIPTION
        A clean, well-written exported function that serves as the baseline
        for supply chain security scanning. All patterns here are intentionally
        good: CmdletBinding, parameter validation, no network calls, no secrets,
        proper output via Write-Output.

    .PARAMETER Name
        The name to include in the greeting. Must be a non-empty string.

    .EXAMPLE
        Invoke-SafeFunction -Name 'World'
        # Returns: Hello, World!

    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    process {
        Write-Output "Hello, $Name!"
    }
}
