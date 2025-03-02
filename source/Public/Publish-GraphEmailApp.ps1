<#
    .SYNOPSIS
        Deploys a new Microsoft Graph Email app and associates it with a certificate for app-only authentication.
    .DESCRIPTION
        This cmdlet deploys a new Microsoft Graph Email app and associates it with a certificate for app-only authentication.
        It requires an AppPrefix for the app, an optional CertThumbprint, an AuthorizedSenderUserName, and a MailEnabledSendingGroup.
    .PARAMETER AppPrefix
        A unique prefix for the Graph Email App to initialize. Ensure it is used consistently for grouping purposes.
    .PARAMETER CertThumbprint
        An optional parameter indicating the thumbprint of the certificate to be retrieved. If not specified, a self-signed certificate will be generated.
    .PARAMETER AuthorizedSenderUserName
        The username of the authorized sender.
    .PARAMETER MailEnabledSendingGroup
        The mail-enabled group to which the sender belongs. This will be used to assign app policy restrictions.
    .EXAMPLE
        PS C:\> Publish-GraphEmailApp -AppPrefix "ABC" -AuthorizedSenderUserName "jdoe@example.com" -MailEnabledSendingGroup "GraphAPIMailGroup@example.com" -CertThumbprint "AABBCCDDEEFF11223344556677889900"
    .INPUTS
        None
    .OUTPUTS
        Returns a pscustomobject containing the AppId, CertThumbprint, TenantID, and CertExpires.
    .NOTES
        This cmdlet requires that the user running the cmdlet have the necessary permissions
        to create the app and connect to Exchange Online. In addition, a mail-enabled security
        group must already exist in Exchange Online for the MailEnabledSendingGroup parameter.
#>
function Publish-GraphEmailApp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage = 'The prefix used to initialize the Graph Email App. 2-4 characters letters and numbers only.')]
        [ValidatePattern('^[A-Z0-9]{2,4}$')]
        [string]$AppPrefix,
        [Parameter(Mandatory = $false, HelpMessage = 'The thumbprint of the certificate to be retrieved.')]
        [string]$CertThumbprint,
        [Parameter(Mandatory = $true, HelpMessage = 'The username of the authorized sender.')]
        [string]$AuthorizedSenderUserName,
        [Parameter(Mandatory = $true, HelpMessage = 'The Mail Enabled Sending Group.')]
        [string]$MailEnabledSendingGroup
    )
    $PublicMods = `
        'Microsoft.Graph', 'ExchangeOnlineManagement', `
        'Microsoft.PowerShell.SecretManagement', 'SecretManagement.JustinGrote.CredMan'
    $PublicVers = `
        '1.22.0', '3.1.0', `
        '1.1.2', '1.0.0'
    $ImportMods = `
        'Microsoft.Graph.Authentication', `
        'Microsoft.Graph.Applications', `
        'Microsoft.Graph.Identity.SignIns', `
        'Microsoft.Graph.Users'
    $params1 = @{
        PublicModuleNames      = $PublicMods
        PublicRequiredVersions = $PublicVers
        ImportModuleNames      = $ImportMods
        Scope                  = 'CurrentUser'
    }
    if (!($script:LogString)) {
        Write-AuditLog -Start
    }
    else {
        Write-AuditLog -BeginFunction
    }
    try {
        Write-AuditLog '###############################################'
        Initialize-ModuleEnv @params1
        Connect-ToMsService -MgGraph -ExchangeOnline
        $AppSettings = New-GraphEmailAppContext -Prefix "$AppPrefix" -UserId "$AuthorizedSenderUserName"
        $CertDetails = Initialize-GraphEmailAppCert -AppName $AppSettings.AppName -CertThumbprint $CertThumbprint
        $appRegistration = Register-GraphApp -AppName $AppSettings.AppName -GraphResourceId $AppSettings.graphResourceId -ResID $AppSettings.ResId -CertThumbprint $CertDetails.CertThumbprint
        Set-GraphEmailAppConfig -AppRegistration $appRegistration -GraphServicePrincipalId $AppSettings.GraphServicePrincipal.Id -Context $AppSettings.Context -CertThumbprint $CertDetails.CertThumbprint
        Read-Host 'Provide admin consent now, or copy the url and provide admin consent later. Press Enter to continue.'
        # Call to New-ExchangeEmailAppPolicy
        [void](New-ExchangeEmailAppPolicy -AppRegistration $appRegistration -MailEnabledSendingGroup $MailEnabledSendingGroup)
        $output = Set-AppSecret -AppName $AppSettings.AppName -AppRegistration $appRegistration `
            -CertThumbprint $CertDetails.CertThumbprint -Context $AppSettings.Context -User $AppSettings.User `
            -MailEnabledSendingGroup $MailEnabledSendingGroup -DefaultDomain $MailEnabledSendingGroup.Split('@')[1]
        return $output
    }
    catch {
        $line = $_.InvocationInfo.Line
        $lineNum = $_.InvocationInfo.ScriptLineNumber
        throw [System.Management.Automation.RuntimeException]::new("Error in $($MyInvocation.MyCommand.Name) at line $lineNum`:`n'$line' - $($_.Exception.Message)", $_.Exception)
    }

}