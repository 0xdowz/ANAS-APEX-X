@{
    # Version number of this module.
    ModuleVersion = '1.0.0'

    # ID uniquely identifying this module
    GUID = 'b45c26b5-0c7f-4424-9b5d-16a8fa00ff8e'

    # Author of this module
    Author = 'ANAS APEX X Team'

    # Company or vendor of this module
    CompanyName = 'ANAS APEX X Corporation'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Script module or binary module file associated with this manifest
    RootModule = 'Apex.psm1'

    # Cmdlets to export from this module
    CmdletsToExport = @('Start-Apex')

    # Functions to export from this module
    FunctionsToExport = @('Start-Apex')

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # Private data to pass to the module during Import-Module
    PrivateData = @{
        PSData = @{
            Tags = @('Windows', 'Optimization', 'CLI', 'Performance')
            ProjectUri = 'https://github.com/anas-apex-x'
            LicenseUri = 'https://github.com/anas-apex-x/LICENSE'
        }
    }
}
