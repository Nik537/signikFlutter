import 'dart:io';
import 'dart:typed_data';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../core/utils/logger.dart';
import '../core/exceptions/app_exceptions.dart';
import 'app_config.dart';

class EmailService {
  late SmtpServer _smtpServer;
  final _logger = Logger.tagged('EmailService');
  
  String? _username;
  String? _password;
  String? _smtpHost;
  int? _smtpPort;
  
  EmailService({
    String? username,
    String? password, 
    String? smtpHost,
    int? smtpPort,
  }) {
    _username = username ?? AppConfig.emailUsername;
    _password = password ?? AppConfig.emailPassword;
    _smtpHost = smtpHost ?? AppConfig.emailSmtpHost; 
    _smtpPort = smtpPort ?? AppConfig.emailSmtpPort;
    
    // Only initialize SMTP server if credentials are provided
    if (_username!.isNotEmpty && _password!.isNotEmpty) {
      _initializeSmtpServer();
    }
    
  }
  
  void _initializeSmtpServer() {
    _smtpServer = SmtpServer(
      _smtpHost!,
      port: _smtpPort!,
      username: _username,
      password: _password,
      ssl: false,
      allowInsecure: false,
    );
  }
  
  Future<void> sendSignedDocument({
    required String documentName,
    required Uint8List pdfBytes,
    String? recipient,
    String? customSubject,
    String? customBody,
  }) async {
    if (!AppConfig.emailEnabled) {
      _logger.info('Email sending is disabled');
      return;
    }
    
    if (_username!.isEmpty || _password!.isEmpty) {
      _logger.warning('Email credentials not configured');
      return;
    }
    
    try {
      final toAddress = recipient ?? AppConfig.emailRecipient;
      
      final message = Message()
        ..from = Address(_username!, 'Signik Document System')
        ..recipients.add(toAddress)
        ..subject = customSubject ?? 'Signed Document: $documentName'
        ..text = customBody ?? '''
Dear User,

Your document "$documentName" has been successfully signed.

Please find the signed document attached to this email.

Best regards,
Signik Document System
'''
        ..attachments.add(FileAttachment(
          File(documentName)..writeAsBytesSync(pdfBytes),
          fileName: documentName,
        ));
      
      _logger.info('Sending email to $toAddress with document: $documentName');
      
      final sendReport = await send(message, _smtpServer);
      
      _logger.info('Email sent successfully: ${sendReport.toString()}');
    } catch (e) {
      _logger.error('Failed to send email', error: e);
      throw NetworkException('Failed to send email: $e', originalError: e);
    }
  }
  
  Future<void> updateEmailConfig({
    required String username,
    required String password,
    required String smtpHost,
    required int smtpPort,
  }) async {
    _username = username;
    _password = password;
    _smtpHost = smtpHost;
    _smtpPort = smtpPort;
    
    _initializeSmtpServer();
    
    // Save to app config
    AppConfig.setEmailConfig(
      username: username,
      password: password,
      smtpHost: smtpHost,
      smtpPort: smtpPort,
    );
    await AppConfig.saveEmailSettings();
  }
  
  Future<bool> testConnection() async {
    try {
      final message = Message()
        ..from = Address(_username!, 'Signik Document System')
        ..recipients.add(_username!)
        ..subject = 'Signik Email Test'
        ..text = 'This is a test email from Signik to verify email configuration.';
      
      await send(message, _smtpServer);
      return true;
    } catch (e) {
      _logger.error('Email test failed', error: e);
      return false;
    }
  }
}