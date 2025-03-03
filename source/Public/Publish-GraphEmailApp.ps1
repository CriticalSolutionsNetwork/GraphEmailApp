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
        [ValidatePattern('^[A-Fa-f0-9]{40}$')]
        [string]$CertThumbprint,
        [Parameter(Mandatory = $true, HelpMessage = 'The username of the authorized sender.')]
        [ValidatePattern('^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')]
        [string]$AuthorizedSenderUserName,
        [Parameter(Mandatory = $true, HelpMessage = 'The Mail Enabled Sending Group.')]
        [ValidatePattern('^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')]
        [string]$MailEnabledSendingGroup,
        [Parameter(Mandatory = $false, HelpMessage = 'Return the parameter splat for use in other functions.')]
        [switch]$DoNotReturnParamSplat
    )
    begin {
        if (-not $script:LogString) {
            Write-AuditLog -Start
        }
        else {
            Write-AuditLog -BeginFunction
        }
        try {
            Write-AuditLog '###############################################'
            $PublicMods = 'Microsoft.Graph', 'ExchangeOnlineManagement', 'Microsoft.PowerShell.SecretManagement', 'SecretManagement.JustinGrote.CredMan'
            $PublicVers = '1.22.0', '3.1.0', '1.1.2', '1.0.0'
            $ImportMods = 'Microsoft.Graph.Authentication', 'Microsoft.Graph.Applications', 'Microsoft.Graph.Identity.SignIns', 'Microsoft.Graph.Users'
            $ModParams = @{
                PublicModuleNames      = $PublicMods
                PublicRequiredVersions = $PublicVers
                ImportModuleNames      = $ImportMods
                Scope                  = 'CurrentUser'
            }
            Initialize-ModuleEnv @ModParams
            Connect-ToMsService -MgGraph -ExchangeOnline
            # Verify if user exists and store object
            $user = Get-MgUser -Filter "Mail eq '$AuthorizedSenderUserName'"
            if (-not $user) {
                throw "User '$AuthorizedSenderUserName' not found in the tenant."
            }
            $AppSettings = New-MgGraphContextObject -Permissions 'Mail.Send'
            $appName = New-GraphAppName -Prefix $AppPrefix `
                -ScenarioName 'AuditGraphEmail' `
                -UserId $AuthorizedSenderUserName
            $AppSettings | Add-Member -NotePropertyName 'User' -NotePropertyValue $user
            $AppSettings | Add-Member -NotePropertyName 'AppName' -NotePropertyValue $appName
            $CertDetails = Initialize-Certificate `
                -AppName $AppSettings.AppName `
                -Thumbprint $CertThumbprint `
                -Subject "CN=$($AppSettings.AppName)"
        }
        catch {
            $line = $_.InvocationInfo.Line
            $lineNum = $_.InvocationInfo.ScriptLineNumber
            throw [System.Management.Automation.RuntimeException]::new(
                "Error in $($MyInvocation.MyCommand.Name) at line $lineNum`:`n'$line' - $($_.Exception.Message)",
                $_.Exception
            )
        }
    }
    process {
        try {
            # Register App
            $appRegistration = New-EnterpriseAppRegistration `
                -DisplayName $AppSettings.AppName `
                -CertThumbprint $CertDetails.CertThumbprint `
                -ResourceAppId $AppSettings.GraphResourceId `
                -PermissionIds $AppSettings.ResId -SignInAudience 'AzureADMyOrg'
            # Set App Config
            Initialize-GraphAppRegistration `
                -AppRegistration $appRegistration `
                -GraphServicePrincipalId $AppSettings.GraphServicePrincipal.Id `
                -Context $AppSettings.Context `
                -AuthMethod 'Certificate' `
                -CertThumbprint $CertDetails.CertThumbprint `
                -Scopes 'Mail.Send'
            Read-Host 'Provide admin consent now, or copy the url and provide admin consent later. Press Enter to continue.'
            # Exchange Online App Policy
            [void](New-ExchangeEmailAppPolicy -AppRegistration $appRegistration -MailEnabledSendingGroup $MailEnabledSendingGroup)
            # Set App Secret
            $output = [PSCustomObject]@{
                AppId                  = $appRegistration.AppId
                AppName                = "CN=$($AppSettings.AppName)"
                AppRestrictedSendGroup = $MailEnabledSendingGroup
                CertExpires            = ($CertDetails.CertExpires)
                CertThumbprint         = $CertDetails.CertThumbprint
                DefaultDomain          = $MailEnabledSendingGroup.Split('@')[1]
                SendAsUser             = ($AppSettings.User.UserPrincipalName.Split('@')[0])
                SendAsUserEmail        = $AppSettings.User.UserPrincipalName
                TenantID               = $AppSettings.Context.TenantId
            }
            # Store it as JSON in the vault
            $name = Set-JsonSecret -Name "CN=$($AppSettings.AppName)" -InputObject $output -VaultName 'GraphEmailAppLocalStore' -Overwrite
            Write-AuditLog "Secret '$name' saved to vault 'GraphEmailAppLocalStore'."
        }
        catch {
            $line = $_.InvocationInfo.Line
            $lineNum = $_.InvocationInfo.ScriptLineNumber
            throw [System.Management.Automation.RuntimeException]::new(
                "Error in $($MyInvocation.MyCommand.Name) at line $lineNum`:`n'$line' - $($_.Exception.Message)",
                $_.Exception
            )
        }
    }
    end {
        # Return output
        if ($DoNotReturnParamSplat) {
            return $output
        }
        else {
            Write-Output ($output | ConvertTo-ParameterSplat)
        }
    }
}
