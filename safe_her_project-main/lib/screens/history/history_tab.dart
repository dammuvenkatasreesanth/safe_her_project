import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_text_field.dart';

enum _Status { emergency, resolved, cancelled }

class _Entry {
  const _Entry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String date;
  final _Status status;

  Color get color => switch (status) {
    _Status.emergency => const Color(0xFFE0334D),
    _Status.resolved => const Color(0xFF16A34A),
    _Status.cancelled => AppColors.neutral400,
  };

  String get statusLabel => switch (status) {
    _Status.emergency => 'Emergency',
    _Status.resolved => 'Resolved',
    _Status.cancelled => 'Cancelled',
  };
}

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  String _filter = 'All';
  final _searchController = TextEditingController();

  static const _filters = ['All', 'Emergency', 'Resolved', 'Cancelled'];

  static const _entries = [
    _Entry(
      icon: Icons.sos_rounded,
      title: 'SOS Alert — Dhanmondi 32, Dhaka',
      subtitle: 'Alerted Mom, Dad, Priya (Neighbour)',
      date: '29-07-2026 · 9:14 PM',
      status: _Status.emergency,
    ),
    _Entry(
      icon: Icons.alt_route_rounded,
      title: 'Journey: Dhanmondi to Uttara',
      subtitle: '11.4 km · Arrived safely',
      date: '27-07-2026 · 6:02 PM',
      status: _Status.resolved,
    ),
    _Entry(
      icon: Icons.share_location_outlined,
      title: 'Location Shared',
      subtitle: 'With Emergency Help Now',
      date: '24-07-2026 · 8:40 AM',
      status: _Status.resolved,
    ),
    _Entry(
      icon: Icons.phone_in_talk_outlined,
      title: 'Fake Call Triggered',
      subtitle: 'Caller: Mom',
      date: '20-07-2026 · 7:55 PM',
      status: _Status.resolved,
    ),
    _Entry(
      icon: Icons.alt_route_rounded,
      title: 'Journey: Gulshan to Dhanmondi',
      subtitle: 'Cancelled before departure',
      date: '18-07-2026 · 3:12 PM',
      status: _Status.cancelled,
    ),
    _Entry(
      icon: Icons.description_outlined,
      title: 'Incident Reported',
      subtitle: 'Suspicious activity near Road 27',
      date: '14-07-2026 · 10:20 PM',
      status: _Status.resolved,
    ),
  ];

  int get _emergencyCount =>
      _entries.where((e) => e.status == _Status.emergency).length;
  int get _journeyCount =>
      _entries.where((e) => e.title.startsWith('Journey')).length;
  int get _resolvedCount =>
      _entries.where((e) => e.status == _Status.resolved).length;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final visible = _entries.where((e) {
      final matchesFilter = _filter == 'All' || e.statusLabel == _filter;
      final matchesQuery =
          query.isEmpty ||
          e.title.toLowerCase().contains(query) ||
          e.subtitle.toLowerCase().contains(query);
      return matchesFilter && matchesQuery;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(19, 12, 19, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Journey History',
            style: AppTextStyles.calloutBold.copyWith(
              fontSize: 20,
              height: 33 / 20,
            ),
          ),
          const SizedBox(height: 4),
          Text('Your safety activity timeline', style: AppTextStyles.b3),
          const SizedBox(height: 16),
          AppTextField(
            controller: _searchController,
            hint: 'Search your past journeys...',
            prefix: const Icon(
              Icons.search_rounded,
              size: 18,
              color: AppColors.neutral400,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  icon: Icons.alt_route_rounded,
                  value: '$_journeyCount',
                  label: 'Journeys',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.sos_rounded,
                  value: '$_emergencyCount',
                  label: 'Emergency',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.check_circle_outline_rounded,
                  value: '$_resolvedCount',
                  label: 'Resolved',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final f in _filters) ...[
                ChoiceChip(
                  label: Text(f),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                  selectedColor: AppColors.primary.withValues(alpha: 0.12),
                  labelStyle: AppTextStyles.b4,
                  side: const BorderSide(color: AppColors.neutral300),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No matching activity yet.',
                  style: AppTextStyles.b3.copyWith(color: AppColors.neutral400),
                ),
              ),
            ),
          for (final e in visible) _HistoryCard(entry: e),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutral300),
        borderRadius: BorderRadius.circular(AppRadius.r4),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.semibold16.copyWith(fontSize: 18)),
          Text(
            label,
            style: AppTextStyles.b5.copyWith(color: AppColors.neutral400),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutral300),
        borderRadius: BorderRadius.circular(AppRadius.r4),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: entry.color,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(4),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 41,
                      height: 41,
                      decoration: BoxDecoration(
                        color: entry.color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(entry.icon, size: 20, color: entry.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            style: AppTextStyles.semibold16.copyWith(
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            entry.subtitle,
                            style: AppTextStyles.b5,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                entry.date,
                                style: AppTextStyles.b5.copyWith(
                                  color: AppColors.neutral400,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: entry.color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  entry.statusLabel,
                                  style: AppTextStyles.b5.copyWith(
                                    color: entry.color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
