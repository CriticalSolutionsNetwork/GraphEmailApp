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
        throw $_.Exception
    }
    Write-AuditLog -EndFunction
}