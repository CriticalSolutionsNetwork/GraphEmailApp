function Get-AppSecret {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "The application name.")]
        [string]$AppName,

        [Parameter(Mandatory = $true, HelpMessage = "The app registration object.")]
        [PSObject]$AppRegistration,

        [Parameter(Mandatory = $true, HelpMessage = "The certificate thumbprint.")]
        [string]$CertThumbprint,

        [Parameter(Mandatory = $true, HelpMessage = "The context object.")]
        [PSObject]$Context,

        [Parameter(Mandatory = $true, HelpMessage = "The user object.")]
        [PSObject]$User,

        [Parameter(Mandatory = $true, HelpMessage = "The mail enabled sending group.")]
        [string]$MailEnabledSendingGroup
    )

    # Begin Logging
    if (!($script:LogString)) {
        Write-AuditLog -Start
    }
    else {
        Write-AuditLog -BeginFunction
    }
    $Cert = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq $CertThumbprint }
    if (!(Get-SecretVault -Name GraphEmailAppLocalStore)) {
        try {
            Write-AuditLog -Message "Registering CredMan Secret Vault"
            Register-SecretVault -Name GraphEmailAppLocalStore -ModuleName "SecretManagement.JustinGrote.CredMan" -ErrorAction Stop
            Write-AuditLog -Message "Secret Vault: GraphEmailAppLocalStore registered."
        }
        catch {
            throw $_.Exception
        }
    }
    elseif ((Get-SecretInfo -Name "CN=$AppName" -Vault GraphEmailAppLocalStore) ) {
        Write-AuditLog -Message "Secret found! Would you like to delete the previous configuration for `"CN=$AppName.`"?" -Severity Warning
        try {
            Remove-Secret -Name "CN=$AppName" -Vault GraphEmailAppLocalStore -Confirm:$false -ErrorAction Stop
            Write-AuditLog -Message "Previous secret CN=$AppName removed."
        }
        catch {
            throw $_.Exception
        }
    }

    $output = [PSCustomObject] @{
        AppId                  = $AppRegistration.AppId
        CertThumbprint         = $CertThumbprint
        TenantID               = $Context.TenantId
        CertExpires            = ($Cert.NotAfter).ToString("yyyy-MM-dd HH:mm:ss")
        SendAsUser             = $($User.UserPrincipalName.Split("@")[0])
        AppRestrictedSendGroup = $MailEnabledSendingGroup
        Appname               = "CN=$AppName"
    }

    $delimiter = '|'
    $joinedString = ($output.PSObject.Properties.Value) -join $delimiter

    try {
        Set-Secret -Name "CN=$AppName" -Secret $joinedString -Vault GraphEmailAppLocalStore -ErrorAction Stop
    }
    catch {
        throw $_.Exception
    }

    Write-AuditLog -Message "Returning output. Save the AppName $("CN=$AppName"). The AppName will be needed to retreive the secret containing authentication info."

    Write-Host "You can use the following values as input into the email function!" -ForegroundColor Green
    Write-AuditLog -EndFunction
    $output | ForEach-Object {
        $hashTable = @{}
        $_.psobject.properties | ForEach-Object {
            $hashTable[$_.Name] = $_.Value
        }

        # Convert hashtable to script text
        $splatScript = "`$params = @{`n"
        $hashTable.Keys | ForEach-Object {
            $value = $hashTable[$_]
            if ($value -is [string]) {
                $value = "`"$value`""
            }
            $splatScript += "    $_ = $value`n"
        }
        $splatScript += "}"

        Write-Output $splatScript
    }
}
