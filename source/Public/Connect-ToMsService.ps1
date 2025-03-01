<#
    .SYNOPSIS
        Connects to Microsoft Graph and/or Exchange Online using defined permission scopes.
    .DESCRIPTION
        The Connect-ToServices function is designed to facilitate a connection to Microsoft Graph and Exchange Online.
        It uses modern authentication pop-ups to request the necessary permissions and logs the connection process,
        including any errors encountered. You can choose to connect to Microsoft Graph, Exchange Online, or both via
        the provided switch parameters.

        For Microsoft Graph, the following permission scopes are used:
            - Application.ReadWrite.All
            - DelegatedPermissionGrant.ReadWrite.All
            - Directory.ReadWrite.All

        The function supports ShouldProcess for WhatIf support and additional confirmations as needed.
    .PARAMETER MgGraph
        Indicates that the function should connect to Microsoft Graph. This switch defaults to $true.
    .PARAMETER ExchangeOnline
        Indicates that the function should connect to Exchange Online. This switch defaults to $true.
    .EXAMPLE
        Connect-ToServices
        Executes the function, connecting to both Microsoft Graph and Exchange Online.
    .EXAMPLE
        Connect-ToServices -MgGraph:$false
        Connects only to Exchange Online.
    .EXAMPLE
        Connect-ToServices -ExchangeOnline:$false
        Connects only to Microsoft Graph.
    .INPUTS
        None. You cannot pipe inputs to this function.
    .OUTPUTS
        None. This function does not return any output.
    .NOTES
        Logging is handled by the Write-AuditLog function, which must be available in the scope.
        If an error occurs during the connection process, the function will throw the corresponding exception.
#>
function Connect-ToMsService {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(HelpMessage = 'Connect to Microsoft Graph.')]
        [Switch]$MgGraph,
        [Parameter(HelpMessage = 'Connect to Exchange Online.')]
        [Switch]$ExchangeOnline
    )
    # Begin Logging
    if (-not $script:LogString) { Write-AuditLog -Start } else { Write-AuditLog -BeginFunction }
    Write-AuditLog "###############################################"
    # Connect to Microsoft Graph if selected.
    if ($MgGraph) {
        if ($PSCmdlet.ShouldProcess("Microsoft Graph", "Connecting with scopes Application.ReadWrite.All, DelegatedPermissionGrant.ReadWrite.All, Directory.ReadWrite.All")) {
            try {
                $mgContext = Get-MgContext -ErrorAction SilentlyContinue
                if ($mgContext) {
                    Write-Host "An active Microsoft Graph session is detected:`n$mgContext"
                    $useExisting = Read-Host "Do you want to use the existing Microsoft Graph session? (Y/N)"
                    if ($useExisting -match '^[Yy]') { Write-AuditLog "Using existing Microsoft Graph session." }
                    else {
                        Write-AuditLog "Creating new Microsoft Graph session."
                        Connect-MgGraph -Scopes "Application.ReadWrite.All", "DelegatedPermissionGrant.ReadWrite.All", "Directory.ReadWrite.All" -ErrorAction Stop
                        Write-AuditLog "Connected to Microsoft Graph."
                    }
                }
                else {
                    Write-AuditLog "No existing Microsoft Graph session found. Connecting..."
                    Connect-MgGraph -Scopes "Application.ReadWrite.All", "DelegatedPermissionGrant.ReadWrite.All", "Directory.ReadWrite.All" -ErrorAction Stop
                    Write-AuditLog "Connected to Microsoft Graph."
                }
            }
            catch {
                Write-AuditLog -Severity Error -Message "Error connecting to Microsoft Graph. Error: $($_.Exception.Message)"
                throw $_.Exception
            }
        }
    }
    # Connect to Exchange Online if selected.
    if ($ExchangeOnline) {
        if ($PSCmdlet.ShouldProcess("Exchange Online", "Connecting to ExchangeOnline using modern authentication pop-up.")) {
            try {
                $exoSession = Get-PSSession | Where-Object { $_.Application -like "*ExchangeOnline*" }
                if ($exoSession) {
                    Write-Host "An active Exchange Online session is detected:"
                    $exoSession | Format-Table -AutoSize
                    $useExisting = Read-Host "Do you want to use the existing Exchange Online session? (Y/N)"
                    if ($useExisting -match '^[Yy]') { Write-AuditLog "Using existing Exchange Online session." }
                    else {
                        Disconnect-ExchangeOnline -Confirm:$false
                        Write-AuditLog "Creating new Exchange Online session."
                        Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
                        Write-AuditLog "Connected to Exchange Online."
                    }
                }
                else {
                    Write-AuditLog "No existing Exchange Online session found. Connecting..."
                    Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
                    Write-AuditLog "Connected to Exchange Online."
                }
            }
            catch {
                Write-AuditLog -Severity Error -Message "Error connecting to Exchange Online. Error: $($_.Exception.Message)"
                throw $_.Exception
            }
        }
    }
    Write-AuditLog -EndFunction
}

