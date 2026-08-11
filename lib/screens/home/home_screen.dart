import 'package:flutter/material.dart';
import '../../services/voice_command_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../history/history_tab.dart';
import '../profile/profile_tab.dart';
import '../sos/sos_screen.dart';
import '../tracking/live_tracking_tab.dart';
import 'home_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SafeHerTab _tab = SafeHerTab.home;
  final _trackingKey = GlobalKey<LiveTrackingTabState>();
  bool _sosScreenActive = false;

  late final _tabs = [
    HomeTab(onShareLocation: _shareLocationFromHome),
    LiveTrackingTab(key: _trackingKey),
    const HistoryTab(),
    const ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    // Voice Command needs somewhere to push the SOS screen from regardless
    // of which tab is currently showing — this outlives tab switches for
    // as long as HomeScreen itself is mounted (i.e. the whole logged-in
    // session), matching "foreground only" for the rest of this feature.
    VoiceCommandService.registerTrigger(_triggerSosFromVoice);
    VoiceCommandService.syncWithSetting();
  }

  @override
  void dispose() {
    VoiceCommandService.registerTrigger(null);
    VoiceCommandService.stop();
    super.dispose();
  }

  void _triggerSosFromVoice() {
    // A panicked "help me, help me" repeats the phrase — without this
    // guard, each repeat would push another SosScreen on top of the last
    // one instead of the countdown just running once.
    if (!mounted || _sosScreenActive) return;
    _sosScreenActive = true;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SosScreen(autoTrigger: true)))
        .then((_) => _sosScreenActive = false);
  }

  void _shareLocationFromHome() {
    setState(() => _tab = SafeHerTab.tracking);
    _trackingKey.currentState?.startSharingLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(
              index: SafeHerTab.values.indexOf(_tab),
              children: _tabs,
            ),
            Positioned(
              left: 15,
              right: 15,
              bottom: 12,
              child: BottomNavBar(
                current: _tab,
                onSelect: (t) => setState(() => _tab = t),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
