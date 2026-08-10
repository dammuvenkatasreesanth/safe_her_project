import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/user_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/screen_header.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  String? _bloodGroup;
  String _email = '';
  bool _loading = true;
  bool _saving = false;

  static const _bloodGroups = ['A+', 'B+', 'O+', 'AB+'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = AuthService.currentUser?.uid;
    if (uid != null) {
      final profile = await UserRepository.getProfile(uid);
      if (mounted && profile != null) {
        _nameController.text = profile.fullName;
        setState(() {
          _bloodGroup = profile.bloodGroup;
          _email = profile.email;
        });
      } else if (mounted) {
        setState(() => _email = AuthService.currentUser?.email ?? '');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      final existing = await UserRepository.getProfile(uid);
      final profile = UserProfile(
        uid: uid,
        email: existing?.email ?? _email,
        fullName: _nameController.text.trim(),
        bloodGroup: _bloodGroup,
        profileComplete: true,
        createdAt: existing?.createdAt,
      );
      await UserRepository.saveProfile(profile);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      Navigator.of(context).maybePop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save. Please try again.")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()[0].toUpperCase()
        : '?';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(19, 12, 19, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ScreenHeader(title: 'Edit Profile'),
                    const SizedBox(height: 20),
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: AppTextStyles.h5.copyWith(
                            color: AppColors.primary,
                            fontSize: 36,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text('Full Name', style: AppTextStyles.b2),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _nameController,
                      hint: 'Ananya Sharma',
                    ),
                    const SizedBox(height: 16),
                    Text('Email', style: AppTextStyles.b2),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.fieldFill,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppColors.neutral300),
                      ),
                      child: Text(
                        _email,
                        style: AppTextStyles.b3.copyWith(
                          color: AppColors.neutral400,
                        ),
                      ),
                    ),
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
                    const Spacer(),
                    PrimaryButton(
                      label: _saving ? 'Saving...' : 'Save Changes',
                      onPressed: _saving ? null : _save,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
