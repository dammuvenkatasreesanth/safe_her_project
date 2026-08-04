import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import 'otp_screen.dart';

class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
              const Spacer(),
              Text(
                'By continuing, you agree to our Terms and Privacy Policy.',
                style: AppTextStyles.b4,
              ),
              const SizedBox(height: 13),
              PrimaryButton(
                label: 'Send Code',
                onPressed: () {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const OtpScreen()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
