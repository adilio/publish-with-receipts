# ExampleModule.psm1 — Root module file
#
# Dot-sources all public functions from the Public/ directory.
# This is a standard pattern for PowerShell module authoring.

$PublicPath = Join-Path $PSScriptRoot 'Public'

Get-ChildItem -Path $PublicPath -Filter '*.ps1' -Recurse | ForEach-Object {
    . $_.FullName
}
