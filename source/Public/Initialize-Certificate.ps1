<#
    .SYNOPSIS
        Retrieves or creates a self-signed certificate in the specified store.
    .DESCRIPTION
        The Initialize-Certificate function either retrieves a certificate by thumbprint from
        the specified store or creates a new self-signed certificate if no thumbprint is provided.
        It returns a PSCustomObject containing the certificate's thumbprint, expiration date,
        and an optional AppName (to maintain compatibility with existing usage).
    .PARAMETER Thumbprint
        The thumbprint of the certificate to retrieve. If omitted, a new self-signed certificate
        is created.
    .PARAMETER AppName
        An optional name for the application or usage context of this certificate.
        This is used to populate the "AppName" property in the returned object if needed.
    .PARAMETER Subject
        The certificate subject, for example: "CN=MyNewAppCert". Defaults to "CN=DefaultSelfSignedCert"
        if no thumbprint is provided.
    .PARAMETER CertStoreLocation
        The certificate store path (e.g., "Cert:\CurrentUser\My" or "Cert:\LocalMachine\My").
        Defaults to "Cert:\CurrentUser\My".
    .EXAMPLE
        # Retrieve an existing cert by thumbprint
        Initialize-Certificate -Thumbprint "9B8B40C5F148B710AD5C0E5CC8D0B71B5A30DB0C"
    .EXAMPLE
        # Create a new self-signed cert for a specific application name
        Initialize-Certificate -AppName "MyGraphApp" -Subject "CN=MyGraphAppCert"
        Returns an object containing AppName, CertThumbprint, and expiration info.
    .OUTPUTS
        PSCustomObject with:
            - CertThumbprint
            - CertExpires
            - AppName      (if provided)
        Preserving compatibility with your existing usage pattern.
    .NOTES
        Author: DrIOSx
        Requires: Write-AuditLog
        The user must have permission to create or retrieve certificates from the specified store.
#>
function Initialize-Certificate {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'The thumbprint of the certificate to retrieve. If omitted, a new self-signed certificate is created.'
        )]
        [string]$Thumbprint,
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'An optional name to store in the output object (e.g., the associated app name).'
        )]
        [string]$AppName,
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'The subject name for the new certificate if no thumbprint is provided.'
        )]
        [string]$Subject = 'CN=DefaultSelfSignedCert',
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'The certificate store location (e.g., "Cert:\CurrentUser\My").'
        )]
        [string]$CertStoreLocation = 'Cert:\CurrentUser\My'
    )
    if (-not $script:LogString) {
        Write-AuditLog -Start
    }
    else {
        Write-AuditLog -BeginFunction
    }
    Write-AuditLog '###############################################'
    try {
        if ($Thumbprint) {
            # Attempt to retrieve an existing certificate
            $Cert = Get-ChildItem -Path $CertStoreLocation | Where-Object { $_.Thumbprint -eq $Thumbprint }
            if (-not $Cert) {
                throw "Certificate with thumbprint $Thumbprint not found in $CertStoreLocation."
            }
            Write-AuditLog "Retrieved certificate with thumbprint $Thumbprint from $CertStoreLocation."
        }
        else {
            # Create a new self-signed certificate
            $Cert = New-SelfSignedCertificate -Subject $Subject -CertStoreLocation $CertStoreLocation `
                -KeyExportPolicy Exportable -KeySpec Signature -KeyLength 2048 -KeyAlgorithm RSA -HashAlgorithm SHA256
            Write-AuditLog "Created new self-signed certificate with subject '$Subject' in $CertStoreLocation."
        }
        $output = [PSCustomObject]@{
            CertThumbprint = $Cert.Thumbprint
            CertExpires    = $Cert.NotAfter.ToString('yyyy-MM-dd HH:mm:ss')
        }
        # Only include AppName if provided (maintaining your original usage pattern)
        if ($AppName) {
            $output | Add-Member -NotePropertyName 'AppName' -NotePropertyValue $AppName
        }
        return $output
    }
    catch {
        $line    = $_.InvocationInfo.Line
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
