// Temporary email configuration for testing
// This file should NOT be committed to version control

class TempEmailConfig {
  // For testing purposes only - this account should have an app-specific password
  static const String testUsername = 'your-test-email@gmail.com';
  static const String testAppPassword = 'your-16-char-app-password';
  
  // Instructions:
  // 1. Create a test Gmail account or use an existing one
  // 2. Enable 2-factor authentication
  // 3. Generate an app-specific password at https://myaccount.google.com/apppasswords
  // 4. Replace the values above
  // 5. Update EmailService constructor in email_service.dart to use these values
  // 6. DELETE this file before committing to version control
}