function New-MailEnabledSendingGroup {
    [CmdletBinding(DefaultParameterSetName = 'CustomDomain')]
    param (
        [Parameter(Mandatory = $true, HelpMessage = 'Specifies the name of the mail enabled sending group.')]
        [string]$Name,
        [Parameter(Mandatory = $false, HelpMessage = 'Optional alias for the group. If not provided, the group name will be used.')]
        [string]$Alias,
        [Parameter(Mandatory = $true, ParameterSetName = 'CustomDomain', HelpMessage = 'Specifies the primary SMTP address for the group when using a custom domain.')]
        [string]$PrimarySmtpAddress,
        [Parameter(Mandatory = $true, ParameterSetName = 'DefaultDomain', HelpMessage = 'Specifies the default domain to construct the primary SMTP address (alias@DefaultDomain) for the group.')]
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
        Connect-ToMsService -ExchangeOnline
        if (-not $Alias) {
            $Alias = $Name
        }
        if ($PSCmdlet.ParameterSetName -eq 'DefaultDomain') {
            $PrimarySmtpAddress = "$Alias@$DefaultDomain"
        }
        # Check if the distribution group already exists
        $existingGroup = Get-DistributionGroup -Identity $Name -ErrorAction SilentlyContinue
        if ($existingGroup) {
            Write-AuditLog -Message "Distribution group '$Name' already exists. Returning existing group."
            return $existingGroup
        }
        # Create the distribution group
        $groupParams = @{
            Name               = $Name
            Alias              = $Alias
            PrimarySmtpAddress = $PrimarySmtpAddress
            Type               = 'security'
        }
        Write-AuditLog -Message "Creating distribution group with parameters: `n$($groupParams | Out-String)"
        $group = New-DistributionGroup @groupParams
        Write-AuditLog -Message "Distribution group created: $($group | Out-String)"
        return $group
    }
    catch {
        Write-AuditLog -Severity Error -Message $_.Exception.Message
        $line = $_.InvocationInfo.Line
        $lineNum = $_.InvocationInfo.ScriptLineNumber
        throw [System.Management.Automation.RuntimeException]::new("Error in $($MyInvocation.MyCommand.Name) at line $lineNum`:`n'$line' - $($_.Exception.Message)", $_.Exception)
    }
    finally {
        Write-AuditLog -EndFunction
    }
}
