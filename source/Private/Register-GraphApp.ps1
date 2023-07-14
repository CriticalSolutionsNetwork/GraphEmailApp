function Register-GraphApp {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "The name of the application.")]
        [string]$AppName,

        [Parameter(Mandatory = $true, HelpMessage = "The Graph Resource Id.")]
        [string]$GraphResourceId,

        [Parameter(Mandatory = $true, HelpMessage = "The Resource Id.")]
        [string]$ResID,

        [Parameter(Mandatory = $true, HelpMessage = "The Certificate.")]
        [string]$CertThumbPrint
    )
    begin {
        # Begin Logging
        if (!($script:LogString)) {
            Write-AuditLog -Start
        }
        else {
            Write-AuditLog -BeginFunction
        }
        Write-AuditLog "###############################################"
        # Install and import the Microsoft.Graph module. Tested: 1.22.0
    }
    process {
        try {
            Write-AuditLog "Creating app registration..."
            $RequiredResourceAccess = New-Object -TypeName Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
            $RequiredResourceAccess.ResourceAppId = $GraphResourceId
            $RequiredResourceAccess.ResourceAccess += @{ Id = $ResID; Type = "Role" }

            $AppPermissions = New-Object -TypeName System.Collections.Generic.List[Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess]
            $AppPermissions.Add($RequiredResourceAccess)

            Write-AuditLog "App permissions are: $AppPermissions"
            $Cert = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq $CertThumbprint }
            $AppRegistration = New-MgApplication -DisplayName $AppName -SignInAudience "AzureADMyOrg" `
                -Web @{ RedirectUris = "http://localhost"; } `
                -RequiredResourceAccess $RequiredResourceAccess `
                -AdditionalProperties @{} `
                -KeyCredentials @(@{ Type = "AsymmetricX509Cert"; Usage = "Verify"; Key = $Cert.RawData })

            if (!($AppRegistration)) {
                throw "The app creation failed for $($AppName)."
            }
            Write-AuditLog "App registration created with app ID $($AppRegistration.AppId)"
            Start-Sleep 1
        }
        catch {
            throw $_.Exception
        }
        return $AppRegistration
    }
    end {
        Write-AuditLog -EndFunction
    }
}
