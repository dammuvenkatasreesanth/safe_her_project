import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The "< Title" back-navigation header used on Live Tracking and every
/// module sub-screen that isn't part of the bottom-nav tab bar.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onBack,
  });

  final String title;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onBack ?? () => Navigator.of(context).maybePop(),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.chevron_left_rounded, size: 26),
          ),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.calloutBold.copyWith(
              fontSize: 20,
              height: 33 / 20,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
