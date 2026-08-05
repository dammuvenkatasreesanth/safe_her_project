import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/user_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../home/home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  String? _bloodGroup;
  bool _saving = false;

  static const _bloodGroups = ['A+', 'B+', 'O+', 'AB+'];

  Future<void> _finish({required bool markComplete}) async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) {
      _goHome();
      return;
    }
    setState(() => _saving = true);
    try {
      final existing = await UserRepository.getProfile(uid);
      final profile = UserProfile(
        uid: uid,
        phone: existing?.phone ?? AuthService.currentUser?.phoneNumber ?? '',
        fullName: _nameController.text.trim(),
        bloodGroup: _bloodGroup,
        profileComplete: markComplete,
        createdAt: existing?.createdAt,
      );
      await UserRepository.saveProfile(profile);
    } catch (_) {
      // Non-fatal for the demo flow — still let the user in.
    }
    if (!mounted) return;
    _goHome();
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
              const SizedBox(height: 16),
              Text('Build your safety net', style: AppTextStyles.h5),
              const SizedBox(height: 2),
              Text(
                'Takes under a minute. Edit anytime',
                style: AppTextStyles.b3,
              ),
              const SizedBox(height: 34),
              Text('Full Name', style: AppTextStyles.b2),
              const SizedBox(height: 8),
              AppTextField(controller: _nameController, hint: 'Ananya Sharma'),
              const SizedBox(height: 23),
              Text('Blood Group (OPTIONAL)', style: AppTextStyles.b2),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final group in _bloodGroups) ...[
                    GestureDetector(
                      onTap: () => setState(() => _bloodGroup = group),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _bloodGroup == group
                                ? AppColors.primary
                                : AppColors.neutral300,
                          ),
                          color: _bloodGroup == group
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : null,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(group, style: AppTextStyles.b2),
                      ),
                    ),
                    const SizedBox(width: 15),
                  ],
                ],
              ),
              const SizedBox(height: 23),
              Text('Primary Emergency Contact', style: AppTextStyles.b2),
              const SizedBox(height: 15),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.neutral300),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text('+  ADD FROM CONTACTS', style: AppTextStyles.b2),
              ),
              const SizedBox(height: 34),
              PrimaryButton(
                label: _saving ? 'Saving...' : 'Finish Setup',
                onPressed: _saving ? null : () => _finish(markComplete: true),
              ),
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : () => _finish(markComplete: false),
                  child: Text(
                    "I'll do this later",
                    style: AppTextStyles.b4.copyWith(
                      color: AppColors.neutral900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
