#
# Module manifest for module 'ExampleModule'
#
# This manifest contains INTENTIONAL SECURITY ISSUES for demonstration purposes.
# See the talk outline and docs/threat-model.md for details on each flaw.
#

@{
    # --- Identity ---
    ModuleVersion = '1.2.0'
    GUID          = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'

    # --- Authorship ---
    # INTENTIONAL FLAW: Missing CompanyName and Copyright fields.
    # PSScriptAnalyzer will flag incomplete metadata as a best-practice violation.
    Author      = 'Example Author'
    Description = 'An example PowerShell module used to demonstrate supply chain security scanning. Contains intentional anti-patterns.'

    # --- Compatibility ---
    PowerShellVersion = '5.1'

    # --- Dependencies ---
    # INTENTIONAL FLAW: RequiredModules without version pinning.
    # Specifying only ModuleVersion (minimum) means the resolved version can change
    # between builds without any code change on your side — a floating dependency.
    # A pinned version would use: @{ ModuleName = 'Az.Accounts'; RequiredVersion = '2.13.2' }
    RequiredModules = @(
        @{ ModuleName = 'Az.Accounts'; ModuleVersion = '2.0.0' }
    )

    # --- Scripts ---
    # INTENTIONAL FLAW: ScriptsToProcess loads a script into the caller's session scope
    # before the module is imported. This is the same mechanism Aqua Security used in
    # their typosquatting PoC to execute arbitrary code when a module is installed.
    # Legitimate use-cases are rare; this pattern should be flagged for review.
    ScriptsToProcess = @('Initialize-Module.ps1')

    # --- Exports ---
    FunctionsToExport = @(
        'Invoke-SafeFunction',
        'Invoke-UnsafeFunction'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    # --- Metadata ---
    # INTENTIONAL FLAW: Missing ProjectUri, LicenseUri, and ReleaseNotes.
    # These fields enable consumer trust and discoverability on PSGallery.
    # PSScriptAnalyzer PSScriptAnalyzerSettings can be configured to require them.
    PrivateData = @{
        PSData = @{
            Tags = @('Example', 'Demo', 'SupplyChain')
            # ProjectUri  = ''  # Missing
            # LicenseUri  = ''  # Missing
            # ReleaseNotes = '' # Missing
        }
    }
}
