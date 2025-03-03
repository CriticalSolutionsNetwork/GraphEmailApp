function Publish-MemPolicyManagerApp {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = '2-4 character prefix used for the App Name (e.g. MSN, CORP, etc.)'
        )]
        [ValidatePattern('^[A-Z0-9]{2,4}$')]
        [string]$Prefix,
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Thumbprint of the certificate. If omitted, a self-signed cert is created.'
        )]
        [ValidatePattern('^[A-Fa-f0-9]{40}$')]
        [string]$CertThumbprint,
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'If specified, use a custom vault name. Otherwise, use the default.'
        )]
        # TODO Change default vault name to 'MemPolicyManagerLocalStore'
        [string]$VaultName = 'GraphEmailAppLocalStore',
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'If specified, overwrite the vault secret if it already exists.'
        )]
        [switch]$OverwriteVaultSecret,
        [Parameter(
            HelpMessage = 'If specified, grant ReadWrite perms. Otherwise, read-only perms.'
        )]
        [switch]$ReadWrite,
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Return the param splat for use in other functions.'
        )]
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
            $PublicMods = 'Microsoft.Graph', 'Microsoft.PowerShell.SecretManagement', 'SecretManagement.JustinGrote.CredMan'
            $PublicVers = '1.22.0', '1.1.2', '1.0.0'
            $ImportMods = 'Microsoft.Graph.Authentication', 'Microsoft.Graph.Applications', 'Microsoft.Graph.Identity.SignIns', 'Microsoft.Graph.Users'
            $ModParams = @{
                PublicModuleNames      = $PublicMods
                PublicRequiredVersions = $PublicVers
                ImportModuleNames      = $ImportMods
                Scope                  = 'CurrentUser'
            }
            Initialize-ModuleEnv @ModParams
            # Only connect to Graph
            Connect-ToMsService -MgGraph
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
            # 1) Determine the correct set of MEM permissions
            #    (We can expand or tweak these as needed)
            $readWritePerms = @(
                'DeviceManagementConfiguration.ReadWrite.All',
                'DeviceManagementApps.ReadWrite.All',
                'DeviceManagementManagedDevices.ReadWrite.All',
                'Policy.ReadWrite.ConditionalAccess',
                'Policy.Read.All'
            )
            $readOnlyPerms = @(
                'DeviceManagementConfiguration.Read.All',
                'DeviceManagementApps.Read.All',
                'DeviceManagementManagedDevices.Read.All',
                'Policy.Read.ConditionalAccess'
                'Policy.Read.All'
            )
            $permissions = if ($ReadWrite) { $readWritePerms } else { $readOnlyPerms }
            Write-AuditLog "Using the following MEM permissions: $($permissions -join ', ')"
            # 2) Build a Graph context object that looks up these permission IDs
            $AppSettings = New-MgGraphContextObject -Permissions $permissions
            # 3) Build an app name for scenario "MemPolicyManager"
            $appName = New-GraphAppName -Prefix $Prefix -ScenarioName 'MemPolicyManager'
            # 4) Add TenantId & AppName to the object so we can store them in the final JSON
            $AppSettings | Add-Member -NotePropertyName 'TenantId' -NotePropertyValue $AppSettings.Context.TenantId
            $AppSettings | Add-Member -NotePropertyName 'AppName' -NotePropertyValue $appName
            # 5) Create or retrieve the certificate
            $CertDetails = Initialize-Certificate `
                -AppName $AppSettings.AppName `
                -Thumbprint $CertThumbprint `
                -Subject "CN=$($AppSettings.AppName)"
            # 6) Register the application (with the cert)
            $appRegistration = New-EnterpriseAppRegistration `
                -DisplayName $AppSettings.AppName `
                -CertThumbprint $CertDetails.CertThumbprint `
                -ResourceAppId $AppSettings.GraphResourceId `
                -PermissionIds $AppSettings.ResId `
                -SignInAudience 'AzureADMyOrg'
            # 7) Create the Service Principal & grant the permissions (Initialize-GraphAppRegistration)
            Initialize-GraphAppRegistration `
                -AppRegistration $appRegistration `
                -GraphServicePrincipalId $AppSettings.GraphServicePrincipal.Id `
                -Context $AppSettings.Context `
                -AuthMethod 'Certificate' `
                -CertThumbprint $CertDetails.CertThumbprint `
                -Scopes $permissions
            # 8) Build a final PSCustomObject to store in the secret vault
            $output = [PSCustomObject]@{
                AppId          = $appRegistration.AppId
                TenantId       = $AppSettings.Context.TenantId
                CertThumbprint = $CertDetails.CertThumbprint
                AppName        = "CN=$($AppSettings.AppName)"
                Permissions    = if ($ReadWrite) { 'ReadWrite' } else { 'ReadOnly' }
                ClientId       = $appRegistration.AppId
            }
            # 9) Store as JSON secret
            $secretName = "CN=$($AppSettings.AppName)"
            $savedName = Set-JsonSecret -Name $secretName -InputObject $output -VaultName $VaultName -Overwrite:$OverwriteVaultSecret
            Write-AuditLog "Secret '$savedName' saved to vault '$VaultName'."
            # Return the final object (param-splat or normal)
            if ($DoNotReturnParamSplat) {
                $output
            }
            else {
                Write-Output ($output | ConvertTo-ParameterSplat)
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
    }
    end {
        Write-AuditLog -EndFunction
    }
}
