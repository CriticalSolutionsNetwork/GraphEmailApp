# GraphEmailApp Module Functions

## Connect-ToMGGraph
Connects to Microsoft Graph and Exchange Online.
- **Permissions**: Application.ReadWrite.All, DelegatedPermissionGrant.ReadWrite.All, Directory.ReadWrite.All.
- **Modules**: Microsoft.Graph, ExchangeOnlineManagement, SecretManagement modules.
- **User Interaction**: Requires key press prompts.
- **Outputs**: Connection established, no direct output.

## Publish-GraphEmailApp
Deploys Microsoft Graph Email app with app-only authentication.
- **Parameters**: AppPrefix, CertThumbprint (optional), AuthorizedSenderUserName, MailEnabledSendingGroup.
- **Permissions**: Administrator-level for app and Exchange Online access.
- **Requirements**: Internet connectivity, mail-enabled security group in Exchange Online.
- **Outputs**: Custom object with AppId, CertThumbprint, TenantID, CertExpires.

## Get-GraphEmailAppCert
Retrieves or creates a new certificate.
- **Parameters**: CertThumbprint (optional), AppName.
- **Permissions**: Certificate store access.
- **Outputs**: Custom object with certificate details.

## Send-GraphAppEmail
Sends an email via Microsoft Graph API.
- **Parameters**: AppName, To, FromAddress, Subject, EmailBody, AttachmentPath (optional).
- **Modules**: Microsoft.Graph, MSAL.PS.
- **Requirements**: AppName with necessary permissions and configurations.
- **Outputs**: Email sent, no direct output.
