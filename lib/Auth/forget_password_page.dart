import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'database_helper.dart';
import 'email_service.dart';

class ForgetPasswordPage extends StatefulWidget {
  const ForgetPasswordPage({super.key});

  @override
  State<ForgetPasswordPage> createState() => _ForgetPasswordPageState();
}

class _ForgetPasswordPageState extends State<ForgetPasswordPage> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _passwordFocus = FocusNode();
  final RegExp _emailRegex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$');

  bool _emailVerified = false;
  bool _isLoading = false;
  bool _isSendingCode = false;
  bool _isConfirmingCode = false;
  bool _codeSent = false;
  String? _generatedOtp;

  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _showPasswordHints = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));

    _passwordFocus.addListener(() {
      setState(() {
        _showPasswordHints = _passwordFocus.hasFocus || _newPasswordController.text.isNotEmpty;
      });
    });

    _emailController.addListener(() {
      if (_emailVerified || _codeSent) {
        setState(() {
          _emailVerified = false;
          _codeSent = false;
          _generatedOtp = null;
          _otpController.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocus.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  String _generateOtp() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        setState(() => _resendCooldown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendVerificationCode() async {
    if (!_emailFormKey.currentState!.validate()) return;
    final email = _emailController.text.trim();

    setState(() => _isSendingCode = true);

    final user = await DatabaseHelper.instance.getUserByEmail(email);
    if (!mounted) return;

    if (user == null) {
      setState(() => _isSendingCode = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No account found with that email.')));
      return;
    }

    final otp = _generateOtp();
    final sent = await EmailService.sendOtpEmail(recipientEmail: email, otp: otp);

    if (!mounted) return;
    setState(() => _isSendingCode = false);

    if (!sent) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send the verification email. Please try again.')));
      return;
    }

    setState(() {
      _generatedOtp = otp;
      _codeSent = true;
      _otpController.clear();
    });

    _startCooldown();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('A verification code was sent to $email.')));
  }

  Future<void> _confirmVerificationCode() async {
    final entered = _otpController.text.trim();
    if (entered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter the code.')));
      return;
    }

    setState(() => _isConfirmingCode = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _isConfirmingCode = false);

    if (entered != _generatedOtp) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect code. Please try again.')));
      return;
    }

    setState(() {
      _emailVerified = true;
      _codeSent = false;
      _cooldownTimer?.cancel();
    });
  }

  bool _hasMetAllPasswordCriteria() {
    final p = _newPasswordController.text;
    return p.isNotEmpty &&
        p.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(p) &&
        RegExp(r'[0-9]').hasMatch(p) &&
        RegExp(r'''[!@#\$%^&*(),.?":{}|<>_\-+=\[\]/\\~`]''').hasMatch(p);
  }

  Future<void> _resetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;
    if (!_hasMetAllPasswordCriteria()) return;

    setState(() => _isLoading = true);
    await DatabaseHelper.instance.updatePasswordByEmail(_emailController.text.trim(), _newPasswordController.text);
    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset successfully. Please log in.')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.brown[800]!;
    final Color hintColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              IconButton(padding: EdgeInsets.zero, icon: Icon(Icons.arrow_back, color: textColor), onPressed: () => Navigator.of(context).pop()),
              const SizedBox(height: 8),
              Text(_emailVerified ? 'Reset Password' : 'Forget Password', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textColor)),
              const SizedBox(height: 8),
              Text(_emailVerified ? 'Enter and confirm your new password.' : 'Enter the email linked to your account to receive a verification code.', style: TextStyle(color: hintColor, fontSize: 14)),
              const SizedBox(height: 28),
              if (!_emailVerified) _buildEmailStep(isDark, textColor, hintColor),
              if (_emailVerified) _buildResetStep(isDark, textColor, hintColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep(bool isDark, Color textColor, Color hintColor) {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Email address', style: TextStyle(color: hintColor, fontSize: 14)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: textColor),
            enabled: !_codeSent,
            decoration: _fieldDecoration(isDark).copyWith(
              suffixIcon: _isSendingCode
                  ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
                  : TextButton(
                onPressed: (_codeSent || _resendCooldown > 0) ? null : _sendVerificationCode,
                child: Text(_resendCooldown > 0 ? '${_resendCooldown}s' : 'Send Code'),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Please enter your email';
              if (!_emailRegex.hasMatch(value.trim())) return 'Please enter a valid email';
              return null;
            },
          ),

          if (_codeSent) ...[
            const SizedBox(height: 18),
            Text('Verification Code', style: TextStyle(color: hintColor, fontSize: 14)),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                    style: TextStyle(color: textColor, letterSpacing: 4),
                    decoration: _fieldDecoration(isDark).copyWith(hintText: '6-digit code', hintStyle: TextStyle(letterSpacing: 0, color: hintColor)),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[700], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: _isConfirmingCode ? null : _confirmVerificationCode,
                    child: _isConfirmingCode ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text('Confirm'),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: (_isSendingCode || _resendCooldown > 0) ? null : _sendVerificationCode,
                child: Text(_resendCooldown > 0 ? 'Resend code in ${_resendCooldown}s' : 'Resend code', style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResetStep(bool isDark, Color textColor, Color hintColor) {
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New Password', style: TextStyle(color: hintColor, fontSize: 14)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _newPasswordController,
            focusNode: _passwordFocus,
            obscureText: _obscureNewPassword,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            style: TextStyle(color: textColor),
            decoration: _fieldDecoration(isDark).copyWith(
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_hasMetAllPasswordCriteria()) const Icon(Icons.check_circle, color: Colors.green),
                  IconButton(icon: Icon(_obscureNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: hintColor), onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword)),
                ],
              ),
            ),
            validator: (value) => (value == null || value.isEmpty) ? 'Please enter a new password' : null,
          ),
          const SizedBox(height: 8),

          if (_showPasswordHints) ...[
            _buildPasswordHint('Minimum 8 characters', _newPasswordController.text.isNotEmpty && _newPasswordController.text.length >= 8),
            _buildPasswordHint('At least 1 uppercase letter', RegExp(r'[A-Z]').hasMatch(_newPasswordController.text)),
            _buildPasswordHint('At least 1 number', RegExp(r'[0-9]').hasMatch(_newPasswordController.text)),
            _buildPasswordHint('At least 1 special symbol', RegExp(r'''[!@#\$%^&*(),.?":{}|<>_\-+=\[\]/\\~`]''').hasMatch(_newPasswordController.text)),
          ],
          const SizedBox(height: 18),

          Text('Confirm New Password', style: TextStyle(color: hintColor, fontSize: 14)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            style: TextStyle(color: textColor),
            decoration: _fieldDecoration(isDark).copyWith(
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_confirmPasswordController.text.isNotEmpty) Icon(_confirmPasswordController.text == _newPasswordController.text ? Icons.check_circle : Icons.cancel, color: _confirmPasswordController.text == _newPasswordController.text ? Colors.green : Colors.red),
                  IconButton(icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: hintColor), onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)),
                ],
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please confirm your new password';
              if (value != _newPasswordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[700], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: _isLoading ? null : _resetPassword,
              child: _isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text('Reset Password', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordHint(String text, bool isMet) {
    final color = isMet ? Colors.green : Colors.red;
    return Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [Icon(isMet ? Icons.check : Icons.close, size: 16, color: color), const SizedBox(width: 8), Text(text, style: TextStyle(fontSize: 12, color: color))]));
  }

  InputDecoration _fieldDecoration(bool isDark) {
    return InputDecoration(
      filled: true, fillColor: isDark ? Colors.grey[850] : Colors.grey[100], contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.brown.withValues(alpha: 0.2))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.brown, width: 1.5)), errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red, width: 1.5)), focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red, width: 2)),
    );
  }
}