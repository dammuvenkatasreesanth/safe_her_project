import 'package:flutter/material.dart';
import '../../models/incident.dart';
import '../../services/incident_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_text_field.dart';

extension on IncidentStatus {
  Color get color => switch (this) {
    IncidentStatus.emergency => const Color(0xFFE0334D),
    IncidentStatus.resolved => const Color(0xFF16A34A),
    IncidentStatus.cancelled => AppColors.neutral400,
  };

  String get label => switch (this) {
    IncidentStatus.emergency => 'Emergency',
    IncidentStatus.resolved => 'Resolved',
    IncidentStatus.cancelled => 'Cancelled',
  };
}

extension on Incident {
  IconData get icon => switch (type) {
    IncidentType.sos => Icons.sos_rounded,
    IncidentType.report => Icons.description_outlined,
  };

  String get formattedDate {
    final d = createdAt;
    String two(int n) => n.toString().padLeft(2, '0');
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    return '${two(d.day)}-${two(d.month)}-${d.year} · $hour12:${two(d.minute)} $ampm';
  }
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Incident>>(
      stream: IncidentService.streamIncidents(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load your history. Check your connection.',
                textAlign: TextAlign.center,
                style: AppTextStyles.b3,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return _HistoryContent(
          entries: snapshot.data!,
          filter: _filter,
          onFilterChanged: (f) => setState(() => _filter = f),
          searchController: _searchController,
          onSearchChanged: () => setState(() {}),
          filters: _filters,
        );
      },
    );
  }
}

class _HistoryContent extends StatelessWidget {
  const _HistoryContent({
    required this.entries,
    required this.filter,
    required this.onFilterChanged,
    required this.searchController,
    required this.onSearchChanged,
    required this.filters,
  });

  final List<Incident> entries;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final List<String> filters;

  int get _emergencyCount =>
      entries.where((e) => e.status == IncidentStatus.emergency).length;
  int get _journeyCount =>
      entries.where((e) => e.title.startsWith('Journey')).length;
  int get _resolvedCount =>
      entries.where((e) => e.status == IncidentStatus.resolved).length;

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim().toLowerCase();
    final visible = entries.where((e) {
      final matchesFilter = filter == 'All' || e.status.label == filter;
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
            controller: searchController,
            hint: 'Search your past journeys...',
            prefix: const Icon(
              Icons.search_rounded,
              size: 18,
              color: AppColors.neutral400,
            ),
            onChanged: (_) => onSearchChanged(),
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
              for (final f in filters) ...[
                ChoiceChip(
                  label: Text(f),
                  selected: filter == f,
                  onSelected: (_) => onFilterChanged(f),
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
                  entries.isEmpty
                      ? 'No activity yet.'
                      : 'No matching activity yet.',
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

  final Incident entry;

  @override
  Widget build(BuildContext context) {
    final color = entry.status.color;
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
                color: color,
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
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(entry.icon, size: 20, color: color),
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
                                entry.formattedDate,
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
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  entry.status.label,
                                  style: AppTextStyles.b5.copyWith(
                                    color: color,
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