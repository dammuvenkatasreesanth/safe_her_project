import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/user_repository.dart';
import '../../theme/app_theme.dart';
import '../behavior/behavior_monitor_screen.dart';
import '../chatbot/chatbot_screen.dart';
import '../contacts/contacts_screen.dart';
import '../evidence/evidence_screen.dart';
import '../settings/accessibility_screen.dart';
import 'edit_profile_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUser?.uid;
    return StreamBuilder<UserProfile?>(
      stream: uid == null ? null : UserRepository.watchProfile(uid),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = profile?.fullName.trim();
        final displayName = (name == null || name.isEmpty)
            ? 'Your Profile'
            : name;
        final displaySubtitle = profile?.email ?? AuthService.currentUser?.email ?? '';
        final initial = displayName.isNotEmpty
            ? displayName[0].toUpperCase()
            : '?';
        return _ProfileTabBody(
          displayName: displayName,
          displaySubtitle: displaySubtitle,
          initial: initial,
        );
      },
    );
  }
}

class _ProfileTabBody extends StatelessWidget {
  const _ProfileTabBody({
    required this.displayName,
    required this.displaySubtitle,
    required this.initial,
  });

  final String displayName;
  final String displaySubtitle;
  final String initial;

  @override
  Widget build(BuildContext context) {
    final menu = [
      (
        icon: Icons.person_outline_rounded,
        label: 'Personal Details',
        onTap: (BuildContext c) => Navigator.of(
          c,
        ).push(MaterialPageRoute(builder: (_) => const EditProfileScreen())),
      ),
      (
        icon: Icons.contacts_outlined,
        label: 'Trusted Contacts',
        onTap: (BuildContext c) => Navigator.of(
          c,
        ).push(MaterialPageRoute(builder: (_) => const ContactsScreen())),
      ),
      (
        icon: Icons.accessibility_new_rounded,
        label: 'Accessibility',
        onTap: (BuildContext c) => Navigator.of(
          c,
        ).push(MaterialPageRoute(builder: (_) => const AccessibilityScreen())),
      ),
      (
        icon: Icons.smart_toy_outlined,
        label: 'Safety Assistant',
        onTap: (BuildContext c) => Navigator.of(
          c,
        ).push(MaterialPageRoute(builder: (_) => const ChatbotScreen())),
      ),
      (
        icon: Icons.directions_walk_rounded,
        label: 'Behavior Monitor',
        onTap: (BuildContext c) => Navigator.of(c).push(
          MaterialPageRoute(builder: (_) => const BehaviorMonitorScreen()),
        ),
      ),
      (
        icon: Icons.folder_shared_outlined,
        label: 'My Evidence',
        onTap: (BuildContext c) => Navigator.of(
          c,
        ).push(MaterialPageRoute(builder: (_) => const EvidenceScreen())),
      ),
      (
        icon: Icons.help_outline_rounded,
        label: 'Help Center',
        onTap: (BuildContext c) => _comingSoon(c),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(19, 12, 19, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.r4),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: AppTextStyles.h5.copyWith(color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: AppTextStyles.semibold16.copyWith(fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displaySubtitle,
                        style: AppTextStyles.b3.copyWith(
                          color: AppColors.neutral400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.neutral400,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          for (final item in menu)
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.r4),
              onTap: () => item.onTap(context),
              child: Container(
                margin: const EdgeInsets.only(bottom: 11),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.neutral300),
                  borderRadius: BorderRadius.circular(AppRadius.r4),
                ),
                child: Row(
                  children: [
                    Icon(item.icon, size: 20),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        item.label,
                        style: AppTextStyles.semibold16.copyWith(
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.neutral400,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Coming soon')));
  }
}
