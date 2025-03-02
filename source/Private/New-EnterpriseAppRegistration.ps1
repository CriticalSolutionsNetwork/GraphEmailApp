function New-EnterpriseAppRegistration {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The display name for the new app registration.'
        )]
        [string]$DisplayName,
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The thumbprint of the certificate used to secure this app.'
        )]
        [string]
        $CertThumbprint,
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The Azure AD resource (e.g., Microsoft Graph AppId).'
        )]
        [string]$ResourceAppId,
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'One or more permission IDs you want to grant. For example, "Mail.Send".'
        )]
        [string[]]$PermissionIds,
        [Parameter(
            HelpMessage = 'The sign-in audience for the app registration.'
        )]
        [ValidateSet('AzureADMyOrg', 'AzureADMultipleOrgs', 'AzureADandPersonalMicrosoftAccount')]
        [string]$SignInAudience = 'AzureADMyOrg'
    )
    # Begin Logging
    if (-not $script:LogString) { Write-AuditLog -Start } else { Write-AuditLog -BeginFunction }
    Write-AuditLog '###############################################'
    try {
        Write-AuditLog "Creating new enterprise app registration for '$DisplayName'."
        # Retrieve the certificate from the CurrentUser store for the app registration
        $Cert = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq $CertThumbprint }
        if (-not $Cert) {
            throw "Certificate with thumbprint $CertThumbprint not found in Cert:\CurrentUser\My."
        }
        # Build the required resource access object
        $requiredResourceAccess = [Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess]::new()
        $requiredResourceAccess.ResourceAppId = $ResourceAppId
        foreach ($permId in $PermissionIds) {
            # Type = 'Role' for Application permissions
            $requiredResourceAccess.ResourceAccess += @{ Id = $permId; Type = 'Role' }
        }
        # Create the new app registration
        $AppRegistration = New-MgApplication -DisplayName $DisplayName `
            -SignInAudience $SignInAudience `
            -RequiredResourceAccess $requiredResourceAccess `
            -AdditionalProperties @{} `
            -KeyCredentials @(
            @{
                Type  = 'AsymmetricX509Cert'
                Usage = 'Verify'
                Key   = $Cert.RawData
            }
        )
        if (-not $AppRegistration) {
            throw "The app creation failed for '$DisplayName'."
        }
        Write-AuditLog "App registration created with app ID $($AppRegistration.AppId)."
        return $AppRegistration
    }
    catch {
        $line = $_.InvocationInfo.Line
        $lineNum = $_.InvocationInfo.ScriptLineNumber
        throw [System.Management.Automation.RuntimeException]::new(
            "Error in $($MyInvocation.MyCommand.Name) at line $lineNum`:`n'$line' - $($_.Exception.Message)",
            $_.Exception
        )
    }
    finally {
        Write-AuditLog -EndFunction
    }
}
