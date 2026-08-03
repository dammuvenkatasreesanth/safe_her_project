import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/screen_header.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _descriptionController = TextEditingController();
  String? _type;
  bool _submitted = false;
  bool _photoAttached = false;

  static const _types = ['Harassment', 'Theft', 'Suspicious Activity', 'Other'];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(19, 12, 19, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ScreenHeader(title: 'Report Incident'),
              const SizedBox(height: 12),
              Expanded(
                child: _submitted
                    ? _SuccessView(onDone: () => Navigator.of(context).pop())
                    : _buildForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What happened?', style: AppTextStyles.b2),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final t in _types)
                ChoiceChip(
                  label: Text(t),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                  selectedColor: AppColors.primary.withValues(alpha: 0.12),
                  labelStyle: AppTextStyles.b4,
                  side: const BorderSide(color: AppColors.neutral300),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Description', style: AppTextStyles.b2),
          const SizedBox(height: 10),
          AppTextField(
            controller: _descriptionController,
            maxLines: 4,
            hint: 'Describe what happened...',
          ),
          const SizedBox(height: 20),
          Text('Location', style: AppTextStyles.b2),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.neutral300),
              borderRadius: BorderRadius.circular(AppRadius.r4),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 18),
                const SizedBox(width: 8),
                Text('Dhanmondi 32, Dhaka', style: AppTextStyles.b3),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Evidence', style: AppTextStyles.b2),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() => _photoAttached = !_photoAttached),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.neutral300),
                borderRadius: BorderRadius.circular(AppRadius.r4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _photoAttached
                        ? Icons.check_circle
                        : Icons.add_a_photo_outlined,
                    size: 18,
                    color: _photoAttached ? AppColors.primary : AppColors.black,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _photoAttached ? 'Photo Attached' : 'Add Photo (Optional)',
                    style: AppTextStyles.b3,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          PrimaryButton(
            label: 'Submit Report',
            onPressed: _type == null
                ? null
                : () => setState(() => _submitted = true),
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
        ),
        const SizedBox(height: 20),
        Text(
          'Report Submitted',
          style: AppTextStyles.h5.copyWith(fontSize: 24),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Thank you for helping keep the community safe.\nOur team will review your report shortly.',
          textAlign: TextAlign.center,
          style: AppTextStyles.b3,
        ),
        const Spacer(),
        PrimaryButton(label: 'Done', onPressed: onDone),
      ],
    );
  }
}
