function New-MgGraphContextObject {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'An array of Graph permission names. Defaults to "Mail.Send".'
        )]
        [string[]]$Permissions = @("Mail.Send")
    )
    process {
        if (-not $script:LogString) {
            Write-AuditLog -Start
        }
        else {
            Write-AuditLog -BeginFunction
        }
        try {
            Write-AuditLog '###############################################'
            Write-AuditLog "Retrieving current MgContext..."
            $context = Get-MgContext
            Write-AuditLog "Looking up Microsoft Graph service principal..."
            $graphServicePrincipal = Get-MgServicePrincipal -Filter "DisplayName eq 'Microsoft Graph'"
            if (-not $graphServicePrincipal) {
                throw "Microsoft Graph Service Principal not found!"
            }
            $graphResourceId = $graphServicePrincipal.AppId
            Write-AuditLog "Microsoft Graph Service Principal AppId is $graphResourceId."
            # Collect all found permission IDs
            $resIds = @()
            foreach ($permName in $Permissions) {
                Write-AuditLog "Searching for application permission '$permName'..."
                $foundPerm = Find-MgGraphPermission -PermissionType Application -All | Where-Object { $_.Name -eq $permName }
                if ($foundPerm) {
                    $resIds += $foundPerm.Id
                    Write-AuditLog "Found permission ID for '$permName': $($foundPerm.Id)"
                }
                else {
                    Write-AuditLog -Severity Warning -Message "Permission '$permName' not found!"
                }
            }
            # Build final object
            $result = [PSCustomObject]@{
                GraphDisplayName      = $graphServicePrincipal.DisplayName
                Context               = $context
                GraphServicePrincipal = $graphServicePrincipal
                GraphResourceId       = $graphResourceId
                ResId                 = $resIds
            }
            Write-AuditLog "Returning Graph context object."
            return $result
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
