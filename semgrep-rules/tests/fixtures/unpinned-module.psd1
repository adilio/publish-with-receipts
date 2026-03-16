@{
    ModuleVersion = '1.0.0'
    GUID = 'test-guid-1234'
    Author = 'Test'
    Description = 'Test fixture for unpinned module rule'

    # Intentionally unpinned — bare string form
    RequiredModules = @( 'Az.Accounts' )

    FunctionsToExport = @()
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
