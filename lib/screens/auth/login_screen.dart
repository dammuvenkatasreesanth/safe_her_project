import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/user_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../home/home_screen.dart';
import 'profile_setup_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isValidEmail => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_emailController.text.trim());

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!_isValidEmail) {
      setState(() {
        _error = 'Enter a valid email address.';
        _info = null;
      });
      return;
    }
    if (password.isEmpty) {
      setState(() {
        _error = 'Enter your password.';
        _info = null;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _info = null;
    });

    try {
      final credential = await AuthService.signIn(email: email, password: password);
      final uid = credential.user!.uid;
      await UserRepository.createIfMissing(uid: uid, email: email);
      if (!mounted) return;
      final profile = await UserRepository.getProfile(uid);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => profile?.profileComplete == true ? const HomeScreen() : const ProfileSetupScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _forgotPassword() async {
    if (!_isValidEmail) {
      setState(() {
        _error = 'Enter your email above first, then tap "Forgot password?".';
        _info = null;
      });
      return;
    }
    try {
      await AuthService.sendPasswordResetEmail(_emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _error = null;
        _info = 'Password reset email sent. Check your inbox.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _info = null;
        _error = e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Could not send reset email.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(27, 20, 27, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 44),
              Text('Welcome back', style: AppTextStyles.h5),
              const SizedBox(height: 5),
              Text('Log in with your email and password.', style: AppTextStyles.b3),
              const SizedBox(height: 34),
              Text('Email', style: AppTextStyles.b2),
              const SizedBox(height: 10),
              AppTextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                hint: 'you@example.com',
              ),
              const SizedBox(height: 20),
              Text('Password', style: AppTextStyles.b2),
              const SizedBox(height: 10),
              AppTextField(
                controller: _passwordController,
                obscureText: true,
                hint: 'Your password',
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _submitting ? null : _forgotPassword,
                child: Text(
                  'Forgot password?',
                  style: AppTextStyles.b4.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: AppTextStyles.b4.copyWith(color: const Color(0xFFE0334D))),
              ],
              if (_info != null) ...[
                const SizedBox(height: 10),
                Text(_info!, style: AppTextStyles.b4.copyWith(color: const Color(0xFF16A34A))),
              ],
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: _submitting
                      ? null
                      : () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const SignupScreen()),
                          ),
                  child: RichText(
                    text: TextSpan(
                      style: AppTextStyles.b3,
                      children: [
                        const TextSpan(text: "Don't have an account? "),
                        TextSpan(
                          text: 'Sign up',
                          style: AppTextStyles.b3.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 34),
              PrimaryButton(
                label: _submitting ? 'Logging in...' : 'Log In',
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
