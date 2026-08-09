import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/user_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _isValidEmail => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_emailController.text.trim());

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (!_isValidEmail) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password should be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = "Passwords don't match.");
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final credential = await AuthService.signUp(email: email, password: password);
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
              Text('Create your account', style: AppTextStyles.h5),
              const SizedBox(height: 5),
              Text(
                "We'll use this to keep your safety data secure.",
                style: AppTextStyles.b3,
              ),
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
                hint: 'At least 6 characters',
              ),
              const SizedBox(height: 20),
              Text('Confirm Password', style: AppTextStyles.b2),
              const SizedBox(height: 10),
              AppTextField(
                controller: _confirmController,
                obscureText: true,
                hint: 'Re-enter your password',
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: AppTextStyles.b4.copyWith(color: const Color(0xFFE0334D))),
              ],
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: _submitting
                      ? null
                      : () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          ),
                  child: RichText(
                    text: TextSpan(
                      style: AppTextStyles.b3,
                      children: [
                        const TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Log in',
                          style: AppTextStyles.b3.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'By continuing, you agree to our Terms and Privacy Policy.',
                style: AppTextStyles.b4,
              ),
              const SizedBox(height: 13),
              PrimaryButton(
                label: _submitting ? 'Creating account...' : 'Create Account',
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
