import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../models/live_session.dart';
import '../../services/tracking_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_map.dart';
import '../../widgets/screen_header.dart';

class TrackingViewerScreen extends StatefulWidget {
  const TrackingViewerScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<TrackingViewerScreen> createState() => _TrackingViewerScreenState();
}

class _TrackingViewerScreenState extends State<TrackingViewerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: StreamBuilder<LiveSession>(
          stream: TrackingService.streamSession(widget.sessionId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ErrorView(error: snapshot.error.toString());
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final session = snapshot.data!;
            if (session.status == 'ended') {
              return _TripEndedView(session: session);
            }

            return _LiveTrackingView(session: session);
          },
        ),
      ),
    );
  }
}

class _LiveTrackingView extends StatelessWidget {
  const _LiveTrackingView({required this.session});
  final LiveSession session;

  @override
  Widget build(BuildContext context) {
    final location = session.lastLocation?.toLatLng;
    final destination = session.destinationLatLng;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 12),
          child: ScreenHeader(
            title: "${session.ownerName}'s Journey",
            onBack: () => Navigator.pop(context),
          ),
        ),
        Expanded(
          child: AppMap(
            center: location ?? destination,
            zoom: 14,
            markers: [
              if (location != null) youAreHereMarker(location),
              placeMarker(
                destination,
                icon: Icons.flag_rounded,
                color: Colors.black87,
              ),
            ],
            polylines: [
              if (location != null)
                Polyline(
                  points: [location, destination],
                  color: AppColors.primary,
                  strokeWidth: 4,
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r6)),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Heading to', style: AppTextStyles.b5),
                      Text(session.destinationLabel, style: AppTextStyles.semibold16),
                    ],
                  ),
                  if (session.etaMinutes != null)
                    _StatItem(label: 'ETA', value: '${session.etaMinutes} min'),
                ],
              ),
              if (session.sharingPaused) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.pause_circle_outline, size: 16, color: AppColors.neutral400),
                    const SizedBox(width: 6),
                    Text(
                      'Still on her way — live location sharing is paused',
                      style: AppTextStyles.b5.copyWith(color: AppColors.neutral400),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              if (session.vehicleNumber != null)
                Row(
                  children: [
                    const Icon(Icons.directions_car, size: 16, color: AppColors.neutral400),
                    const SizedBox(width: 8),
                    Text(
                      'Vehicle: ${session.vehicleNumber}',
                      style: AppTextStyles.b3.copyWith(color: AppColors.neutral900),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TripEndedView extends StatelessWidget {
  const _TripEndedView({required this.session});
  final LiveSession session;

  @override
  Widget build(BuildContext context) {
    final arrived = session.arrivedSafely;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              arrived ? Icons.verified_rounded : Icons.check_circle_outline,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 24),
            Text(arrived ? 'Reached Destination' : 'Trip Ended', style: AppTextStyles.h5),
            const SizedBox(height: 8),
            Text(
              arrived
                  ? '${session.ownerName} reached ${session.destinationLabel} safely.'
                  : '${session.ownerName} has ended this journey safely.',
              textAlign: TextAlign.center,
              style: AppTextStyles.b2,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close Viewer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Error loading session: $error'),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.b5),
        Text(value, style: AppTextStyles.semibold16),
      ],
    );
  }
}