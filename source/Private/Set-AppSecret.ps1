function Set-AppSecret {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The application name.'
        )]
        [string]$AppName,
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The app registration object.'
        )]
        [PSObject]$AppRegistration,
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The certificate thumbprint.'
        )]
        [string]$CertThumbprint,
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The context object.'
        )]
        [PSObject]$Context,
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The user object.'
        )]
        [PSObject]$User,
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The mail enabled sending group.'
        )]
        [string]$MailEnabledSendingGroup,
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'The Default Domain'
        )]
        [string]$DefaultDomain
    )
    # Begin Logging
    if (!($script:LogString)) {
        Write-AuditLog -Start
    }
    else {
        Write-AuditLog -BeginFunction
    }
    try {
        $Cert = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq $CertThumbprint }
        if (!(Get-SecretVault -Name GraphEmailAppLocalStore)) {
            Write-AuditLog -Message 'Registering CredMan Secret Vault'
            Register-SecretVault -Name GraphEmailAppLocalStore -ModuleName 'SecretManagement.JustinGrote.CredMan' -ErrorAction Stop
            Write-AuditLog -Message 'Secret Vault: GraphEmailAppLocalStore registered.'
        }
        elseif ((Get-SecretInfo -Name "CN=$AppName" -Vault GraphEmailAppLocalStore)) {
            Write-AuditLog -Message "Secret found! Would you like to delete the previous configuration for `"CN=$AppName.`"?" -Severity Warning
            try {
                Remove-Secret -Name "CN=$AppName" -Vault GraphEmailAppLocalStore -Confirm:$false -ErrorAction Stop
                Write-AuditLog -Message "Previous secret CN=$AppName removed."
            }
            catch {
                throw $_.Exception
            }
        }

        $output = [PSCustomObject]@{
            AppId                  = $AppRegistration.AppId
            AppName                = "CN=$AppName"
            AppRestrictedSendGroup = $MailEnabledSendingGroup
            CertExpires            = ($Cert.NotAfter).ToString('yyyy-MM-dd HH:mm:ss')
            CertThumbprint         = $CertThumbprint
            DefaultDomain          = $DefaultDomain
            SendAsUser             = ($User.UserPrincipalName.Split('@')[0])
            SendAsUserEmail        = $User.UserPrincipalName
            TenantID               = $Context.TenantId
        }
        $SecretJson = $output | ConvertTo-Json -Compress
        Set-Secret -Name "CN=$AppName" -Secret $SecretJson -Vault GraphEmailAppLocalStore -ErrorAction Stop
        Write-AuditLog -Message "Returning output. Save the AppName $("CN=$AppName"). The AppName will be needed to retrieve the secret containing authentication info."
        Write-Host 'You can use the following values as input into the email function!' -ForegroundColor Green
        Write-AuditLog -EndFunction
        # Now simply call ConvertTo-ParameterSplat passing in the output PSObject
        Write-Output ($output | ConvertTo-ParameterSplat)
    }
    catch {
        Write-AuditLog -Severity Error -Message $_.Exception.Message
        $line = $_.InvocationInfo.Line
        $lineNum = $_.InvocationInfo.ScriptLineNumber
        throw [System.Management.Automation.RuntimeException]::new("Error in $($MyInvocation.MyCommand.Name) at line $lineNum`:`n'$line' - $($_.Exception.Message)", $_.Exception)
    }
}
