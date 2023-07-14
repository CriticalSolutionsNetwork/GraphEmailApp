function Get-GraphEmailAppConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "The App Registration object.")]
        $AppRegistration,

        [Parameter(Mandatory = $true, HelpMessage = "The Graph Service Principal Id.")]
        [string]$GraphServicePrincipalId,

        [Parameter(Mandatory = $true, HelpMessage = "The Azure context.")]
        $Context,

        [Parameter(Mandatory = $true, HelpMessage = "The Certificate.")]
        [string]$CertThumbPrint
    )

    begin {
        if (!($script:LogString)) {
            Write-AuditLog -Start
        }
        else {
            Write-AuditLog -BeginFunction
        }
        $Cert = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq $CertThumbprint }
        Write-AuditLog "###############################################"
        Write-AuditLog "Creating service principal for app with AppId $($AppRegistration.AppId)"
    }

    process {
        try {
            # Create a Service Principal for the app.
            New-MgServicePrincipal -AppId $AppRegistration.AppId -AdditionalProperties @{}

            # Get the client Service Principal for the created app.
            $ClientSp = Get-MgServicePrincipal -Filter "appId eq '$($AppRegistration.AppId)'"
            if (!($ClientSp)) {
                Write-AuditLog "Client service Principal not found for $($AppRegistration.AppId)" -Error
                throw "Unable to find Client Service Principal."
            }

            # Build the parameters for the New-MgOauth2PermissionGrant and create the grant.
            $Params = @{
                "ClientId"    = $ClientSp.Id
                "ConsentType" = "AllPrincipals"
                "ResourceId"  = $GraphServicePrincipalId
                "Scope"       = "Mail.Send"
            }
            New-MgOauth2PermissionGrant -BodyParameter $Params -Confirm:$false

            # Create the admin consent url:
            $adminConsentUrl = "https://login.microsoftonline.com/" + $Context.TenantId + "/adminconsent?client_id=" + $AppRegistration.AppId
            Write-Output "Please go to the following URL in your browser to provide admin consent"
            Write-Output $adminConsentUrl
            Write-Output "After providing admin consent, you can use the following values with Connect-MgGraph for app-only authentication:"

            # Generate graph command that can be used to connect later that can be copied and saved.
            $connectGraph = "Connect-MgGraph -ClientId """ + $AppRegistration.AppId + """ -TenantId """`
                + $Context.TenantId + """ -CertificateName """ + $Cert.SubjectName.Name + """"
                Write-Output $connectGraph
        }
        catch {
            throw $_.Exception
        }
        Write-AuditLog -EndFunction
    }
}
