<#
    .SYNOPSIS
        Retrieves or creates a new certificate for the Microsoft Graph Email app.
    .DESCRIPTION
        The Get-GraphEmailAppCert function retrieves a certificate for the specified app from the CurrentUser's certificate store based on the provided thumbprint. 
        If a thumbprint is not provided, it will generate a new self-signed certificate.
    .PARAMETER CertThumbprint
        The thumbprint of the certificate to be retrieved. If not specified, a self-signed certificate will be generated.
    .PARAMETER AppName
        The name of the Graph Email App.
    .EXAMPLE
        PS C:\> Get-GraphEmailAppCert -AppName "MyApp" -CertThumbprint "9B8B40C5F148B710AD5C0E5CC8D0B71B5A30DB0C"
    .EXAMPLE
        PS C:\> Get-GraphEmailAppCert -AppName "MyApp"
    .INPUTS
        None
    .OUTPUTS
        A custom PowerShell object containing the certificate's thumbprint, expiration date, and the associated app's name.
    .NOTES
        The cmdlet requires that the user running the cmdlet have the necessary permissions to create or retrieve certificates from the certificate store.
        The certificate's expiration date is formatted as "yyyy-MM-dd HH:mm:ss".
#>
function Get-GraphEmailAppCert {
    param (
        [string]$CertThumbprint,
        [string]$AppName
    )
    if (!($script:LogString)) {
        Write-AuditLog -Start
    }
    else {
        Write-AuditLog -BeginFunction
    }
    Write-AuditLog "###############################################"
    # Step 10:
    # Create or retrieve certificate from the store.
    try {
        if (!$CertThumbprint) {
            # Create a self-signed certificate for the app.
            $Cert = New-SelfSignedCertificate -Subject "CN=$AppName" -CertStoreLocation "Cert:\CurrentUser\My" -KeyExportPolicy Exportable -KeySpec Signature -KeyLength 2048 -KeyAlgorithm RSA -HashAlgorithm SHA256
            $CertThumbprint = $Cert.Thumbprint
            $CertExpirationDate = $Cert.NotAfter
            $output = [PSCustomObject] @{
                CertThumbprint = $CertThumbprint
                CertExpires    = $certExpirationDate.ToString("yyyy-MM-dd HH:mm:ss")
                AppName        = $AppName
            }
        }
        else {
            # Retrieve the certificate from the CurrentUser's certificate store.
            $Cert = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq $CertThumbprint }
            if (!($Cert)) {
                throw "Certificate with thumbprint $CertThumbprint not found in CurrentUser's certificate store."
            }
            $CertThumbprint = $Cert.Thumbprint
            $CertExpirationDate = $Cert.NotAfter
            $output = [PSCustomObject] @{
                CertThumbprint = $CertThumbprint
                CertExpires    = $certExpirationDate.ToString("yyyy-MM-dd HH:mm:ss")
                AppName        = $AppName
            }
        }
        return $output
    }
    catch {
        # If there is an error, throw an exception with the error message.
        throw $_.Exception
    }
    write-auditlog "Certificate with thumbprint $CertThumbprint created or retrieved from the CurrentUser's certificate store."
    Write-AuditLog -EndFunction
}

