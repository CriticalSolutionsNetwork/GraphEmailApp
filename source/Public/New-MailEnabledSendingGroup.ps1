function New-MailEnabledSendingGroup {
    [CmdletBinding(DefaultParameterSetName = 'CustomDomain')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Alias,

        [Parameter(Mandatory = $true, ParameterSetName = 'CustomDomain')]
        [string]$PrimarySmtpAddress,

        [Parameter(Mandatory = $true, ParameterSetName = 'DefaultDomain')]
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
        if ($PSCmdlet.ParameterSetName -eq 'DefaultDomain') {
            $PrimarySmtpAddress = "$Alias@$DefaultDomain"
        }

        # Create the distribution group
        $groupParams = @{
            Name               = $Name
            Alias              = $Alias
            PrimarySmtpAddress = $PrimarySmtpAddress
            Type               = "security"
        }
        # Using EXO.
        Write-AuditLog -Message "Creating distribution group with parameters: $($groupParams | Out-String)"
        $group = New-DistributionGroup @groupParams

        Write-AuditLog -Message "Distribution group created: $($group | Out-String)"
        return $group
    }
    catch {
        Write-AuditLog -Severity Error -Message $_.Exception.Message
        throw $_.Exception
    }
    finally {
        Write-AuditLog -EndFunction
    }
}
