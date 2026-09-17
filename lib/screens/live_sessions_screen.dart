import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/live_session.dart';
import '../services/admin_data_service.dart';
import '../theme.dart';

class LiveSessionsScreen extends StatelessWidget {
  const LiveSessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LiveSession>>(
      stream: AdminDataService.streamActiveLiveSessions(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Could not load live sessions: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        final sessions = snap.data!;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Active Live Tracking', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.dark)),
              const SizedBox(height: 4),
              Text(
                sessions.isEmpty
                    ? 'No one is currently sharing a live journey.'
                    : '${sessions.length} user${sessions.length == 1 ? '' : 's'} currently sharing their location.',
                style: const TextStyle(color: AppColors.neutral900),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: sessions.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'This updates live — it will populate the moment someone starts '
                            'sharing a journey or their location from the app.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.neutral400),
                          ),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 340,
                          mainAxisExtent: 170,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: sessions.length,
                        itemBuilder: (context, i) => _SessionCard(session: sessions[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});
  final LiveSession session;

  @override
  Widget build(BuildContext context) {
    final stale = session.lastUpdatedAt != null && DateTime.now().difference(session.lastUpdatedAt!).inMinutes > 15;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: stale ? AppColors.warning : AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: stale ? AppColors.warning : AppColors.success, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(session.ownerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (session.destinationLabel != null) ...[
            _InfoRow(icon: Icons.flag_outlined, text: session.destinationLabel!),
            const SizedBox(height: 4),
          ],
          if (session.vehicleNumber != null && session.vehicleNumber!.isNotEmpty) ...[
            _InfoRow(icon: Icons.directions_car_outlined, text: session.vehicleNumber!),
            const SizedBox(height: 4),
          ],
          _InfoRow(
            icon: Icons.people_outline_rounded,
            text: '${session.sharedWithCount} contact${session.sharedWithCount == 1 ? '' : 's'} watching',
          ),
          const Spacer(),
          Text(
            session.lastUpdatedAt == null
                ? 'No location update yet'
                : (stale ? 'Stale — last update ' : 'Updated ') + DateFormat('h:mm a').format(session.lastUpdatedAt!),
            style: TextStyle(fontSize: 11, color: stale ? AppColors.warning : AppColors.neutral400),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.neutral400),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.neutral900), overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
