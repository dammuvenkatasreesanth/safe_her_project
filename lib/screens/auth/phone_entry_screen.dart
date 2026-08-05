import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/user_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../home/home_screen.dart';
import 'otp_screen.dart';
import 'profile_setup_screen.dart';

class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _e164 => '+91${_controller.text.trim()}';

  Future<void> _sendCode() async {
    final digits = _controller.text.trim();
    if (digits.length < 10) {
      setState(() => _error = 'Enter a valid 10-digit mobile number.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });

    await AuthService.sendOtp(
      phoneNumber: _e164,
      onCodeSent: (verificationId) {
        if (!mounted) return;
        setState(() => _sending = false);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpScreen(verificationId: verificationId, phoneNumber: _e164),
          ),
        );
      },
      onAutoVerified: (credential) async {
        // Some Android devices verify the SMS automatically — no code entry needed.
        await UserRepository.createIfMissing(uid: credential.user!.uid, phone: _e164);
        if (!mounted) return;
        _goPostAuth(credential.user!.uid);
      },
      onError: (message) {
        if (!mounted) return;
        setState(() {
          _sending = false;
          _error = message;
        });
      },
    );
  }

  Future<void> _goPostAuth(String uid) async {
    final profile = await UserRepository.getProfile(uid);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => profile?.profileComplete == true ? const HomeScreen() : const ProfileSetupScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(27, 20, 27, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 44),
              Text("What's your number?", style: AppTextStyles.h5),
              const SizedBox(height: 5),
              Text(
                "We'll text you a code to verify it's you.",
                style: AppTextStyles.b3,
              ),
              const SizedBox(height: 34),
              Text('Mobile Number', style: AppTextStyles.b2),
              const SizedBox(height: 10),
              AppTextField(
                controller: _controller,
                keyboardType: TextInputType.phone,
                hint: '93477 89781',
                prefix: Text(
                  '+91',
                  style: AppTextStyles.b2.copyWith(color: AppColors.neutral400),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: AppTextStyles.b4.copyWith(color: const Color(0xFFE0334D))),
              ],
              const Spacer(),
              Text(
                'By continuing, you agree to our Terms and Privacy Policy.',
                style: AppTextStyles.b4,
              ),
              const SizedBox(height: 13),
              PrimaryButton(
                label: _sending ? 'Sending...' : 'Send Code',
                onPressed: _sending ? null : _sendCode,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
