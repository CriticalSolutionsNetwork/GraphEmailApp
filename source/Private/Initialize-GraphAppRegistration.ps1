function Initialize-GraphAppRegistration {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The App Registration object.'
        )]
        $AppRegistration,
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The Graph Service Principal Id.'
        )]
        [string]$GraphServicePrincipalId,
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The Azure context.'
        )]
        $Context,
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'One or more OAuth2 scopes to grant. Defaults to Mail.Send.'
        )]
        [string[]]$Scopes = @('Mail.Send'),
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Auth method (placeholder). Currently only "Certificate" is used.'
        )]
        [ValidateSet('Certificate','ClientSecret','ManagedIdentity','None')]
        [string]$AuthMethod = 'Certificate',
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Certificate thumbprint if using Certificate-based auth.'
        )]
        [string]$CertThumbprint
    )
    begin {
        if (-not $script:LogString) {
            Write-AuditLog -Start
        }
        else {
            Write-AuditLog -BeginFunction
        }
        Write-AuditLog '###############################################'
        if ($AuthMethod -eq 'Certificate' -and -not $CertThumbprint) {
            throw "CertThumbprint is required when AuthMethod is 'Certificate'."
        }
    }
    process {
        try {
            # 1. If using certificate auth, retrieve the certificate
            $Cert = $null
            if ($AuthMethod -eq 'Certificate') {
                Write-AuditLog "Retrieving certificate with thumbprint $CertThumbprint."
                $Cert = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq $CertThumbprint }
                if (-not $Cert) {
                    throw "Certificate with thumbprint $CertThumbprint not found in Cert:\CurrentUser\My."
                }
            }
            # 2. Create a Service Principal for the app (if not existing).
            Write-AuditLog "Creating service principal for app with AppId $($AppRegistration.AppId)."
            [void](New-MgServicePrincipal -AppId $AppRegistration.AppId -AdditionalProperties @{})
            # 3. Get the client Service Principal for the created app.
            $ClientSp = Get-MgServicePrincipal -Filter "appId eq '$($AppRegistration.AppId)'"
            if (-not $ClientSp) {
                Write-AuditLog "Client service principal not found for $($AppRegistration.AppId)." -Severity Error
                throw "Unable to find client service principal."
            }
            # 4. Grant each scope in $Scopes
            foreach ($scope in $Scopes) {
                Write-AuditLog "Granting '$scope' to Service Principal $($ClientSp.DisplayName)."
                $Params = @{
                    'ClientId'    = $ClientSp.Id
                    'ConsentType' = 'AllPrincipals'
                    'ResourceId'  = $GraphServicePrincipalId
                    'Scope'       = $scope
                }
                [void](New-MgOauth2PermissionGrant -BodyParameter $Params -Confirm:$false)
            }
            # 5. Build the admin consent URL
            $adminConsentUrl = 'https://login.microsoftonline.com/' + $Context.TenantId + '/adminconsent?client_id=' + $AppRegistration.AppId
            Write-Verbose 'Please go to the following URL in your browser to provide admin consent:' -Verbose
            Write-Host $adminConsentUrl -ForegroundColor DarkGray
            Write-Verbose 'After providing admin consent, you can use the following command for certificate-based auth:' -Verbose
            if ($AuthMethod -eq 'Certificate') {
                $connectGraph = 'Connect-MgGraph -ClientId "' + $AppRegistration.AppId + '" -TenantId "'`
                    + $Context.TenantId + '" -CertificateName "' + $Cert.SubjectName.Name + '"'
                Write-Host "`n$connectGraph`n" -ForegroundColor DarkGreen
            }
            else {
                # Placeholder for other auth methods
                Write-Host "Future logic for $AuthMethod auth can go here."
            }
        }
        catch {
            $line = $_.InvocationInfo.Line
            $lineNum = $_.InvocationInfo.ScriptLineNumber
            throw [System.Management.Automation.RuntimeException]::new(
                "Error in $($MyInvocation.MyCommand.Name) at line $lineNum`:`n'$line' - $($_.Exception.Message)",
                $_.Exception
            )
        }
        Write-AuditLog -EndFunction
    }
    end {}
}