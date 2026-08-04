import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/screen_header.dart';
import 'incoming_call_screen.dart';

class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({super.key});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  final _nameController = TextEditingController(text: 'Mom');
  final _numberController = TextEditingController(text: '+91 98765 43210');
  int _delayIndex = 0;

  static const _presets = [
    (label: 'Mom', icon: Icons.woman_rounded, number: '+91 98765 43210'),
    (label: 'Dad', icon: Icons.man_rounded, number: '+91 98765 43211'),
    (label: 'Boss', icon: Icons.work_rounded, number: '+91 90000 11122'),
    (
      label: 'Friend',
      icon: Icons.emoji_people_rounded,
      number: '+91 76719 76036',
    ),
  ];

  static const _delays = [
    (label: 'Now', seconds: 0, icon: Icons.flash_on_rounded),
    (label: '5 sec', seconds: 5, icon: Icons.timer_3_rounded),
    (label: '30 sec', seconds: 30, icon: Icons.timer_rounded),
    (label: '1 min', seconds: 60, icon: Icons.schedule_rounded),
  ];

  bool _scheduling = false;

  Future<void> _trigger() async {
    final seconds = _delays[_delayIndex].seconds;
    if (seconds == 0) {
      _launchCall();
      return;
    }
    setState(() => _scheduling = true);
    await Future.delayed(Duration(seconds: seconds));
    if (!mounted) return;
    setState(() => _scheduling = false);
    _launchCall();
  }

  void _launchCall() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IncomingCallScreen(
          callerName: _nameController.text.trim().isEmpty
              ? 'Unknown'
              : _nameController.text.trim(),
          callerNumber: _numberController.text.trim(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
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
              const ScreenHeader(title: 'Fake Call'),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CallPreviewCard(
                        name: _nameController.text.trim().isEmpty
                            ? 'Unknown'
                            : _nameController.text.trim(),
                        number: _numberController.text.trim(),
                      ),
                      const SizedBox(height: 24),
                      Text('Caller Name', style: AppTextStyles.b2),
                      const SizedBox(height: 10),
                      AppTextField(
                        controller: _nameController,
                        hint: 'Contact name',
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final p in _presets)
                            _PresetChip(
                              label: p.label,
                              icon: p.icon,
                              selected: _nameController.text == p.label,
                              onTap: () => setState(() {
                                _nameController.text = p.label;
                                _numberController.text = p.number;
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Phone Number', style: AppTextStyles.b2),
                      const SizedBox(height: 10),
                      AppTextField(
                        controller: _numberController,
                        hint: '+91 00000 00000',
                        keyboardType: TextInputType.phone,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 28),
                      Text('Ring after', style: AppTextStyles.b2),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          for (var i = 0; i < _delays.length; i++) ...[
                            if (i != 0) const SizedBox(width: 10),
                            Expanded(
                              child: _DelayOption(
                                label: _delays[i].label,
                                icon: _delays[i].icon,
                                selected: _delayIndex == i,
                                onTap: () => setState(() => _delayIndex = i),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_scheduling) ...[
                Center(
                  child: Text(
                    'Calling in ${_delays[_delayIndex].label}...',
                    style: AppTextStyles.b3.copyWith(
                      color: AppColors.neutral400,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              PrimaryButton(
                label: _scheduling ? 'Scheduled...' : 'Start Fake Call',
                onPressed: _scheduling ? null : _trigger,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallPreviewCard extends StatelessWidget {
  const _CallPreviewCard({required this.name, required this.number});

  final String name;
  final String number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(AppRadius.r6),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const ShapeDecoration(
              color: Color(0xFF0B5C6B),
              shape: StarBorder(
                points: 14,
                innerRadiusRatio: 0.92,
                pointRounding: 0.5,
                valleyRounding: 0.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            number.isEmpty ? 'Incoming call...' : number,
            style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.white,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.neutral300,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppColors.primary : AppColors.black,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.b4.copyWith(
                color: selected ? AppColors.primary : AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DelayOption extends StatelessWidget {
  const _DelayOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.neutral300,
          ),
          borderRadius: BorderRadius.circular(AppRadius.r4),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : AppColors.black,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.b5.copyWith(
                color: selected ? Colors.white : AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
