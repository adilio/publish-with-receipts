# ConvertTo-Sarif.ps1
# Shared SARIF builder used by ps-script-analysis and Invoke-LocalValidation.
#
# Converts PSScriptAnalyzer result objects into a SARIF 2.1.0 document and
# writes it to the specified output path.
#
# Parameters:
#   Results       - Array of PSScriptAnalyzer DiagnosticRecord objects
#   OutputPath    - File path to write the SARIF JSON
#   WorkspacePath - Optional: prefix to strip from artifact URIs (e.g. $env:GITHUB_WORKSPACE)
#                   When omitted, paths are written as-is (useful for local runs)

function ConvertTo-Sarif {
    param(
        [object[]]$Results,
        [string]$OutputPath,
        [string]$WorkspacePath = ''
    )

    $runs = @(
        @{
            tool    = @{
                driver = @{
                    name           = 'PSScriptAnalyzer'
                    informationUri = 'https://github.com/PowerShell/PSScriptAnalyzer'
                    rules          = @()
                }
            }
            results = @(
                $Results | ForEach-Object {
                    $severity = switch ($_.Severity.ToString()) {
                        'Error'       { 'error' }
                        'Warning'     { 'warning' }
                        'Information' { 'note' }
                        default       { 'note' }
                    }

                    $uri = $_.ScriptPath
                    if ($WorkspacePath -and $WorkspacePath -ne '') {
                        $uri = $uri -replace [regex]::Escape("$WorkspacePath/"), ''
                    }

                    $artifactLocation = @{ uri = $uri }
                    if ($WorkspacePath -and $WorkspacePath -ne '') {
                        $artifactLocation['uriBaseId'] = '%SRCROOT%'
                    }

                    @{
                        ruleId    = $_.RuleName
                        level     = $severity
                        message   = @{ text = $_.Message }
                        locations = @(
                            @{
                                physicalLocation = @{
                                    artifactLocation = $artifactLocation
                                    region           = @{
                                        startLine   = $_.Line
                                        startColumn = $_.Column
                                    }
                                }
                            }
                        )
                    }
                }
            )
        }
    )

    $sarif = @{
        '$schema' = 'https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json'
        version   = '2.1.0'
        runs      = $runs
    }

    $sarif | ConvertTo-Json -Depth 20 | Out-File -FilePath $OutputPath -Encoding utf8
}
