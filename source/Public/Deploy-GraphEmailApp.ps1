    <#
    .SYNOPSIS
    Creates a new Microsoft Graph Email app and associated certificate for app-only authentication.
    .DESCRIPTION
    This cmdlet creates a new Microsoft Graph Email app and associated certificate for app-only authentication.
    It requires a 2 to 4 character long prefix ID for the app, files and certs that are created, as well as the
    email address of the sender and the email of the Group the sender is a part of to assign app policy restrictions.
    .PARAMETER Prefix
    The 2 to 4 character long prefix ID of the app, files and certs that are created. Meant to group multiple runs
    so that if run in different environments, they will stack naturally in Azure. Ensure you use the same prefix each
    time if you'd like this behavior.
    .PARAMETER UserId
    The email address of the sender.
    .PARAMETER MailEnabledSendingGroup
    The email of the Group the sender is a member of to assign app policy restrictions.
    For Example: IT-AuditEmailGroup@contoso.com
    You can create the group using the admin center at https://admin.microsoft.com or you can create it
    using the following commands as an example.
        # Import the ExchangeOnlineManagement module
        Import-Module ExchangeOnlineManagement

        # Create a new mail-enabled security group
        New-DistributionGroup -Name "My Group" -Members "user1@contoso.com", "user2@contoso.com" -MemberDepartRestriction Closed
    .PARAMETER CertThumbprint
    The thumbprint of the certificate to use. If not specified, a self-signed certificate will be generated.
    .EXAMPLE
    PS C:\> New-GraphEmailApp -Prefix ABC -UserId jdoe@example.com -MailEnabledSendingGroup "GraphAPIMailGroup@example.com" -CertThumbprint "9B8B40C5F148B710AD5C0E5CC8D0B71B5A30DB0C"
    .INPUTS
    None
    .OUTPUTS
    Returns a pscustomobject containing the AppId, CertThumbprint, TenantID, and CertExpires.
    .NOTES
    This cmdlet requires that the user running the cmdlet have the necessary permissions
    to create the app and connect to Exchange Online. In addition, a mail-enabled security
    group must already exist in Exchange Online for the MailEnabledSendingGroup parameter.
    .LINK
    https://github.com/CriticalSolutionsNetwork/ADAuditTasks/wiki/New-GraphEmailApp
    .LINK
    https://criticalsolutionsnetwork.github.io/ADAuditTasks/#New-GraphEmailApp
    #>
function Deploy-GraphEmailApp {
    [CmdletBinding()]
    param(

        [Parameter(Mandatory = $true, HelpMessage = "The prefix used to initialize the Graph Email App.")]
        [string]$AppPrefix,

        [Parameter(Mandatory = $false, HelpMessage = "The thumbprint of the certificate to be retrieved.")]
        [string]$CertThumbprint,

        [Parameter(Mandatory = $true, HelpMessage = "The username of the authorized sender.")]
        [string]$AuthorizedSenderUserName,

        [Parameter(Mandatory = $true, HelpMessage = "The Mail Enabled Sending Group.")]
        [string]$MailEnabledSendingGroup
    )

    $PublicMods = `
        "Microsoft.Graph", "ExchangeOnlineManagement", `
        "Microsoft.PowerShell.SecretManagement", "SecretManagement.JustinGrote.CredMan"
    $PublicVers = `
        "1.22.0", "3.1.0", `
        "1.1.2", "1.0.0"
    $ImportMods = `
        "Microsoft.Graph.Authentication", `
        "Microsoft.Graph.Applications", `
        "Microsoft.Graph.Identity.SignIns", `
        "Microsoft.Graph.Users"
    $params1 = @{
        PublicModuleNames      = $PublicMods
        PublicRequiredVersions = $PublicVers
        ImportModuleNames      = $ImportMods
        Scope                  = "CurrentUser"
    }
    if (!($script:LogString)) {
        Write-AuditLog -Start
    }
    else {
        Write-AuditLog -BeginFunction
    }
    Write-AuditLog "###############################################"
    Initialize-ModuleEnv @params1
    Connect-ToMGGraph
    $AppSettings = Initialize-GraphEmailApp -Prefix "$AppPrefix" -UserId "$AuthorizedSenderUserName"

    $CertDetails = Get-GraphEmailAppCert -AppName $AppSettings.AppName -CertThumbprint $CertThumbprint

    $appRegistration = Register-GraphApp -AppName $AppSettings.AppName -GraphResourceId $AppSettings.graphResourceId -ResID $AppSettings.ResId -CertThumbprint $CertDetails.CertThumbprint


    Get-GraphEmailAppConfig -AppRegistration $appRegistration -GraphServicePrincipalId $AppSettings.GraphServicePrincipal.Id -Context $AppSettings.Context -CertThumbprint $CertDetails.CertThumbprint
    Read-Host "Provide admin consent now, or copy the url and provide admin consent later. Press Enter to continue."
    # Call to New-ExchangeEmailAppPolicy

    [void](New-ExchangeEmailAppPolicy -AppRegistration $appRegistration -MailEnabledSendingGroup $MailEnabledSendingGroup)
    $output = Get-AppSecret -AppName $AppSettings.AppName  -AppRegistration $appRegistration -CertThumbprint $CertDetails.CertThumbprint -Context $AppSettings.Context -User $AppSettings.User -MailEnabledSendingGroup $MailEnabledSendingGroup
    return $output
    #>
}