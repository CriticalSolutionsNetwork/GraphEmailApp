function Initialize-GraphEmailApp {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "The 2 to 4 character long prefix ID of the app, files and certs that are created.")]
        [ValidatePattern('^[A-Z]{2,4}$')]
        [string]$Prefix,

        [Parameter(Mandatory = $true, HelpMessage = "The email address of the sender.")]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern("^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$")]
        [String] $UserId
    )

    process {
        # Begin Logging Check
        if (!($script:LogString)) {
            Write-AuditLog -Start
        }
        else {
            Write-AuditLog -BeginFunction
        }
        Write-AuditLog "###############################################"

        # Step 5:
        # Get the MGContext
        $context = Get-MgContext
        # Step 6:
        # Instantiate the user variable.
        $user = Get-MgUser -Filter "Mail eq '$UserId'"
        # Step 7:
        # Define the application Name and Encrypted File Paths.
        $AppName = "$($Prefix)-AuditGraphEmail-$($env:USERDNSDOMAIN)-As-$(($user.UserPrincipalName).Split("@")[0])"
        $graphServicePrincipal = Get-MgServicePrincipal -Filter "DisplayName eq 'Microsoft Graph'"
        $graphResourceId = $graphServicePrincipal.AppId
        Write-AuditLog "Microsoft Graph Service Principal AppId is $graphResourceId"
        # Step 9:
        # Build resource requirements variable using Find-MgGraphCommand -Command New-MgApplication | Select -First 1 -ExpandProperty Permissions
        # Find-MgGraphPermission -PermissionType Application -All | ? {$_.name -eq "Mail.Send"}
        $resId = (Find-MgGraphPermission -PermissionType Application -All | Where-Object { $_.name -eq "Mail.Send" }).Id

        return @{
            "GraphDisplayname"      = $graphServicePrincipal.DisplayName
            "Context"               = $context
            "User"                  = $user
            "AppName"               = $AppName
            "GraphServicePrincipal" = $graphServicePrincipal
            "GraphResourceId"       = $graphResourceId
            "ResId"                 = $resId
        }
        Write-AuditLog -EndFunction
    }
}
