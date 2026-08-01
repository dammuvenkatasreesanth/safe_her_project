import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class OnboardingDots extends StatelessWidget {
  const OnboardingDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i != 0) const SizedBox(width: 7),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 9,
            width: i == index ? 33 : 9,
            decoration: BoxDecoration(
              color: i == index ? AppColors.primary : AppColors.dot,
              borderRadius: BorderRadius.circular(34),
            ),
          ),
        ],
      ],
    );
  }
}
