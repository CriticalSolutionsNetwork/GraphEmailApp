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

