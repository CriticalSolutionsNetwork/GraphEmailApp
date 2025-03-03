<#
    .SYNOPSIS
        Creates a new enterprise application registration in Azure AD with a specified certificate.
    .DESCRIPTION
        The New-EnterpriseAppRegistration function creates a new Azure AD application registration (sometimes called
        an enterprise app) using Microsoft Graph. It sets the sign-in audience, attaches a certificate for authentication,
        and configures one or more application permission IDs for the specified resource (e.g., Microsoft Graph).
        Logging is handled by the Write-AuditLog function, and the newly created application object is returned.
    .PARAMETER DisplayName
        The display name for the new app registration.
    .PARAMETER CertThumbprint
        The thumbprint of the certificate used to secure this app, located in the CurrentUser certificate store.
    .PARAMETER ResourceAppId
        The Azure AD resource (for example, the Microsoft Graph app ID: 00000003-0000-0000-c000-000000000000).
    .PARAMETER PermissionIds
        One or more permission IDs (application permissions) to grant for the resource. For example, "Mail.Send".
    .PARAMETER SignInAudience
        The sign-in audience for the app registration. Valid values are "AzureADMyOrg", "AzureADMultipleOrgs",
        and "AzureADandPersonalMicrosoftAccount". Defaults to "AzureADMyOrg".
    .EXAMPLE
        PS C:\> New-EnterpriseAppRegistration -DisplayName "MyEnterpriseApp" -CertThumbprint "AABBCCDDEEFF1122" -ResourceAppId "00000003-0000-0000-c000-000000000000" -PermissionIds "Mail.Send"
        Creates a new Azure AD application named "MyEnterpriseApp", attaches the specified certificate, targets the Microsoft Graph
        resource (AppId 00000003-0000-0000-c000-000000000000), and grants the "Mail.Send" permission.
    .INPUTS
        None. You cannot pipe input to this function.
    .OUTPUTS
        Microsoft.Graph.PowerShell.Models.MicrosoftGraphApplication
        Returns the newly created Azure AD application registration object.
    .NOTES
        Author: DrIOSx
        Requires: Microsoft.Graph PowerShell module, Write-AuditLog function
        The user must have permissions in Azure AD to create and manage applications.
#>
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
