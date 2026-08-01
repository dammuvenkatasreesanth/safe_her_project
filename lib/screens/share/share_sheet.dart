import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

Future<void> showShareSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r6)),
    ),
    builder: (context) => const _ShareSheetContent(),
  );
}

class _ShareSheetContent extends StatelessWidget {
  const _ShareSheetContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 15, 26, 23),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 57,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.dot,
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 39,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.neutral200),
                    borderRadius: BorderRadius.circular(AppRadius.r4),
                  ),
                  child: Text(
                    'Write Message (Optional)',
                    style: AppTextStyles.b3.copyWith(
                      color: AppColors.neutral300,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Container(
                width: 114,
                height: 39,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.r4),
                ),
                child: Text(
                  'Share Now',
                  style: AppTextStyles.b3.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Send to trusted contact',
            style: AppTextStyles.semibold16.copyWith(
              fontSize: 18,
              height: 33 / 18,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i != 0) const SizedBox(width: 14),
                _ContactAvatar(),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Send in SafeHer',
            style: AppTextStyles.semibold16.copyWith(
              fontSize: 18,
              height: 33 / 18,
            ),
          ),
          const SizedBox(height: 7),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 6,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, i) => const _PlainAvatar(),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Share to',
            style: AppTextStyles.semibold16.copyWith(
              fontSize: 18,
              height: 33 / 18,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              _ShareIcon(
                icon: Icons.sms_outlined,
                color: const Color(0xFF34C759),
              ),
              const SizedBox(width: 14),
              _ShareIcon(
                icon: Icons.email_outlined,
                color: const Color(0xFF3478F6),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactAvatar extends StatelessWidget {
  const _ContactAvatar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 55,
      height: 55,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary),
              image: const DecorationImage(
                image: AssetImage('assets/images/avatar_shape.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            right: -2,
            top: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 11, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlainAvatar extends StatelessWidget {
  const _PlainAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(
          image: AssetImage('assets/images/avatar_shape.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _ShareIcon extends StatelessWidget {
  const _ShareIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white),
    );
  }
}
