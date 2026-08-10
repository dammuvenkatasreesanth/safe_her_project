import 'package:flutter/material.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../history/history_tab.dart';
import '../profile/profile_tab.dart';
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

  late final _tabs = [
    HomeTab(onShareLocation: _shareLocationFromHome),
    LiveTrackingTab(key: _trackingKey),
    const HistoryTab(),
    const ProfileTab(),
  ];

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