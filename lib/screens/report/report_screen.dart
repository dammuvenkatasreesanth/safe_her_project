import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/geocoding_service.dart';
import '../../services/incident_service.dart';
import '../../services/location_service.dart';
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
  bool _submitting = false;
  bool _photoAttached = false;
  String? _error;

  LatLng? _location;
  String _locationLabel = 'Locating...';
  bool _locating = true;

  static const _types = ['Harassment', 'Theft', 'Suspicious Activity', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final point = await LocationService.getCurrentLocation();
    String label;
    if (point == null) {
      label = 'Location unavailable';
    } else {
      label = await GeocodingService.reverse(point) ??
          '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
    }
    if (!mounted) return;
    setState(() {
      _location = point;
      _locationLabel = label;
      _locating = false;
    });
  }

  Future<void> _submit() async {
    if (_type == null || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await IncidentService.submitReport(
        category: _type!,
        description: _descriptionController.text.trim(),
        locationLabel: _locationLabel,
        locationLatLng: _location,
        hasPhoto: _photoAttached,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not submit report. Check your connection and try again.';
      });
    }
  }

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
                Expanded(
                  child: _locating
                      ? Text('Locating...', style: AppTextStyles.b3)
                      : Text(
                          _locationLabel,
                          style: AppTextStyles.b3,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
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
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: AppTextStyles.b4.copyWith(color: const Color(0xFFE0334D)),
            ),
          ],
          const SizedBox(height: 28),
          PrimaryButton(
            label: _submitting ? 'Submitting...' : 'Submit Report',
            onPressed: (_type == null || _submitting) ? null : _submit,
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