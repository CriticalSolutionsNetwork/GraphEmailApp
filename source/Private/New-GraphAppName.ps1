function New-GraphAppName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,
            HelpMessage='A short prefix for your app name (2-4 alphanumeric chars).')]
        [ValidatePattern('^[A-Z0-9]{2,4}$')]
        [string]$Prefix,
        [Parameter(Mandatory=$false,
            HelpMessage='Optional scenario name (e.g. AuditGraphEmail, MemPolicy, etc.).')]
        [string]$ScenarioName = "GraphApp",
        [Parameter(Mandatory=$false,
            HelpMessage='Optional user email to append "As-[username]" suffix.')]
        [ValidatePattern('^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')]
        [string]$UserId
    )
    begin {
        if (-not $script:LogString) { Write-AuditLog -Start } else { Write-AuditLog -BeginFunction }
    }
    process {
        try {
            Write-AuditLog "Building app name..."
            # Build a user suffix if $UserId is provided
            $userSuffix = ""
            if ($UserId) {
                # e.g. "helpdesk@mydomain.com" -> "As-helpDesk"
                $userPrefix = ($UserId.Split('@')[0])
                $userSuffix = "-As-$userPrefix"
            }
            # Example final: "CORP-AuditGraphEmail-AD.MYDOMAIN.COM-As-helpDesk"
            # But you can do anything you want with $env:USERDNSDOMAIN, etc.
            $domainSuffix = $env:USERDNSDOMAIN
            if (-not $domainSuffix) {
                # fallback if not set
                $domainSuffix = "MyDomain"
            }
            $appName = "$Prefix-$ScenarioName-$domainSuffix$userSuffix"
            Write-AuditLog "Returning app name: $appName"
            return $appName
        }
        catch {
            $line = $_.InvocationInfo.Line
            $lineNum = $_.InvocationInfo.ScriptLineNumber
            throw [System.Management.Automation.RuntimeException]::new(
                "Error in $($MyInvocation.MyCommand.Name) at line $lineNum`:`n'$line' - $($_.Exception.Message)",
                $_.Exception
            )
        }
        finally {
            Write-AuditLog -EndFunction
        }
    }
}
