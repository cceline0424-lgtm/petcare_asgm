import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  static const String _senderEmail = 'ckrn0411@gmail.com';
  static const String _senderAppPassword = 'xrjj bkgt onws itlh';
  static const String _senderName = 'Pet Health Care App';

  static Future<bool> sendOtpEmail({
    required String recipientEmail,
    required String otp,
  }) async {
    final smtpServer = gmail(_senderEmail, _senderAppPassword);

    final message = Message()
      ..from = Address(_senderEmail, _senderName)
      ..recipients.add(recipientEmail)
      ..subject = 'Your Pet Health Care verification code'
      ..text = 'Your verification code is: $otp\n\n'
          'Enter this code in the app to verify your email address. '
          'This code expires once you leave the sign up page.\n\n'
          'If you did not request this, you can safely ignore this email.';

    try {
      await send(message, smtpServer);
      return true;
    } catch (e) {
      print('Failed to send OTP email: $e');
      return false;
    }
  }
}
