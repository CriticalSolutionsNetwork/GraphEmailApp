<#
    .SYNOPSIS
        Connects to Microsoft Graph and Exchange Online using defined permission scopes.
    .DESCRIPTION
        The Connect-ToMGGraph function is designed to facilitate a connection to Microsoft Graph and Exchange Online.
        It uses modern authentication pop-up, requesting the user to grant permissions. It logs the process of
        connection, including any errors that might occur.

        The function operates on three permission scopes for Microsoft Graph:
        - Application.ReadWrite.All
        - DelegatedPermissionGrant.ReadWrite.All
        - Directory.ReadWrite.All

        Note: It is necessary to press Enter at each prompt to proceed with the connection or you can cancel by pressing ctrl+c.
    .PARAMETERS
        The function does not take any parameters.
    .EXAMPLE
        Connect-ToMGGraph
        Executes the function, initiating the connection process to Microsoft Graph and Exchange Online.
    .INPUTS
        None. You cannot pipe inputs to this function.
    .OUTPUTS
        None. This function does not return any output.
    .NOTES
        Logging details are handled by the Write-AuditLog function, which needs to be available in the scope.
        If any error occurs during the connection process, the function will throw the corresponding exception.
#>
function Connect-ToMGGraph {
    # Begin Logging
    if (!($script:LogString)) {
        Write-AuditLog -Start
    }
    else {
        Write-AuditLog -BeginFunction
    }
    Write-AuditLog "###############################################"

    # Step 4:
    Read-Host "Press Enter to connect to Microsoft Graph scopes Application.ReadWrite.All, DelegatedPermissionGrant.ReadWrite.All, and  Directory.ReadWrite.All, or press ctrl+c to cancel " -ErrorAction Stop
    # Connect to MSGraph with the appropriate permission scopes and then Exchange.
    Write-AuditLog "Connecting to MgGraph and ExchangeOnline using modern authentication pop-up."
    try {
        Write-AuditLog "Connecting to MgGraph with scopes Application.ReadWrite.All, DelegatedPermissionGrant.ReadWrite.All, and  Directory.ReadWrite.All."
        Connect-MgGraph -Scopes "Application.ReadWrite.All", "DelegatedPermissionGrant.ReadWrite.All", "Directory.ReadWrite.All"
        Write-AuditLog "Connected to MgGraph"
        Read-Host "Press Enter to connect to ExchangeOnline" -ErrorAction Stop
        Connect-ExchangeOnline -ErrorAction Stop
        Write-AuditLog "Connected to ExchangeOnline."
        Read-Host "Press Enter to continue" -ErrorAction Stop
    }
    catch {
        Write-AuditLog -Severity Error -Message "Error connecting to MgGraph or ExchangeOnline. Error: $($_.Exception.Message)"
        throw $_.Exception
    }
    Write-AuditLog -EndFunction
}