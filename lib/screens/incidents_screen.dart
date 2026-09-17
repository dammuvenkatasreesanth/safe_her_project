import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/incident.dart';
import '../services/admin_data_service.dart';
import '../theme.dart';

enum _TypeFilter { all, sos, safetyEvent, report }

/// Covers both "Reports" and "SOS Activities" from the admin requirement —
/// they're the same underlying `incidents` collection, filtered by type,
/// rather than two separate screens/queries.
class IncidentsScreen extends StatefulWidget {
  const IncidentsScreen({super.key});

  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  _TypeFilter _typeFilter = _TypeFilter.all;
  String _query = '';
  final _dateFormat = DateFormat('d MMM y, h:mm a');

  bool _matchesType(Incident i) {
    switch (_typeFilter) {
      case _TypeFilter.all:
        return true;
      case _TypeFilter.sos:
        return i.type == IncidentType.sos && !i.isAutomaticSafetyEvent;
      case _TypeFilter.safetyEvent:
        return i.isAutomaticSafetyEvent;
      case _TypeFilter.report:
        return i.type == IncidentType.report;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Incident>>(
      stream: AdminDataService.streamRecentIncidents(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Could not load incidents: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        final q = _query.trim().toLowerCase();
        final rows = snap.data!.where(_matchesType).where((i) {
          if (q.isEmpty) return true;
          return i.title.toLowerCase().contains(q) ||
              i.subtitle.toLowerCase().contains(q) ||
              i.reporterId.toLowerCase().contains(q) ||
              (i.locationLabel ?? '').toLowerCase().contains(q);
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Reports & SOS Activity', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.dark)),
              const SizedBox(height: 4),
              const Text('Every SOS alert, incident report, and automatic safety event, across all users.', style: TextStyle(color: AppColors.neutral900)),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search_rounded, size: 18),
                        hintText: 'Search title, reporter id, location...',
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  for (final f in _TypeFilter.values)
                    ChoiceChip(
                      label: Text(_labelFor(f)),
                      selected: _typeFilter == f,
                      onSelected: (_) => setState(() => _typeFilter = f),
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: rows.isEmpty
                    ? const Center(child: Text('No matching incidents.', style: TextStyle(color: AppColors.neutral400)))
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.neutral200),
                        ),
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(AppColors.surface),
                            columns: const [
                              DataColumn(label: Text('When')),
                              DataColumn(label: Text('Type')),
                              DataColumn(label: Text('Title')),
                              DataColumn(label: Text('Reporter (uid)')),
                              DataColumn(label: Text('Location')),
                              DataColumn(label: Text('Status')),
                            ],
                            rows: [
                              for (final i in rows)
                                DataRow(cells: [
                                  DataCell(Text(_dateFormat.format(i.createdAt), style: const TextStyle(fontSize: 12))),
                                  DataCell(_TypeBadge(incident: i)),
                                  DataCell(SizedBox(width: 220, child: Text(i.title, overflow: TextOverflow.ellipsis))),
                                  DataCell(SizedBox(width: 160, child: Text(i.reporterId, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis))),
                                  DataCell(SizedBox(width: 180, child: Text(i.locationLabel ?? '—', overflow: TextOverflow.ellipsis))),
                                  DataCell(_StatusBadge(status: i.status)),
                                ]),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _labelFor(_TypeFilter f) => switch (f) {
        _TypeFilter.all => 'All',
        _TypeFilter.sos => 'SOS',
        _TypeFilter.safetyEvent => 'Safety events',
        _TypeFilter.report => 'Reports',
      };
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.incident});
  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final (label, color) = incident.isAutomaticSafetyEvent
        ? ('Safety event', AppColors.warning)
        : incident.type == IncidentType.sos
            ? ('SOS', AppColors.danger)
            : ('Report', AppColors.primary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final IncidentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      IncidentStatus.emergency => ('Emergency', AppColors.danger),
      IncidentStatus.resolved => ('Resolved', AppColors.success),
      IncidentStatus.cancelled => ('Cancelled', AppColors.neutral400),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
