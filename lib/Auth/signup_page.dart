import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database_helper.dart';
import 'email_service.dart';
import 'login_page.dart';

const String _phoneCountryCode = '+60';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();

  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _showPasswordHints = false;

  bool _isUsernameValid = false;
  bool _isUsernameTaken = false;
  Timer? _usernameDebounce;

  bool _isPhoneValid = false;
  bool _isPhoneTaken = false;
  Timer? _phoneDebounce;

  bool _emailVerified = false;
  bool _isSendingCode = false;
  bool _isConfirmingCode = false;
  bool _codeSent = false;
  String? _generatedOtp;

  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  final RegExp _emailRegex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$');

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
    _phoneController.addListener(_onPhoneChanged);
    _passwordController.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));

    _passwordFocus.addListener(() {
      setState(() {
        _showPasswordHints = _passwordFocus.hasFocus || _passwordController.text.isNotEmpty;
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
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    _passwordFocus.dispose();
    _usernameDebounce?.cancel();
    _phoneDebounce?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _onUsernameChanged() {
    if (_usernameDebounce?.isActive ?? false) _usernameDebounce!.cancel();
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      final username = _usernameController.text.trim();
      if (username.isEmpty) {
        setState(() => _isUsernameValid = false);
        return;
      }
      final isTaken = await DatabaseHelper.instance.isUsernameTaken(username);
      setState(() {
        _isUsernameTaken = isTaken;
        _isUsernameValid = !isTaken;
      });
    });
  }

  void _onPhoneChanged() {
    if (_phoneDebounce?.isActive ?? false) _phoneDebounce!.cancel();
    _phoneDebounce = Timer(const Duration(milliseconds: 500), () async {
      final phone = _phoneController.text.trim();
      if (phone.isEmpty || phone.length < 9 || phone.length > 10) {
        setState(() => _isPhoneValid = false);
        return;
      }
      final fullPhone = '$_phoneCountryCode$phone';
      final isTaken = await DatabaseHelper.instance.isPhoneTaken(fullPhone);
      setState(() {
        _isPhoneTaken = isTaken;
        _isPhoneValid = !isTaken;
      });
    });
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
    final email = _emailController.text.trim();

    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid email address first.')));
      return;
    }

    setState(() => _isSendingCode = true);

    final taken = await DatabaseHelper.instance.isEmailTaken(email);
    if (!mounted) return;

    if (taken) {
      setState(() => _isSendingCode = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That email is already registered.')));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter the code sent to your email.')));
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email verified.')));
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please verify your email address first.')));
      return;
    }
    if (!_hasMetAllPasswordCriteria()) return;

    setState(() => _isLoading = true);

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final phone = '$_phoneCountryCode${_phoneController.text.trim()}';

    UserCredential? credential;
    try {
      credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );

      await credential.user?.updateDisplayName(username);

      await DatabaseHelper.instance.createUserProfile(
        uid: credential.user!.uid,
        name: username,
        username: username,
        email: email,
        phone: phone,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created! Please log in.')));
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
    } on FirebaseAuthException catch (e) {
      await credential?.user?.delete();

      setState(() => _isLoading = false);
      String message = 'Could not create account. Please try again.';
      if (e.code == 'email-already-in-use') message = 'That email is already registered.';
      if (e.code == 'weak-password') message = 'Password is too weak.';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      await credential?.user?.delete();
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Username or Phone is already in use.')));
      }
    }
  }

  bool _hasMetAllPasswordCriteria() {
    final p = _passwordController.text;
    return p.isNotEmpty &&
        p.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(p) &&
        RegExp(r'[0-9]').hasMatch(p) &&
        RegExp(r'''[!@#\$%^&*(),.?":{}|<>_\-+=\[\]/\\~`]''').hasMatch(p);
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Row(
                  children: [
                    IconButton(padding: EdgeInsets.zero, icon: Icon(Icons.arrow_back, color: textColor), onPressed: () => Navigator.of(context).pop()),
                    const SizedBox(width: 4),
                    Text('Sign Up', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                  ],
                ),
                Divider(color: isDark ? Colors.grey[700] : Colors.grey[300]),
                const SizedBox(height: 16),

                _buildLabel('Username', hintColor),
                TextFormField(
                  controller: _usernameController,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  style: TextStyle(color: textColor),
                  decoration: _inputDeco(isDark).copyWith(
                    suffixIcon: _isUsernameValid ? const Icon(Icons.check_circle, color: Colors.green) : null,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Please enter a username';
                    if (_isUsernameTaken) return 'Username is already taken';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                _buildLabel('Email address', hintColor),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  enabled: !_emailVerified && !_codeSent,
                  style: TextStyle(color: textColor),
                  decoration: _inputDeco(isDark).copyWith(
                    suffixIcon: _emailVerified
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : (_isSendingCode
                        ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
                        : TextButton(
                      onPressed: (_codeSent || _resendCooldown > 0) ? null : _sendVerificationCode,
                      child: Text(_resendCooldown > 0 ? '${_resendCooldown}s' : 'Send Code'),
                    )),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Please enter your email';
                    if (!_emailRegex.hasMatch(value.trim())) return 'Please enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  _emailVerified ? 'Email verified.' : (_codeSent ? 'Enter the 6-digit code we emailed you.' : 'Tap "Send Code" to receive a verification code by email.'),
                  style: TextStyle(fontSize: 12, color: _emailVerified ? Colors.green : hintColor),
                ),

                if (_codeSent && !_emailVerified) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                          style: TextStyle(color: textColor, letterSpacing: 4),
                          decoration: _inputDeco(isDark).copyWith(hintText: '6-digit code', hintStyle: TextStyle(letterSpacing: 0, color: hintColor)),
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
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: (_isSendingCode || _resendCooldown > 0) ? null : _sendVerificationCode,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: Text(_resendCooldown > 0 ? 'Resend code in ${_resendCooldown}s' : 'Resend code', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                _buildLabel('Phone Number', hintColor),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 48,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: isDark ? Colors.grey[850] : Colors.grey[100], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.brown.withValues(alpha: 0.2))),
                      child: Text('🇲🇾  $_phoneCountryCode', style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: TextStyle(color: textColor),
                        decoration: _inputDeco(isDark).copyWith(
                          hintText: '123456789',
                          suffixIcon: _isPhoneValid ? const Icon(Icons.check_circle, color: Colors.green) : null,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Please enter your phone number';
                          if (value.trim().length < 9 || value.trim().length > 10) return 'Invalid phone number (9-10 digits)';
                          if (_isPhoneTaken) return 'Phone number already registered';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                _buildLabel('Password', hintColor),
                TextFormField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  obscureText: _obscurePassword,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  style: TextStyle(color: textColor),
                  decoration: _inputDeco(isDark).copyWith(
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_hasMetAllPasswordCriteria()) const Icon(Icons.check_circle, color: Colors.green),
                        IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: hintColor), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
                      ],
                    ),
                  ),
                  validator: (value) => (value == null || value.isEmpty) ? 'Please enter a password' : null,
                ),
                const SizedBox(height: 8),

                if (_showPasswordHints) ...[
                  _buildPasswordHint('Minimum 8 characters', _passwordController.text.isNotEmpty && _passwordController.text.length >= 8),
                  _buildPasswordHint('At least 1 uppercase letter', RegExp(r'[A-Z]').hasMatch(_passwordController.text)),
                  _buildPasswordHint('At least 1 number', RegExp(r'[0-9]').hasMatch(_passwordController.text)),
                  _buildPasswordHint('At least 1 special symbol', RegExp(r'''[!@#\$%^&*(),.?":{}|<>_\-+=\[\]/\\~`]''').hasMatch(_passwordController.text)),
                ],
                const SizedBox(height: 18),

                _buildLabel('Confirm Password', hintColor),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  style: TextStyle(color: textColor),
                  decoration: _inputDeco(isDark).copyWith(
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_confirmPasswordController.text.isNotEmpty) Icon(_confirmPasswordController.text == _passwordController.text ? Icons.check_circle : Icons.cancel, color: _confirmPasswordController.text == _passwordController.text ? Colors.green : Colors.red),
                        IconButton(icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: hintColor), onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)),
                      ],
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please confirm your password';
                    if (value != _passwordController.text) return 'Confirm password is not same as the password input';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[700], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: _isLoading ? null : _handleSignUp,
                    child: _isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text('Sign Up', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordHint(String text, bool isMet) {
    final color = isMet ? Colors.green : Colors.red;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [Icon(isMet ? Icons.check : Icons.close, size: 16, color: color), const SizedBox(width: 8), Text(text, style: TextStyle(fontSize: 12, color: color))]),
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text, style: TextStyle(color: color, fontSize: 14)));
  }

  InputDecoration _inputDeco(bool isDark) {
    return InputDecoration(
      filled: true, fillColor: isDark ? Colors.grey[850] : Colors.grey[100], contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.brown.withValues(alpha: 0.2))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.brown, width: 1.5)), errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red, width: 1.5)), focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red, width: 2)),
    );
  }
}