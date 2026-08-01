import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The single consistent text-input shell used across the whole app
/// (phone entry, contacts, report, fake call, profile setup) — fixes the
/// old inconsistency where the phone field was noticeably shorter/smaller
/// than every other input.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.hint,
    this.prefix,
    this.keyboardType,
    this.maxLines = 1,
    this.autofocus = false,
    this.onChanged,
  });

  final TextEditingController? controller;
  final String? hint;
  final Widget? prefix;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: maxLines == 1
          ? const BoxConstraints(minHeight: height)
          : null,
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: maxLines == 1 ? 0 : 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        border: Border.all(color: AppColors.neutral300),
        borderRadius: BorderRadius.circular(AppRadius.r5),
      ),
      child: Row(
        crossAxisAlignment: maxLines == 1
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          if (prefix != null) ...[
            prefix!,
            const SizedBox(width: 12),
            Container(width: 1, height: 24, color: AppColors.neutral300),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              autofocus: autofocus,
              onChanged: onChanged,
              style: AppTextStyles.b2,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTextStyles.b2.copyWith(
                  color: AppColors.neutral400,
                ),
                border: InputBorder.none,
                isDense: true,
                isCollapsed: maxLines > 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
