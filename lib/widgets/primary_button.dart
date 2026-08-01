import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The orange CTA button used across every SafeHer screen.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.height = 57,
    this.radius = AppRadius.r6,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double radius;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: outlined ? Colors.white : AppColors.primary,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onPressed,
          child: Container(
            decoration: outlined
                ? BoxDecoration(
                    border: Border.all(color: AppColors.primary),
                    borderRadius: BorderRadius.circular(radius),
                  )
                : null,
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppTextStyles.b1.copyWith(
                color: outlined ? AppColors.black : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
