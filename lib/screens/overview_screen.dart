import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/incident.dart';
import '../models/app_user.dart';
import '../models/live_session.dart';
import '../services/admin_data_service.dart';
import '../theme.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Incident>>(
      stream: AdminDataService.streamRecentIncidents(),
      builder: (context, incidentSnap) {
        return StreamBuilder<List<AppUser>>(
          stream: AdminDataService.streamUsers(),
          builder: (context, userSnap) {
            return StreamBuilder<List<LiveSession>>(
              stream: AdminDataService.streamActiveLiveSessions(),
              builder: (context, sessionSnap) {
                if (incidentSnap.hasError || userSnap.hasError || sessionSnap.hasError) {
                  return _ErrorState(
                    error: (incidentSnap.error ?? userSnap.error ?? sessionSnap.error).toString(),
                  );
                }
                if (!incidentSnap.hasData || !userSnap.hasData || !sessionSnap.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }

                final incidents = incidentSnap.data!;
                final users = userSnap.data!;
                final activeSessions = sessionSnap.data!;

                final now = DateTime.now();
                final last24h = incidents.where((i) => now.difference(i.createdAt).inHours < 24);
                final sosCount = last24h.where((i) => i.type == IncidentType.sos && !i.isAutomaticSafetyEvent).length;
                final emergencyOpen = incidents.where((i) => i.status == IncidentStatus.emergency).length;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.dark)),
                      const SizedBox(height: 4),
                      const Text('Live snapshot across every SafeHer user.', style: TextStyle(color: AppColors.neutral900)),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _StatCard(icon: Icons.people_alt_outlined, label: 'Registered users', value: '${users.length}', color: AppColors.primary),
                          _StatCard(icon: Icons.report_gmailerrorred_rounded, label: 'Incidents (all time)', value: '${incidents.length}', color: AppColors.dark),
                          _StatCard(icon: Icons.sos_rounded, label: 'SOS alerts (24h)', value: '$sosCount', color: AppColors.danger),
                          _StatCard(icon: Icons.warning_amber_rounded, label: 'Open / emergency', value: '$emergencyOpen', color: AppColors.warning),
                          _StatCard(icon: Icons.share_location_rounded, label: 'Active live sessions', value: '${activeSessions.length}', color: AppColors.success),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _IncidentsOverTimeChart(incidents: incidents)),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: _IncidentsByTypeChart(incidents: incidents)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.dark)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.neutral900, fontSize: 13)),
        ],
      ),
    );
  }
}

class _IncidentsOverTimeChart extends StatelessWidget {
  const _IncidentsOverTimeChart({required this.incidents});
  final List<Incident> incidents;

  @override
  Widget build(BuildContext context) {
    const days = 14;
    final now = DateTime.now();
    final buckets = List<int>.filled(days, 0);
    for (final incident in incidents) {
      final diff = now.difference(DateTime(incident.createdAt.year, incident.createdAt.month, incident.createdAt.day)).inDays;
      final idx = days - 1 - diff;
      if (idx >= 0 && idx < days) buckets[idx]++;
    }
    final maxY = (buckets.isEmpty ? 1 : buckets.reduce((a, b) => a > b ? a : b)).toDouble();

    return Container(
      height: 260,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.neutral200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Incidents — last 14 days', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.dark)),
          const SizedBox(height: 12),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxY < 4 ? 4 : maxY + 1,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26)),
                ),
                barGroups: [
                  for (var i = 0; i < days; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(toY: buckets[i].toDouble(), color: AppColors.primary, width: 12, borderRadius: BorderRadius.circular(3)),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncidentsByTypeChart extends StatelessWidget {
  const _IncidentsByTypeChart({required this.incidents});
  final List<Incident> incidents;

  @override
  Widget build(BuildContext context) {
    final sos = incidents.where((i) => i.type == IncidentType.sos && !i.isAutomaticSafetyEvent).length;
    final safety = incidents.where((i) => i.isAutomaticSafetyEvent).length;
    final reports = incidents.where((i) => i.type == IncidentType.report).length;
    final total = sos + safety + reports;

    return Container(
      height: 260,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.neutral200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('By type', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.dark)),
          const SizedBox(height: 12),
          Expanded(
            child: total == 0
                ? const Center(child: Text('No incidents yet', style: TextStyle(color: AppColors.neutral400)))
                : Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 30,
                            sections: [
                              if (sos > 0) PieChartSectionData(value: sos.toDouble(), color: AppColors.danger, title: '', radius: 40),
                              if (safety > 0) PieChartSectionData(value: safety.toDouble(), color: AppColors.warning, title: '', radius: 40),
                              if (reports > 0) PieChartSectionData(value: reports.toDouble(), color: AppColors.primary, title: '', radius: 40),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LegendRow(color: AppColors.danger, label: 'SOS', value: sos),
                          _LegendRow(color: AppColors.warning, label: 'Safety events', value: safety),
                          _LegendRow(color: AppColors.primary, label: 'Reports', value: reports),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label, required this.value});
  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$label ($value)', style: const TextStyle(fontSize: 12, color: AppColors.neutral900)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 32, color: AppColors.danger),
            const SizedBox(height: 10),
            Text('Could not load dashboard data:\n$error', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.neutral900)),
          ],
        ),
      ),
    );
  }
}
