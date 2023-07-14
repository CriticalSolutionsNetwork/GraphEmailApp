Function Get-MgApplicationCertificateAndSecretExpiration {
    <#
    .SYNOPSIS
        This will display all Applications that have certificates or secrets expiring within a certain timeframe
     
     
    .NOTES
        Name: Get-MgApplicationCertificateAndSecretExpiration
        Author: Paul Contreras
        Version: 1.3
        DateCreated: 2022-Feb-8
     
    .LINK
        https://thesysadminchannel.com/get-application-certificate-and-secret-expiration-with-graph-api-powershell -
     
    .EXAMPLE
        Get-MgApplicationCertificateAndSecretExpiration
     
    .EXAMPLE
        Get-MgApplicationCertificateAndSecretExpiration -ShowExpiredKeys
    #>
     
        [CmdletBinding(DefaultParameterSetName='Default')]
        param(
            [Parameter(
                Mandatory = $false,
                ParameterSetName = 'CertOnly'
            )]
            [switch]    $ShowOnlyCertificates,
     
            [Parameter(
                Mandatory = $false,
                ParameterSetName = 'SecretOnly'
            )]
            [switch]    $ShowOnlySecrets,
     
     
            [Parameter(
                Mandatory = $false
            )]
            [switch]    $ShowExpiredKeys,
     
     
            [Parameter(
                Mandatory = $false
            )]
            [ValidateRange(1,720)]
            [int]    $DaysWithinExpiration = 30,
     
     
            [Parameter(
                Mandatory = $false,
                ValueFromPipeline = $true,
                ValueFromPipelineByPropertyName = $true
            )]
            [Alias('ApplicationId', 'ClientId')]
            [string]    $AppId
        )
     
        BEGIN {
            $ConnectionGraph = Get-MgContext
            if (-not $ConnectionGraph) {
                Write-Error "Please connect to Microsoft Graph" -ErrorAction Stop
            }
            #Adding an extra day to account for hour differences and offsets.
            $DaysWithinExpiration++
        }
     
        PROCESS {
            try {
                if ($PSBoundParameters.ContainsKey('AppId')) {
                    $ApplicationList = Get-MgApplication -Filter "AppId eq '$AppId'" -ErrorAction Stop
                    $AppFilter = $true
                } else {
                    $ApplicationList = Get-MgApplication -All -Property AppId, DisplayName, PasswordCredentials, KeyCredentials, Id -PageSize 999 -ErrorAction Stop
                }
     
                #If certs are selected, show certs
                if ($PSBoundParameters.ContainsKey('ShowOnlyCertificates') -or
     
                    #If neither Certs or Secrets are selected show both.
                   (-not $PSBoundParameters.ContainsKey('ShowOnlyCertificates') -and
                    -not $PSBoundParameters.ContainsKey('ShowOnlySecrets'))) {
     
                        $CertificateApps  = $ApplicationList | Where-Object {$_.keyCredentials}
     
                        $CertApp = foreach ($App in $CertificateApps) {
                            foreach ($Cert in $App.keyCredentials) {
                                if ( $Cert.endDateTime -le (Get-Date).AddDays($DaysWithinExpiration) -or ($AppFilter) ) {
                                    [PSCustomObject]@{
                                        AppDisplayName      = $App.DisplayName
                                        AppId               = $App.AppId
                                        KeyType             = 'Certificate'
                                        ExpirationDate      = $Cert.EndDateTime
                                        DaysUntilExpiration = (($Cert.EndDateTime) - (Get-Date) | select -ExpandProperty TotalDays) -as [int]
                                        ThumbPrint          = [System.Convert]::ToBase64String($Cert.CustomKeyIdentifier)
                                        Id                  = $App.Id
                                        KeyId               = $Cert.KeyId
                                        Description         = $Cert.DisplayName
                                    }
                                }
                            }
                        }
     
                        if ($PSBoundParameters.ContainsKey('ShowExpiredKeys')) {
                            $CertApp | Sort-Object DaysUntilExpiration
                        } else {
                            $CertApp | Sort-Object DaysUntilExpiration | Where-Object {$_.DaysUntilExpiration -ge 0}
                        }
                }
     
                #If secrets are selected, show secrets
                if ($PSBoundParameters.ContainsKey('ShowOnlySecrets') -or
     
                    #If neither Certs or Secrets are selected show both.
                   (-not $PSBoundParameters.ContainsKey('ShowOnlySecrets') -and
                    -not $PSBoundParameters.ContainsKey('ShowOnlyCertificates'))) {
     
                        $ClientSecretApps = $ApplicationList | Where-Object {$_.passwordCredentials}
     
                        $SecretApp = foreach ($App in $ClientSecretApps){
                            foreach ($Secret in $App.PasswordCredentials) {
                                if ( $Secret.EndDateTime -le (Get-Date).AddDays($DaysWithinExpiration) -or ($AppFilter) ) {
                                    [PSCustomObject]@{
                                        AppDisplayName      = $App.DisplayName
                                        AppId               = $App.AppId
                                        KeyType             = 'ClientSecret'
                                        ExpirationDate      = $Secret.EndDateTime
                                        DaysUntilExpiration = (($Secret.EndDateTime) - (Get-Date) | select -ExpandProperty TotalDays) -as [int]
                                        ThumbPrint          = 'N/A'
                                        Id                  = $App.Id
                                        KeyId               = $Secret.KeyId
                                        Description         = $Secret.DisplayName
                                    }
                                }
                            }
                        }
     
                        if ($PSBoundParameters.ContainsKey('ShowExpiredKeys')) {
                            $SecretApp | Sort-Object DaysUntilExpiration
                        } else {
                            $SecretApp | Sort-Object DaysUntilExpiration | Where-Object {$_.DaysUntilExpiration -ge 0}
                        }
                }
            } catch {
                Write-Error $_.Exception.Message
            }
        }
     
        END {}
    }