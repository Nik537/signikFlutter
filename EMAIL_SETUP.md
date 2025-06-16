# Email Configuration for Signik

## Overview
Signik now automatically sends signed PDFs to nurtaburto@gufum.com. This feature is integrated into the Windows client.

## Default Configuration
- **Recipient**: nurtaburto@gufum.com (hardcoded default)
- **SMTP Server**: smtp.gmail.com (port 587)
- **Authentication**: Required (see setup below)

## Setup Instructions

### 1. Gmail Setup (Recommended)
If using Gmail, you need an app-specific password:
1. Enable 2-factor authentication on your Gmail account
2. Go to https://myaccount.google.com/apppasswords
3. Generate an app password for "Mail"
4. Use this password in the configuration

### 2. Configure Email Settings
The email settings can be configured in the app:
- Username: Your Gmail address
- Password: Your app-specific password
- SMTP Host: smtp.gmail.com
- SMTP Port: 587

### 3. Alternative SMTP Servers
You can use other SMTP servers by updating the configuration:
- **Outlook**: smtp-mail.outlook.com (port 587)
- **Yahoo**: smtp.mail.yahoo.com (port 587)
- **Custom**: Your organization's SMTP server

## How It Works
1. When a PDF is signed on Android and accepted on Windows
2. The signed PDF is saved locally
3. The email service automatically sends the signed PDF to nurtaburto@gufum.com
4. If email fails, the PDF is still saved locally (no data loss)

## Troubleshooting
- **Authentication failed**: Check username/password and ensure app-specific password is used for Gmail
- **Connection timeout**: Verify SMTP server and port settings
- **Email not sent**: Check the app logs for detailed error messages

## Disabling Email
To disable automatic email sending:
- Set `emailEnabled` to false in the app configuration
- Signed PDFs will still be saved locally